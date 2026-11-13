import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../shared/date_format.dart';
import '../../shared/server_time.dart';
import '../constants/api.dart';
import 'auth_service.dart';

/// 공지사항 API
/// 백엔드의 /notices/findAll, /notices/findOne 은 가드가 없어 토큰 없이 호출 가능하다.
/// 등록·수정·삭제는 ADMIN 만 되고, 서버가 역할을 보고 막는다.
class NoticeService {
  /// 오늘 등록된 공지사항 전체 조회 (최신순)
  /// 오늘 공지가 없으면 빈 리스트를 반환한다.
  static Future<List<Notice>> getTodayNotices() async {
    final res = await http.get(
      Uri.parse('$kBaseUrl/notices/findAll'),
      headers: {'Content-Type': 'application/json'},
    );
    _checkStatus(res);

    final body = jsonDecode(res.body);
    // 공지가 없을 때 백엔드가 { message: ... } 를 반환할 수도 있으므로 방어
    if (body is! List) return const [];
    return body.map((e) => Notice.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// 오늘 공지 중 가장 최근 1개. 오늘 올라온 공지가 없으면 null.
  ///
  /// 백엔드는 공지가 없을 때 리스트가 아니라 { message: ... } 를 돌려준다.
  static Future<Notice?> getLatestNotice() async {
    final res = await http.get(
      Uri.parse('$kBaseUrl/notices/findOne'),
      headers: {'Content-Type': 'application/json'},
    );
    _checkStatus(res);

    final body = jsonDecode(res.body);
    if (body is! Map<String, dynamic> || body['id'] == null) return null;
    return Notice.fromJson(body);
  }

  // ── 관리자 ───────────────────────────────────────────────────

  /// 관리자용 공지 목록. 전체 기간, 최신순.
  ///
  /// 학생이 보는 /notices/findAll 은 오늘 올린 것만 내려줘서, 지난 공지를
  /// 고치거나 지우려면 이쪽이 필요하다.
  ///
  /// 서버가 한 번에 최대 100개까지만 준다. 페이지를 넘기는 화면이 없어서
  /// 첫 장만 받고, 전체 개수는 [total] 로 따로 돌려준다.
  static Future<({List<Notice> items, int total})> getAllForAdmin({
    int page = 1,
    int limit = 100,
  }) async {
    final res = await AuthService.authorized(
      (token) => http.get(
        Uri.parse('$kBaseUrl/notices/admin?page=$page&limit=$limit'),
        headers: {'Authorization': 'Bearer $token'},
      ),
    );
    _checkStatus(res);

    final body = jsonDecode(res.body);
    if (body is! Map<String, dynamic>) {
      return (items: const <Notice>[], total: 0);
    }
    final rawItems = body['items'];
    final items = rawItems is List
        ? rawItems
              .map((e) => Notice.fromJson(e as Map<String, dynamic>))
              .toList()
        : const <Notice>[];
    return (items: items, total: (body['total'] as int?) ?? items.length);
  }

  /// 공지 등록. [imagePath] 를 주면 사진을 함께 올린다.
  static Future<void> create({
    required String title,
    required String description,
    String? imagePath,
  }) async {
    final res = await AuthService.authorized(
      (token) => _multipart(
        'POST',
        '$kBaseUrl/notices',
        token,
        title: title,
        description: description,
        imagePath: imagePath,
      ),
    );
    _checkStatus(res);
  }

  /// 공지 수정. [imagePath] 를 주면 기존 사진을 교체한다.
  ///
  /// 사진을 떼는 건 불가능하다. 서버에 image_url 을 비우는 경로가 없다.
  static Future<void> update(
    int id, {
    required String title,
    required String description,
    String? imagePath,
  }) async {
    final res = await AuthService.authorized(
      (token) => _multipart(
        'PATCH',
        '$kBaseUrl/notices/$id',
        token,
        title: title,
        description: description,
        imagePath: imagePath,
      ),
    );
    _checkStatus(res);
  }

  static Future<void> delete(int id) async {
    final res = await AuthService.authorized(
      (token) => http.delete(
        Uri.parse('$kBaseUrl/notices/$id'),
        headers: {'Authorization': 'Bearer $token'},
      ),
    );
    _checkStatus(res);
  }

  /// 등록과 수정이 같은 multipart 형식을 쓴다.
  ///
  /// 서버는 image_url 필드도 받아주지만 보내면 안 된다. 수정 처리 순서상
  /// 방금 업로드한 사진 주소를 그 값으로 덮어써 버린다.
  static Future<http.Response> _multipart(
    String method,
    String url,
    String token, {
    required String title,
    required String description,
    String? imagePath,
  }) async {
    final request = http.MultipartRequest(method, Uri.parse(url))
      ..headers['Authorization'] = 'Bearer $token'
      ..fields['title'] = title
      ..fields['description'] = description;
    if (imagePath != null) {
      request.files.add(await http.MultipartFile.fromPath('image', imagePath));
    }
    final streamed = await request.send();
    return http.Response.fromStream(streamed);
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
      throw const ApiException('공지사항을 불러오지 못했습니다.');
    }
  }
}

class Notice {
  const Notice({
    required this.id,
    required this.title,
    required this.description,
    required this.createdAt,
    this.imageUrl,
  });

  final int id;
  final String title;
  final String description;
  final DateTime createdAt;

  /// 첨부 이미지. 등록하지 않은 공지는 null.
  final String? imageUrl;

  factory Notice.fromJson(Map<String, dynamic> json) => Notice(
    id: json['id'] as int,
    title: (json['title'] ?? '') as String,
    description: (json['description'] ?? '') as String,
    createdAt: parseServerTime(json['created_at'] as String) ?? DateTime.now(),
    imageUrl: json['image_url'] as String?,
  );

  /// "방금 전" / "3분 전" / "2시간 전" / "3일 전".
  ///
  /// 관리자 목록에는 지난 공지도 올라와서, 한 주가 넘으면 "214일 전" 대신
  /// 날짜를 보여준다.
  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.isNegative || diff.inMinutes < 1) return '방금 전';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    if (diff.inDays <= 7) return '${diff.inDays}일 전';
    return dateKey(createdAt);
  }
}
