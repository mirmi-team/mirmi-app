import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../constants/api.dart';

class AuthService {
  static const _storage = FlutterSecureStorage();
  static const _accessKey = 'accessToken';
  static const _refreshKey = 'refreshToken';

  // ── Token storage ──────────────────────────────────────────────

  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
  }

  static Future<String?> getAccessToken() => _storage.read(key: _accessKey);

  static Future<String?> getRefreshToken() => _storage.read(key: _refreshKey);

  static Future<void> clearTokens() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }

  // ── Token refresh ──────────────────────────────────────────────

  static Future<bool> _tryRefresh() async {
    try {
      final refreshToken = await getRefreshToken();
      if (refreshToken == null) return false;

      final res = await http.post(
        Uri.parse('$kBaseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );
      if (res.statusCode < 200 || res.statusCode >= 300) return false;

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      await _storage.write(key: _accessKey, value: body['accessToken'] as String);
      return true;
    } catch (_) {
      return false;
    }
  }

  // 401 시 자동 refresh 후 재시도하는 공통 헬퍼
  static Future<http.Response> _send(
    Future<http.Response> Function(String token) request,
  ) async {
    var token = await getAccessToken() ?? '';
    var res = await request(token);

    if (res.statusCode == 401) {
      final ok = await _tryRefresh();
      if (!ok) {
        await clearTokens();
        throw const SessionExpiredException();
      }
      token = await getAccessToken() ?? '';
      res = await request(token);
    }

    return res;
  }

  // ── Public API calls ───────────────────────────────────────────

  static Future<void> sendVerificationCode(String email) async {
    final res = await http.post(
      Uri.parse('$kBaseUrl/auth/email/send'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    _checkStatus(res);
  }

  static Future<void> verifyCode(String email, String code) async {
    final res = await http.post(
      Uri.parse('$kBaseUrl/auth/email/verify'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'code': code}),
    );
    _checkStatus(res);
  }

  static Future<void> register({
    required String email,
    required String password,
    required String username,
    required int grade,
    required int classNo,
    required int roomNumber,
    required bool canStaying,
    required String gender,
  }) async {
    final res = await http.post(
      Uri.parse('$kBaseUrl/auth/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'username': username,
        'grade': grade,
        'class_no': classNo,
        'room_number': roomNumber,
        'can_staying': canStaying,
        'gender': gender == '남자' ? 'MALE' : 'FEMALE',
      }),
    );
    _checkStatus(res);
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('$kBaseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    _checkStatus(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    await saveTokens(
      accessToken: body['accessToken'] as String,
      refreshToken: body['refreshToken'] as String,
    );
    return body;
  }

  static Future<Map<String, dynamic>> getMe() async {
    final res = await _send((token) => http.get(
      Uri.parse('$kBaseUrl/users/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ));
    _checkStatus(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<String> uploadProfileImage(String filePath) async {
    final res = await _send((token) async {
      final request = http.MultipartRequest(
        'PATCH',
        Uri.parse('$kBaseUrl/users/me/profile-image'),
      )
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(await http.MultipartFile.fromPath('image', filePath));
      final streamed = await request.send();
      return http.Response.fromStream(streamed);
    });
    _checkStatus(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return body['profile_image'] as String;
  }

  static Future<void> deleteAccount() async {
    final res = await _send((token) => http.post(
      Uri.parse('$kBaseUrl/auth/quit'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ));
    _checkStatus(res);
    await clearTokens();
  }

  static Future<void> logout() async {
    try {
      await _send((token) => http.post(
        Uri.parse('$kBaseUrl/auth/logout'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ));
    } catch (_) {
      // 백엔드 실패해도 로컬 토큰은 반드시 삭제
    } finally {
      await clearTokens();
    }
  }

  // ── Helper ─────────────────────────────────────────────────────

  static void _checkStatus(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    final body = jsonDecode(res.body);
    final message = body['message'];
    throw ApiException(
      message is List ? message.first.toString() : message.toString(),
    );
  }
}

class ApiException implements Exception {
  const ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class SessionExpiredException extends ApiException {
  const SessionExpiredException() : super('세션이 만료되었습니다. 다시 로그인해주세요.');
}
