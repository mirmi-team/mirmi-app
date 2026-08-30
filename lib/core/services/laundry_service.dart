import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api.dart';
import 'auth_service.dart';

class LaundryService {
  static Future<http.Response> _send(
    Future<http.Response> Function(String token) request,
  ) async {
    var token = await AuthService.getAccessToken() ?? '';
    var res = await request(token);
    if (res.statusCode == 401) {
      try {
        await AuthService.getMe();
      } on SessionExpiredException {
        rethrow;
      }
      token = await AuthService.getAccessToken() ?? '';
      res = await request(token);
    }
    return res;
  }

  static Future<List<Map<String, dynamic>>> getMachines() async {
    final res = await _send(
      (token) => http.get(
        Uri.parse('$kBaseUrl/laundry'),
        headers: {'Authorization': 'Bearer $token'},
      ),
    );
    _checkStatus(res);
    return List<Map<String, dynamic>>.from(jsonDecode(res.body) as List);
  }

  static Future<List<Map<String, dynamic>>> getMyReservations() async {
    final res = await _send(
      (token) => http.get(
        Uri.parse('$kBaseUrl/laundry/requests/me'),
        headers: {'Authorization': 'Bearer $token'},
      ),
    );
    _checkStatus(res);
    return List<Map<String, dynamic>>.from(jsonDecode(res.body) as List);
  }

  // ============================================================
  // TODO(백엔드 작업 후 활성화): 친구가 laundry.service.ts에
  // findActiveReservations() + controller에 GET /laundry/requests/active
  // 라우트를 추가하면, 아래 주석을 해제해서 실제 메서드로 만들면 됩니다.
  // 그리고 laundry_screen.dart의 _loadData()에서
  //   LaundryService.getMyReservations()
  // 라고 되어있는 부분을 아래처럼 딱 한 줄만 바꾸면 끝이에요:
  //   LaundryService.getActiveReservations()
  // ============================================================
  //
  // static Future<List<Map<String, dynamic>>> getActiveReservations() async {
  //   final res = await _send((token) => http.get(
  //     Uri.parse('$kBaseUrl/laundry/requests/active'),
  //     headers: {'Authorization': 'Bearer $token'},
  //   ));
  //   _checkStatus(res);
  //   return List<Map<String, dynamic>>.from(jsonDecode(res.body) as List);
  // }

  static Future<int> createReservation({
    required int laundryId,
    required int roomNumber,
    required DateTime start,
    required DateTime end,
  }) async {
    final res = await _send(
      (token) => http.post(
        Uri.parse('$kBaseUrl/laundry/requests'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'laundry_id': laundryId,
          'room_number': roomNumber,
          'start_time': start.toIso8601String(),
          'end_time': end.toIso8601String(),
        }),
      ),
    );
    _checkStatus(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return body['reservationId'] as int;
  }

  static Future<void> cancelReservation(int reservationId) async {
    final res = await _send(
      (token) => http.delete(
        Uri.parse('$kBaseUrl/laundry/reservations/$reservationId'),
        headers: {'Authorization': 'Bearer $token'},
      ),
    );
    _checkStatus(res);
  }

  static void _checkStatus(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    final body = jsonDecode(res.body);
    final message = body['message'];
    throw ApiException(
      message is List ? message.first.toString() : message.toString(),
    );
  }
}
