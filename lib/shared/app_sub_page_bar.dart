import 'package:flutter/material.dart';

import 'app_back_button.dart';
import 'app_palette.dart';

/// 하위 화면 공통 상단바. 가운데 제목 + 왼쪽 뒤로가기.
///
/// 배경은 투명이라 [ThemeData.scaffoldBackgroundColor] 가 비쳐 보인다.
///
/// ```dart
/// Scaffold(appBar: const AppSubPageBar(title: '상벌점 내역'), body: ...)
/// ```
class AppSubPageBar extends StatelessWidget implements PreferredSizeWidget {
  const AppSubPageBar({super.key, required this.title, this.onBack});

  final String title;

  /// 뒤로가기 동작. 기본은 이전 화면으로 돌아가기.
  final VoidCallback? onBack;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      leading: AppBackButton(onTap: onBack),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppPalette.of(context).textPrimary,
        ),
      ),
    );
  }
}
