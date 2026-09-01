import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/services/auth_service.dart';
import 'app_colors.dart';

/// 앱 공통 상단바. MIRMI 로고와 프로필 사진을 보여준다.
///
/// 프로필 사진은 이 위젯이 직접 불러오고, 마이페이지에 다녀오면 다시 읽으므로
/// 사진을 바꾼 게 바로 반영된다.
///
/// ```dart
/// Scaffold(appBar: const AppTopBar(), body: ...)
/// ```
class AppTopBar extends StatefulWidget implements PreferredSizeWidget {
  const AppTopBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  State<AppTopBar> createState() => _AppTopBarState();
}

class _AppTopBarState extends State<AppTopBar> {
  String? _profileImage;

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
  }

  Future<void> _loadProfileImage() async {
    try {
      final user = await AuthService.getMe();
      if (mounted) {
        setState(() => _profileImage = user['profile_image'] as String?);
      }
    } on SessionExpiredException {
      if (mounted) context.go('/login');
    } catch (_) {
      // 프로필 사진은 없어도 화면이 동작하므로 조용히 넘어간다.
    }
  }

  Future<void> _goToMyPage() async {
    await context.push('/my');
    _loadProfileImage();
  }

  @override
  Widget build(BuildContext context) {
    final imageProvider = (_profileImage != null && _profileImage!.isNotEmpty)
        ? NetworkImage(_profileImage!) as ImageProvider
        : null;

    return AppBar(
      backgroundColor: AppColors.backB,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: 20,
      // 푸시된 화면에서도 왼쪽에 기본 뒤로가기 화살표가 생기지 않게 한다.
      automaticallyImplyLeading: false,
      title: Image.asset('assets/img/MIRMI.png', height: 18),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 20),
          child: GestureDetector(
            onTap: _goToMyPage,
            child: CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.avatarBg,
              backgroundImage: imageProvider,
              child: imageProvider == null
                  ? const Icon(Icons.person, size: 20, color: Colors.white)
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}
