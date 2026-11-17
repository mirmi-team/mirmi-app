import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_palette.dart';

/// 상벌점 표기 규칙. 관리자 목록·상세 시트와 학생 내역 화면이 같은 규칙을
/// 써야 해서 여기 모아 둔다.
///
/// 미르미는 상점과 벌점을 하나의 총점으로 묶어 부호로 구분한다.
/// (마이페이지·상벌점 내역 화면도 같은 방식이다)

/// '-3점' / '0점' / '+5점'.
String meritLabel(int score) => score > 0 ? '+$score점' : '$score점';

/// 벌점은 빨강, 상점은 청록, 0은 흐리게.
Color meritColor(int score, AppPalette palette) {
  if (score < 0) return palette.statusError;
  if (score > 0) return AppBrand.primary;
  return palette.textTertiary;
}
