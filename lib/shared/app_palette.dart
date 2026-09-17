import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 현재 테마에 맞는 색 묶음.
///
/// 화면에서 `AppDark.xxx` 를 직접 쓰면 라이트 모드로 못 바꾼다.
/// 대신 `AppPalette.of(context).xxx` 로 읽으면 테마를 따라간다.
///
/// ```dart
/// final palette = AppPalette.of(context);
/// Container(color: palette.bgSurface)
/// ```
class AppPalette {
  const AppPalette._({
    required this.bgCanvas,
    required this.bgSurface,
    required this.bgSurfaceSubtle,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.borderSubtle,
    required this.borderSubtleAlpha,
    required this.borderDefault,
    required this.textDisabled,
    required this.statusError,
  });

  final Color bgCanvas;
  final Color bgSurface;
  final Color bgSurfaceSubtle;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color borderSubtle;
  final Color borderSubtleAlpha;

  /// 라디오·입력 테두리처럼 확실히 보여야 하는 선
  final Color borderDefault;

  /// 비활성 라벨
  final Color textDisabled;
  final Color statusError;

  static const dark = AppPalette._(
    bgCanvas: AppDark.bgCanvas,
    bgSurface: AppDark.bgSurface,
    bgSurfaceSubtle: AppDark.bgSurfaceSubtle,
    textPrimary: AppDark.textPrimary,
    textSecondary: AppDark.textSecondary,
    textTertiary: AppDark.textTertiary,
    borderSubtle: AppDark.borderSubtle,
    borderSubtleAlpha: AppDark.borderSubtleAlpha,
    // 다크에는 대응 값이 따로 없어 가장 가까운 색을 쓴다.
    borderDefault: AppDark.borderSubtle,
    textDisabled: AppDark.textTertiary,
    statusError: AppDark.statusError,
  );

  static const light = AppPalette._(
    bgCanvas: AppLight.bgCanvas,
    bgSurface: AppLight.bgSurface,
    bgSurfaceSubtle: AppLight.bgSurfaceSubtle,
    textPrimary: AppLight.textPrimary,
    textSecondary: AppLight.textSecondary,
    textTertiary: AppLight.textTertiary,
    borderSubtle: AppLight.borderSubtle,
    borderSubtleAlpha: AppLight.borderSubtleAlpha,
    borderDefault: AppLight.borderDefault,
    textDisabled: AppLight.textDisabled,
    statusError: AppLight.statusError,
  );

  static AppPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

/// 라이트·다크 ThemeData.
abstract final class AppTheme {
  static ThemeData get dark => _build(Brightness.dark, AppPalette.dark);
  static ThemeData get light => _build(Brightness.light, AppPalette.light);

  static ThemeData _build(Brightness brightness, AppPalette palette) {
    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: palette.bgCanvas,
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppBrand.primary,
        selectionColor: AppBrand.primary.withValues(alpha: 0.33),
        selectionHandleColor: AppBrand.primary,
      ),
    );
  }
}
