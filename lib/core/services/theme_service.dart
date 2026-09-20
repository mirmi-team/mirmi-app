import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 테마 모드 저장·복원.
///
/// 기본값은 다크. 사용자가 토글하면 기기에 남아 다음 실행에도 유지된다.
abstract final class ThemeService {
  static const _storage = FlutterSecureStorage();
  static const _key = 'themeMode';

  /// 현재 테마. MyApp 이 이걸 듣고 다시 그린다.
  static final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.dark);

  /// 앱 시작 시 한 번 불러 저장된 값을 반영한다.
  static Future<void> load() async {
    try {
      final saved = await _storage.read(key: _key);
      if (saved == 'light') mode.value = ThemeMode.light;
    } catch (_) {
      // 저장소를 못 읽어도 기본값(다크)으로 그냥 뜬다.
    }
  }

  /// 토글. 저장 실패해도 화면은 즉시 바뀐다.
  static Future<void> setDark(bool isDark) async {
    mode.value = isDark ? ThemeMode.dark : ThemeMode.light;
    try {
      await _storage.write(key: _key, value: isDark ? 'dark' : 'light');
    } catch (_) {}
  }
}
