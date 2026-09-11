import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/api.dart';
import 'auth_service.dart';

/// 기상송 API. 전부 로그인이 필요하다.
class SongService {
  static Map<String, String> _headers(String token) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  /// 유튜브 검색 (서버가 최대 5건 반환)
  static Future<List<SongSearchResult>> search(String query) async {
    final res = await AuthService.authorized(
      (token) => http.get(
        Uri.parse(
          '$kBaseUrl/morning-songs/search?q=${Uri.encodeQueryComponent(query)}',
        ),
        headers: _headers(token),
      ),
    );
    _checkStatus(res);
    final body = jsonDecode(res.body);
    if (body is! List) return const [];
    return body
        .map((e) => SongSearchResult.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 신청. 재생 날짜(play_date)는 서버가 KST 기준 내일로 정한다.
  /// 그 날짜가 이미 10곡이면 400 이 온다.
  static Future<void> request(SongSearchResult song) async {
    final res = await AuthService.authorized(
      (token) => http.post(
        Uri.parse('$kBaseUrl/morning-songs'),
        headers: _headers(token),
        body: jsonEncode({
          'song_name': song.title,
          'youtube_url': song.youtubeUrl,
          'thumbnail': song.thumbnail,
        }),
      ),
    );
    _checkStatus(res);
  }

  /// 오늘 나가는 기상송 목록 (KST)
  static Future<List<MorningSong>> getToday() async {
    final res = await AuthService.authorized(
      (token) => http.get(
        Uri.parse('$kBaseUrl/morning-songs/today'),
        headers: _headers(token),
      ),
    );
    _checkStatus(res);
    return _parseList(res.body);
  }

  /// 내 신청 내역. 서버가 날짜로 거르지 않아 전체가 내려온다.
  static Future<List<MorningSong>> getMine() async {
    final res = await AuthService.authorized(
      (token) => http.get(
        Uri.parse('$kBaseUrl/morning-songs/me'),
        headers: _headers(token),
      ),
    );
    _checkStatus(res);
    return _parseList(res.body);
  }

  /// 내 신청 취소
  static Future<void> cancel(int id) async {
    final res = await AuthService.authorized(
      (token) => http.delete(
        Uri.parse('$kBaseUrl/morning-songs/$id'),
        headers: _headers(token),
      ),
    );
    _checkStatus(res);
  }

  /// KST 기준 오늘. 'YYYY-MM-DD' 라 문자열 비교로 날짜 대소를 가릴 수 있다.
  static String get todayKst => _kstDate(const Duration(hours: 9));

  /// 서버가 play_date 를 정하는 방식과 동일하게 계산한 '내일'.
  /// 기기 시간대가 KST 가 아니어도 어긋나지 않도록 UTC 에 9시간을 더한다.
  static String get tomorrowKst => _kstDate(const Duration(hours: 9, days: 1));

  /// 기기 시간대가 KST 가 아니어도 어긋나지 않도록 UTC 에 9시간을 더해 계산한다.
  static String _kstDate(Duration offset) {
    final kst = DateTime.now().toUtc().add(offset);
    final mm = kst.month.toString().padLeft(2, '0');
    final dd = kst.day.toString().padLeft(2, '0');
    return '${kst.year}-$mm-$dd';
  }

  static List<MorningSong> _parseList(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! List) return const [];
    return decoded
        .map((e) => MorningSong.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static void _checkStatus(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    try {
      final body = jsonDecode(res.body);
      final message = body['message'];
      throw ApiException(
        message is List ? message.first.toString() : message.toString(),
      );
    } on FormatException {
      throw const ApiException('요청을 처리하지 못했습니다.');
    }
  }
}

/// 유튜브가 제목·채널명을 HTML 이스케이프해서 준다. (`Don&#39;t` → `Don't`)
/// 신청 시 그 문자열이 그대로 저장되므로 저장된 곡 이름에도 같이 적용한다.
String _unescapeHtml(String input) {
  if (!input.contains('&')) return input;
  return input.replaceAllMapped(
    RegExp(r'&(#(?:[xX][0-9a-fA-F]+|[0-9]+)|[a-zA-Z]+);'),
    (match) {
      final body = match[1]!;
      if (body.startsWith('#')) {
        final isHex = body[1] == 'x' || body[1] == 'X';
        final digits = isHex ? body.substring(2) : body.substring(1);
        final code = int.tryParse(digits, radix: isHex ? 16 : 10);
        if (code == null || code < 0 || code > 0x10FFFF) return match[0]!;
        return String.fromCharCode(code);
      }
      const named = {
        'amp': '&',
        'lt': '<',
        'gt': '>',
        'quot': '"',
        'apos': "'",
        'nbsp': ' ',
      };
      return named[body.toLowerCase()] ?? match[0]!;
    },
  );
}

/// 유튜브 검색 결과 한 건.
class SongSearchResult {
  const SongSearchResult({
    required this.title,
    required this.youtubeUrl,
    required this.thumbnail,
    required this.channel,
  });

  final String title;
  final String youtubeUrl;
  final String thumbnail;
  final String channel;

  factory SongSearchResult.fromJson(Map<String, dynamic> json) =>
      SongSearchResult(
        title: _unescapeHtml((json['title'] ?? '') as String),
        youtubeUrl: (json['youtube_url'] ?? '') as String,
        thumbnail: (json['thumbnail'] ?? '') as String,
        channel: _unescapeHtml((json['channel'] ?? '') as String),
      );
}

/// 신청된 기상송 한 건.
class MorningSong {
  const MorningSong({
    required this.id,
    required this.songName,
    required this.youtubeUrl,
    required this.thumbnail,
    required this.playDate,
    required this.playOrder,
  });

  final int id;
  final String songName;
  final String youtubeUrl;
  final String? thumbnail;

  /// 이 곡이 나가는 날짜 ('YYYY-MM-DD')
  final String playDate;
  final int? playOrder;

  factory MorningSong.fromJson(Map<String, dynamic> json) => MorningSong(
    id: json['id'] as int,
    songName: _unescapeHtml((json['song_name'] ?? '') as String),
    youtubeUrl: (json['youtube_url'] ?? '') as String,
    thumbnail: json['thumbnail'] as String?,
    playDate: (json['play_date'] ?? '') as String,
    playOrder: json['play_order'] as int?,
  );

  /// 아직 재생되지 않은 곡. 이것만 취소할 수 있다.
  /// (서버는 신청분을 항상 '내일'로 잡으므로 실질적으로 내일 곡을 뜻한다)
  bool get isUpcoming => playDate.compareTo(SongService.todayKst) > 0;
}
