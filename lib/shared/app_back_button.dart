import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_palette.dart';

/// 공통 뒤로가기 버튼. 원형 배경 위에 chevron 하나.
///
/// 배경은 [AppPalette.bgSurfaceHover] 를 쓴다. 다크에서 27272A,
/// 라이트에서 흰색이라 어느 쪽 캔버스 위에서도 원이 또렷하게 보인다.
/// (borderSubtle 은 라이트 캔버스 E9E9E9 와 거의 같아 묻힌다)
class AppBackButton extends StatelessWidget {
  const AppBackButton({
    super.key,
    this.onTap,
    this.padding = const EdgeInsets.only(left: 16),
  });

  /// 누르면 할 일. 기본은 이전 화면으로 돌아가기.
  final VoidCallback? onTap;

  /// 버튼 주변 여백. AppBar leading 에 넣을 때는 기본값 그대로 쓰면 된다.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: padding,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap ?? () => context.pop(),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: palette.bgSurfaceHover,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.chevron_left, color: palette.textPrimary, size: 22),
        ),
      ),
    );
  }
}
