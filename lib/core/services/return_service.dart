import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../shared/server_time.dart';
import '../constants/api.dart';
import 'auth_service.dart';

/// 복귀 입실 체크 API. 로그인이 필요하다.
///
/// 사감이 QR을 띄우는 게 아니라 **학생이 QR을 띄우고 사감이 스캔**한다.
/// 그래서 앱에는 스캐너가 없고 QR을 보여주기만 하면 된다.
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
    actualTime: parseServerTime(json['actual_return_time'] as String?),
  );
}

/// 서버가 내려주는 복귀 타입 → 화면에 쓰는 이름.
const returnTypeLabels = {
  'IMMEDIATE': '바로 복귀',
  'DINNER': '석식 복귀',
  'EIGHT_PM': '8시 복귀',
};
