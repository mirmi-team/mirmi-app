import '../../shared/date_format.dart';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../shared/server_time.dart';
import '../constants/api.dart';
import 'auth_service.dart';

/// 서버 enum 값 → 화면 라벨. 백엔드 SuggestionCategory 와 1:1.
const suggestionCategoryLabels = <String, String>{
  'FACILITY': '시설',
  'OPERATION': '운영',
  'MEAL': '급식',
  'CLEANING': '청소',
  'SAFETY': '안전',
  'NOISE': '소음',
  'ETC': '기타',
};

/// 건의사항 API. 전부 로그인이 필요하고, 학생은 본인 것만 조회된다.
class SuggestionService {
  static Map<String, String> _headers(String token) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  /// 내 건의사항 목록 (최신순). 목록에는 description 이 내려오지 않는다.
  static Future<List<Suggestion>> getMine() => _list();

  /// 전체 건의사항 (관리자). 엔드포인트는 [getMine] 과 같고, 서버가 역할을
  /// 보고 학생에게는 본인 것만, 관리자에게는 모두를 내려준다.
  static Future<List<Suggestion>> getAll() => _list();

  static Future<List<Suggestion>> _list() async {
    final res = await AuthService.authorized(
      (token) => http.get(
        Uri.parse('$kBaseUrl/suggestions'),
        headers: _headers(token),
      ),
    );
    _checkStatus(res);
    final body = jsonDecode(res.body);
    if (body is! List) return const [];
    return body
        .map((e) => Suggestion.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 상세. 목록에 없는 description 이 여기서만 내려온다.
  static Future<Suggestion> getOne(int id) async {
    final res = await AuthService.authorized(
      (token) => http.get(
        Uri.parse('$kBaseUrl/suggestions/$id'),
        headers: _headers(token),
      ),
    );
    _checkStatus(res);
    return Suggestion.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// 등록. [category] 는 서버 enum 값('FACILITY' 등).
  static Future<void> create({
    required String title,
    required String description,
    required String category,
  }) async {
    final res = await AuthService.authorized(
      (token) => http.post(
        Uri.parse('$kBaseUrl/suggestions'),
        headers: _headers(token),
        body: jsonEncode({
          'title': title,
          'description': description,
          'category': category,
        }),
      ),
    );
    _checkStatus(res);
  }

  /// 답변 등록·수정 (관리자). 등록과 수정이 같은 요청이다.
  ///
  /// 서버가 빈 문자열을 거부하므로 한 번 쓴 답변은 지울 수 없다.
  static Future<void> reply(int id, String text) async {
    final res = await AuthService.authorized(
      (token) => http.patch(
        Uri.parse('$kBaseUrl/suggestions/admin/$id/reply'),
        headers: _headers(token),
        body: jsonEncode({'reply': text}),
      ),
    );
    _checkStatus(res);
  }

  static Future<void> delete(int id) async {
    final res = await AuthService.authorized(
      (token) => http.delete(
        Uri.parse('$kBaseUrl/suggestions/$id'),
        headers: _headers(token),
      ),
    );
    _checkStatus(res);
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
      throw const ApiException('건의사항을 불러오지 못했습니다.');
    }
  }
}

class Suggestion {
  const Suggestion({
    required this.id,
    required this.title,
    required this.category,
    required this.createdAt,
    this.description,
    this.reply,
    this.writerName,
    this.roomNumber,
  });

  final int id;
  final String title;

  /// 서버 enum 값. 화면에는 [categoryLabel] 을 쓴다.
  final String category;
  final DateTime createdAt;

  /// 목록 조회에는 없고 상세에만 있다.
  final String? description;

  /// 관리자 답변. 아직 없으면 null.
  final String? reply;

  /// 작성자. 관리자가 "누가 올렸는지" 알아야 처리할 수 있어서 쓰는 값이다.
  ///
  /// 서버는 관리자 응답에만 `author` 를 담아준다. 학생 응답에는 키 자체가
  /// 없어서 둘 다 null 이 되고, 그러면 화면에서 그 줄을 그리지 않는다.
  final String? writerName;
  final int? roomNumber;

  factory Suggestion.fromJson(Map<String, dynamic> json) {
    // author: { username, room_number, grade, class_no }
    final author = json['author'] as Map<String, dynamic>?;
    return Suggestion(
      id: json['id'] as int,
      title: (json['title'] ?? '') as String,
      category: (json['category'] ?? 'ETC') as String,
      createdAt:
          parseServerTime(json['created_at'] as String) ?? DateTime.now(),
      description: json['description'] as String?,
      reply: json['reply'] as String?,
      writerName: author?['username'] as String?,
      roomNumber: author?['room_number'] as int?,
    );
  }

  String get categoryLabel => suggestionCategoryLabels[category] ?? '기타';

  /// 화면에 보여줄 제목. '[시설] 샤워실 온수가 안나와요.'
  String get labeledTitle => '[$categoryLabel] $title';

  bool get hasReply => reply != null && reply!.isNotEmpty;

  /// '305호 이제호'. 작성자 정보가 없으면 null 이라 그 줄을 그리지 않는다.
  String? get writerLabel {
    final name = writerName;
    final parts = [
      if (roomNumber != null) '$roomNumber호',
      if (name != null && name.isNotEmpty) name,
    ];
    return parts.isEmpty ? null : parts.join(' ');
  }

  /// '2026-09-14'
  String get dateLabel => dateKey(createdAt);
}
