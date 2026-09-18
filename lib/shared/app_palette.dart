import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    required this.bgSurfaceHover,
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

  /// 배경 위에 한 단계 올라온 표면 (카드 위 카드 등)
  final Color bgSurfaceHover;
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
    bgSurfaceHover: AppDark.bgSurfaceHover,
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
    // 라이트는 흰 표면 하나로 충분해 bgSurface 와 같은 값을 쓴다.
    bgSurfaceHover: AppLight.bgSurface,
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

  /// 상태바·네비게이션바 글자와 아이콘 색.
  ///
  /// 배경은 앱 화면이 비치도록 투명하게 두고 아이콘 밝기만 뒤집는다.
  /// 안드로이드는 `...IconBrightness`(아이콘 자체의 밝기), iOS 는
  /// `statusBarBrightness`(뒤에 깔린 배경의 밝기)를 보므로 값이 서로 반대다.
  static SystemUiOverlayStyle overlayStyle(bool isDark) => SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
    systemNavigationBarIconBrightness: isDark
        ? Brightness.light
        : Brightness.dark,
  );

  static ThemeData _build(Brightness brightness, AppPalette palette) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: palette.bgCanvas,
      // AppBar 는 자기 영역의 오버레이 스타일을 직접 정하고, 그게 앱 전체에
      // 걸어둔 AnnotatedRegion 보다 안쪽이라 이긴다. 여기서 같은 값을 줘야
      // 상단바가 있는 화면에서도 상태바 글자색이 테마를 따라간다.
      appBarTheme: AppBarTheme(systemOverlayStyle: overlayStyle(isDark)),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppBrand.primary,
        selectionColor: AppBrand.primary.withValues(alpha: 0.33),
        selectionHandleColor: AppBrand.primary,
      ),
    );
  }
}
