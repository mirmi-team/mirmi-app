import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api.dart';
import 'auth_service.dart';

/// 공지사항 API
/// 백엔드의 /notices/findAll, /notices/findOne 은 가드가 없어 토큰 없이 호출 가능하다.
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
    return body
        .map((e) => Notice.fromJson(e as Map<String, dynamic>))
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
  });

  final int id;
  final String title;
  final String description;
  final DateTime createdAt;

  factory Notice.fromJson(Map<String, dynamic> json) => Notice(
    id: json['id'] as int,
    title: (json['title'] ?? '') as String,
    description: (json['description'] ?? '') as String,
    createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
  );

  /// "방금 전" / "3분 전" / "2시간 전" — 당일 공지만 내려오므로 시간 단위면 충분
  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.isNegative || diff.inMinutes < 1) return '방금 전';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }
}
