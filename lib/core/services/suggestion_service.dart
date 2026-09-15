import 'dart:convert';

import 'package:http/http.dart' as http;

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
  static Future<List<Suggestion>> getMine() async {
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

  factory Suggestion.fromJson(Map<String, dynamic> json) => Suggestion(
    id: json['id'] as int,
    title: (json['title'] ?? '') as String,
    category: (json['category'] ?? 'ETC') as String,
    createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    description: json['description'] as String?,
    reply: json['reply'] as String?,
  );

  String get categoryLabel => suggestionCategoryLabels[category] ?? '기타';

  /// 화면에 보여줄 제목. '[시설] 샤워실 온수가 안나와요.'
  String get labeledTitle => '[$categoryLabel] $title';

  bool get hasReply => reply != null && reply!.isNotEmpty;

  /// '2026-09-14'
  String get dateLabel {
    final mm = createdAt.month.toString().padLeft(2, '0');
    final dd = createdAt.day.toString().padLeft(2, '0');
    return '${createdAt.year}-$mm-$dd';
  }
}
