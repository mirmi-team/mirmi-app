import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/api.dart';
import 'auth_service.dart';

/// 기숙사 일정 API. 로그인이 필요하다.
class ScheduleService {
  /// 전체 일정 (서버가 schedule_date 오름차순으로 준다).
  /// 월별 조회 엔드포인트가 없어 한 번에 받아 앱에서 달별로 나눈다.
  static Future<List<DormSchedule>> getAll() async {
    final res = await AuthService.authorized(
      (token) => http.get(
        Uri.parse('$kBaseUrl/schedules'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ),
    );
    _checkStatus(res);

    final body = jsonDecode(res.body);
    if (body is! List) return const [];
    return body
        .map((e) => DormSchedule.fromJson(e as Map<String, dynamic>))
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
      throw const ApiException('일정을 불러오지 못했습니다.');
    }
  }
}

class DormSchedule {
  const DormSchedule({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
  });

  final int id;
  final String title;
  final String description;

  /// 일정이 실제로 있는 날 (등록 시각이 아니다).
  final DateTime date;

  factory DormSchedule.fromJson(Map<String, dynamic> json) => DormSchedule(
    id: json['id'] as int,
    title: (json['title'] ?? '') as String,
    description: (json['description'] ?? '') as String,
    // 'YYYY-MM-DD' 라 시간대 변환 없이 그대로 읽는다.
    date: DateTime.parse((json['schedule_date'] as String).substring(0, 10)),
  );
}
