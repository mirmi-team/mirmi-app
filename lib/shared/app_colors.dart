import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────
// 색상 팔레트
//
// - AppBrand  : 모드와 무관하게 같은 값 (브랜드색, 상태색)
// - AppDark   : 다크 모드 전용
// - AppLight  : 라이트 모드 전용
// - AppColors : 팔레트로 분류하기 애매한, 특정 화면 전용 색
//
// 현재 앱은 다크 고정이라 화면에서 AppDark 를 직접 쓴다.
// 라이트 모드를 붙일 때는 AppLight 로 갈아끼운다.
// ─────────────────────────────────────────────────────────────────

/// 다크·라이트에서 값이 같은 색.
abstract final class AppBrand {
  static const primary = Color(0xFF06B6D4);
  static const primaryHover = Color(0xFF0891B2);
  static const secondary = Color(0xFF67E8F9);

  /// 브랜드색의 옅은 배경 틴트
  static const subtle = Color(0xFFCAF4F7);

  static const success = Color(0xFF22C55E);
  static const disabled = Color(0xFFC0C0C0);
}

/// 다크 모드 팔레트.
abstract final class AppDark {
  // 배경
  static const bgCanvas = Color(0xFF09090B);
  static const bgSurface = Color(0xFF18181B);
  static const bgSurfaceHover = Color(0xFF27272A);

  /// 반투명 표면 (겹쳐 쓰는 카드)
  static const bgSurfaceSubtle = Color(0xC418181B);
  static const bgSurfaceOverlay = Color(0x9218181B);

  // 글자
  static const textPrimary = Color(0xFFFAFAFA);
  static const textSecondary = Color(0xFFD4D4D8);
  static const textTertiary = Color(0xFFA1A1AA);

  // 테두리
  static const borderSubtle = Color(0xFF3F3F46);

  /// 반투명 테두리
  static const borderSubtleAlpha = Color(0x2BE8E8E8);

  // 상태
  static const statusError = Color(0xFFEF4444);
}

/// 라이트 모드 팔레트.
abstract final class AppLight {
  // 배경
  static const bgCanvas = Color(0xFFE9E9E9);
  static const bgSurface = Color(0xFFFFFFFF);

  /// 밝은 배경 위 반투명 표면
  static const bgSurfaceSubtle = Color(0x63FFFFFF);

  /// 살짝 푸른 기가 도는 캔버스 변형
  static const bgCanvasAlt = Color(0xFFF8FAFC);

  // 글자
  static const textPrimary = Color(0xFF191F28);
  static const textSecondary = Color(0xFF333D48);
  static const textTertiary = Color(0xFF6B7684);
  static const textDisabled = Color(0xFF8B95A1);

  // 테두리
  static const borderDefault = Color(0xFFD1D6DB);
  static const borderSubtle = Color(0xFFE5E8EB);

  /// 반투명 테두리
  static const borderSubtleAlpha = Color(0x2B1C1C1C);

  // 상태
  static const statusError = Color(0xFFB03D3F);
}

/// 팔레트로 분류하기 애매한, 특정 화면에서만 쓰는 색.
abstract final class AppColors {
  /// 미구현 화면 안내 문구
  static const placeholder = Color(0xFF888888);

  /// 하단 네비게이션 아이콘 및 글로우
  static const navIcon = Color(0xFF898989);

  /// 입력 필드 힌트, 네비게이션 테두리
  static const hint = Color(0xFFA7A7A7);

  /// 프로필 사진 기본 배경
  static const avatarBg = Color(0xFFD9D9D9);
}
