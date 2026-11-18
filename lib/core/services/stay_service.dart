import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../shared/date_format.dart';
import '../constants/api.dart';
import 'auth_service.dart';

/// 주간 잔류/외박 현황 (관리자).
///
/// 학생이 신청하는 쪽은 [AuthService] 에 있다. 여기는 사감이 한 주를 통째로
/// 들여다보는 용도다.
class StayService {
  /// [date] 가 속한 주의 현황. 서버는 그 주 **월요일 날짜**를 요구한다.
  static Future<StayWeek> getWeek(DateTime date) async {
    final monday = mondayOf(date);
    final res = await AuthService.authorized(
      (token) => http.get(
        Uri.parse('$kBaseUrl/stay-status/admin?week=${dateKey(monday)}'),
        headers: {'Authorization': 'Bearer $token'},
      ),
    );
    _checkStatus(res);
    final body = jsonDecode(res.body);
    if (body is! Map<String, dynamic>) return StayWeek.empty(monday);
    return StayWeek.fromJson(body, monday);
  }

  /// 그 주의 월요일. 일요일은 지나간 월요일로 친다.
  ///
  /// 서버 `getWeekStartKst()` 와 같은 규칙이어야 한다. 하루라도 어긋나면
  /// 빈 주를 조회하게 된다.
  static DateTime mondayOf(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return day.subtract(Duration(days: day.weekday - 1));
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
      throw const ApiException('잔류 현황을 불러오지 못했습니다.');
    }
  }
}

/// 한 주의 잔류/외박 현황.
class StayWeek {
  const StayWeek({
    required this.weekStart,
    required this.stayCount,
    required this.outingCount,
    required this.entries,
  });

  StayWeek.empty(this.weekStart)
    : stayCount = 0,
      outingCount = 0,
      entries = const [];

  /// 그 주 월요일.
  final DateTime weekStart;

  final int stayCount;
  final int outingCount;
  final List<StayEntry> entries;

  /// '11.16 ~ 11.22'
  String get rangeLabel {
    final end = weekStart.add(const Duration(days: 6));
    return '${shortDateLabel(weekStart)} ~ ${shortDateLabel(end)}';
  }

  List<StayEntry> get staying => entries.where((e) => e.isStaying).toList();

  List<StayEntry> get outing => entries.where((e) => !e.isStaying).toList();

  factory StayWeek.fromJson(Map<String, dynamic> json, DateTime monday) {
    final summary = (json['summary'] as Map<String, dynamic>?) ?? const {};
    final raw = json['list'];
    final entries = raw is List
        ? raw.map((e) => StayEntry.fromJson(e as Map<String, dynamic>)).toList()
        : const <StayEntry>[];
    // 호실 순으로 보는 쪽이 점호하기 편하다.
    entries.sort((a, b) => (a.roomNumber ?? 0).compareTo(b.roomNumber ?? 0));
    return StayWeek(
      weekStart: monday,
      stayCount: (summary['STAY'] as int?) ?? 0,
      outingCount: (summary['OUTING'] as int?) ?? 0,
      entries: entries,
    );
  }
}

/// 학생 한 명의 신청.
class StayEntry {
  const StayEntry({
    required this.userId,
    required this.isStaying,
    this.username,
    this.roomNumber,
    this.parentPhone,
  });

  final int userId;

  /// true 면 기숙사 잔류, false 면 금토외박.
  final bool isStaying;

  final String? username;
  final int? roomNumber;

  /// 보호자 연락처. 잔류 학생에게 연락할 일이 생긴다.
  final String? parentPhone;

  bool get hasPhone => (parentPhone ?? '').trim().isNotEmpty;

  factory StayEntry.fromJson(Map<String, dynamic> json) => StayEntry(
    userId: (json['user_id'] as int?) ?? 0,
    isStaying: json['status'] == 'STAY',
    username: json['username'] as String?,
    roomNumber: json['room_number'] as int?,
    parentPhone: json['parent_phone'] as String?,
  );
}
