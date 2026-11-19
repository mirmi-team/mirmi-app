import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../shared/server_time.dart';
import '../constants/api.dart';
import 'auth_service.dart';

/// 복귀 입실 체크 API. 로그인이 필요하다.
///
/// 사감이 QR을 띄우는 게 아니라 **학생이 QR을 띄우고 사감이 스캔**한다.
/// 학생 쪽은 QR을 보여주기만 하고, 관리자 쪽에 스캐너가 있다.
class ReturnService {
  /// 내 복귀 인증용 QR. 30초 뒤 만료되므로 화면에 띄워둔 동안 다시 받아야 한다.
  static Future<ReturnQr> getMyQr() async {
    final res = await AuthService.authorized(
      (token) => http.get(
        Uri.parse('$kBaseUrl/returns/qr'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ),
    );
    _checkStatus(res);
    return ReturnQr.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// 오늘 내 입실 체크 기록. 체크인마다 행이 쌓이므로 여러 건이 올 수 있고,
  /// 아직 한 번도 안 찍었으면 빈 목록이다.
  static Future<List<ReturnRecord>> getMine() async {
    final res = await AuthService.authorized(
      (token) => http.get(
        Uri.parse('$kBaseUrl/returns'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ),
    );
    _checkStatus(res);
    if (res.body.isEmpty || res.body == 'null') return const [];
    final body = jsonDecode(res.body);
    if (body is! List) return const [];
    return body
        .map((e) => ReturnRecord.fromJson(e as Map<String, dynamic>))
        // 같은 테이블에 사전 등록 행(체크인 전)도 섞여 있다. 그건 뺀다.
        .where((record) => record.isChecked)
        .toList();
  }

  // ── 관리자 ───────────────────────────────────────────────────

  /// 오늘 전체 복귀 현황. [floor] 를 주면 그 층만.
  ///
  /// 서버가 층 → 학생 순으로 묶어 준다. 호실로 다시 묶는 건 화면에서 한다.
  static Future<List<FloorReturnStatus>> getTodayStatus({int? floor}) async {
    final query = floor == null ? '' : '?floor=$floor';
    final res = await AuthService.authorized(
      (token) => http.get(
        Uri.parse('$kBaseUrl/admin/returns/today$query'),
        headers: {'Authorization': 'Bearer $token'},
      ),
    );
    _checkStatus(res);
    final body = jsonDecode(res.body);
    if (body is! List) return const [];
    return body
        .map((e) => FloorReturnStatus.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 스캔한 QR 토큰으로 복귀를 확정한다.
  ///
  /// 복귀 타입은 서버가 **스캔한 시각**을 보고 정한다. 앱이 고르지 않는다.
  /// 시간대 밖이면 타입 없이 기록되고 [ReturnScan.returnType] 이 null 이다.
  static Future<ReturnScan> verify(String qrToken) async {
    final res = await AuthService.authorized(
      (token) => http.post(
        Uri.parse('$kBaseUrl/admin/returns/verify'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'token': qrToken}),
      ),
    );
    _checkStatus(res);
    return ReturnScan.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
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
      throw const ApiException('QR을 불러오지 못했습니다.');
    }
  }
}

/// 서버가 만들어 준 QR.
class ReturnQr {
  ReturnQr({required this.image, required this.ttl})
    : receivedAt = DateTime.now();

  /// `data:image/png;base64,...` 형태. 서버가 이미지까지 만들어 주므로
  /// 앱에 QR 생성 라이브러리를 넣지 않아도 된다.
  final String image;

  /// 이 QR 이 살아 있는 시간.
  final Duration ttl;

  /// 응답을 받은 기기 시각.
  final DateTime receivedAt;

  /// QR 기본 수명. 서버에서 계산하지 못했을 때 쓴다.
  static const _defaultTtl = Duration(seconds: 30);

  /// 남은 시간은 **받은 순간부터** 센다.
  ///
  /// 서버가 준 만료 시각을 기기 시계와 직접 비교하면, 기기 시계가 몇 초만
  /// 틀어져도 이미 만료된 QR 을 계속 보여주거나 반대로 끊임없이 새로
  /// 받아오게 된다. 수명(ttl)만 서버에서 얻고 카운트는 기기에서 한다.
  DateTime get expiresAt => receivedAt.add(ttl);

  Duration get remaining {
    final left = expiresAt.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  factory ReturnQr.fromJson(Map<String, dynamic> json) =>
      ReturnQr(image: json['qrImage'] as String? ?? '', ttl: _ttlOf(json));

  /// 수명을 서버 값끼리만 빼서 구한다. 토큰이 `{userId}.{발급시각}.{서명}`
  /// 이라 발급 시각을 알 수 있고, 만료 시각과의 차이가 곧 수명이다.
  /// 기기 시계가 끼어들지 않는다.
  static Duration _ttlOf(Map<String, dynamic> json) {
    final expiresAt = DateTime.tryParse(json['expiresAt'] as String? ?? '');
    final parts = (json['token'] as String? ?? '').split('.');
    if (expiresAt == null || parts.length != 3) return _defaultTtl;

    final issuedAtMs = int.tryParse(parts[1]);
    if (issuedAtMs == null) return _defaultTtl;

    final ttl = expiresAt.difference(
      DateTime.fromMillisecondsSinceEpoch(issuedAtMs, isUtc: true),
    );
    // 서버 값이 이상하면(음수이거나 지나치게 길면) 기본값으로 돌아간다.
    if (ttl <= Duration.zero || ttl > const Duration(minutes: 10)) {
      return _defaultTtl;
    }
    return ttl;
  }

  /// data URL 앞부분을 떼고 실제 PNG 바이트만 돌려준다.
  List<int> get bytes {
    final comma = image.indexOf(',');
    if (comma < 0) return const [];
    return base64Decode(image.substring(comma + 1));
  }
}

/// 오늘 복귀 기록.
class ReturnRecord {
  const ReturnRecord({required this.returnType, required this.actualTime});

  /// `IMMEDIATE` / `DINNER` / `EIGHT_PM`. 시간대 밖에 스캔하면 null.
  final String? returnType;

  /// 사감이 QR을 스캔한 시각. null이면 아직 입실 체크 전.
  final DateTime? actualTime;

  bool get isChecked => actualTime != null;

  factory ReturnRecord.fromJson(Map<String, dynamic> json) => ReturnRecord(
    returnType: json['return_type'] as String?,
    // 이 컬럼만 한국시간 벽시계로 내려온다. parseServerTime 으로 읽으면
    // 9시간이 밀린다.
    actualTime: parseKstTime(json['actual_return_time'] as String?),
  );
}

/// 서버가 내려주는 복귀 타입 → 화면에 쓰는 이름.
const returnTypeLabels = {
  'IMMEDIATE': '바로 복귀',
  'DINNER': '석식 복귀',
  'EIGHT_PM': '8시 복귀',
};

/// 복귀 시간대. 서버 `resolveReturnTypeByTime` 과 같은 경계다.
///
/// 정답은 서버가 정한다. 여기 값은 사감에게 "지금 찍으면 어디로 들어간다"를
/// 미리 알려주는 안내용일 뿐이다. 서버에서 시간대가 바뀌면 여기도 고쳐야 한다.
///
/// [toExclusive] 는 **포함하지 않는** 끝이다. 서버가 `nowMinutes < end` 로
/// 보기 때문에 17:20 은 바로 복귀가 아니라 석식이다.
///
/// 8시 복귀만 끝이 20:31 인 것은 20:30 분을 통째로 포함시키려는 것이다.
/// 그래서 화면에 띄울 끝 시각은 [endLabel] 로 따로 들고 있다.
const returnSlots =
    <({String type, int from, int toExclusive, String endLabel})>[
      (
        type: 'IMMEDIATE',
        from: 8 * 60,
        toExclusive: 17 * 60 + 20,
        endLabel: '17:20',
      ),
      (
        type: 'DINNER',
        from: 17 * 60 + 20,
        toExclusive: 18 * 60 + 20,
        endLabel: '18:20',
      ),
      (
        type: 'EIGHT_PM',
        from: 18 * 60 + 20,
        toExclusive: 20 * 60 + 31,
        endLabel: '20:30',
      ),
    ];

/// 지금 스캔하면 어느 칸에 들어가는지. 시간대 밖이면 null.
({String type, int from, int toExclusive, String endLabel})? currentReturnSlot([
  DateTime? at,
]) {
  final now = at ?? DateTime.now();
  final minutes = now.hour * 60 + now.minute;
  for (final slot in returnSlots) {
    if (minutes >= slot.from && minutes < slot.toExclusive) return slot;
  }
  return null;
}

/// '8시 복귀 중 · 20:30까지' / '복귀 시간대 아님 · 기타로 기록됩니다'
///
/// 사감이 스캔하면서 "이게 석식으로 들어가나 8시로 들어가나" 헷갈리지
/// 않도록 머리말에 띄운다.
String returnSlotNotice([DateTime? at]) {
  final slot = currentReturnSlot(at);
  if (slot == null) return '복귀 시간대 아님 · 기타로 기록됩니다';
  return '${returnTypeLabels[slot.type]} 중 · ${slot.endLabel}까지';
}

// ── 관리자용 모델 ───────────────────────────────────────────────

/// 한 층의 복귀 현황.
class FloorReturnStatus {
  const FloorReturnStatus({required this.floor, required this.students});

  final int floor;
  final List<StudentReturnStatus> students;

  factory FloorReturnStatus.fromJson(Map<String, dynamic> json) {
    final raw = json['students'];
    return FloorReturnStatus(
      floor: (json['floor'] as int?) ?? 0,
      students: raw is List
          ? raw
                .map(
                  (e) =>
                      StudentReturnStatus.fromJson(e as Map<String, dynamic>),
                )
                .toList()
          : const <StudentReturnStatus>[],
    );
  }
}

/// 학생 한 명의 오늘 복귀 상태.
class StudentReturnStatus {
  const StudentReturnStatus({
    required this.userId,
    required this.username,
    required this.roomNumber,
    required this.returned,
    required this.checkins,
  });

  final int userId;
  final String username;
  final int roomNumber;

  /// 오늘 한 번이라도 찍었는지. 시간대 밖에 찍은 것도 복귀로 친다.
  final bool returned;

  final ReturnCheckins checkins;

  factory StudentReturnStatus.fromJson(Map<String, dynamic> json) =>
      StudentReturnStatus(
        userId: json['user_id'] as int,
        username: (json['username'] ?? '') as String,
        roomNumber: (json['room_number'] as int?) ?? 0,
        returned: json['status'] == '복귀완료',
        checkins: ReturnCheckins.fromJson(
          json['checkins'] as Map<String, dynamic>?,
        ),
      );
}

/// 시간대별 체크인 시각. 안 찍은 칸은 null.
class ReturnCheckins {
  const ReturnCheckins({this.immediate, this.dinner, this.eightPm, this.other});

  final DateTime? immediate;
  final DateTime? dinner;
  final DateTime? eightPm;

  /// 정해진 시간대 밖에 찍은 기록. 세 칸 어디에도 안 들어간다.
  ///
  /// 예외가 아니라 매일 생긴다. 시간대 사이에 빈 구간이 있어서
  /// (16:30~17:20, 20:30 이후) 그때 찍으면 전부 여기로 온다.
  final DateTime? other;

  factory ReturnCheckins.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ReturnCheckins();
    // 전부 actual_return_time 에서 나온 값이라 한국시간 벽시계다.
    return ReturnCheckins(
      immediate: parseKstTime(json['IMMEDIATE'] as String?),
      dinner: parseKstTime(json['DINNER'] as String?),
      eightPm: parseKstTime(json['EIGHT_PM'] as String?),
      other: parseKstTime(json['OTHER'] as String?),
    );
  }
}

/// QR 한 번 스캔한 결과. 사감이 얼굴과 대조할 수 있도록 누구인지 실려 온다.
class ReturnScan {
  const ReturnScan({
    required this.userId,
    required this.username,
    this.returnType,
    this.roomNumber,
    this.grade,
    this.classNo,
  });

  final int userId;
  final String username;

  /// 시간대 밖에 찍었으면 null. 기록은 되지만 어느 칸에도 안 들어간다.
  final String? returnType;

  final int? roomNumber;
  final int? grade;
  final int? classNo;

  String get typeLabel => returnTypeLabels[returnType] ?? '기타 복귀';

  /// '501호 · 2학년 3반'. 없는 값은 빼고 잇는다.
  String get detailLabel => [
    if (roomNumber != null) '$roomNumber호',
    if (grade != null && classNo != null) '$grade학년 $classNo반',
  ].join(' · ');

  factory ReturnScan.fromJson(Map<String, dynamic> json) {
    final student = (json['student'] as Map<String, dynamic>?) ?? const {};
    return ReturnScan(
      userId: (student['user_id'] as int?) ?? 0,
      username: (student['username'] ?? '') as String,
      returnType: json['returnType'] as String?,
      roomNumber: student['room_number'] as int?,
      grade: student['grade'] as int?,
      classNo: student['class_no'] as int?,
    );
  }
}
