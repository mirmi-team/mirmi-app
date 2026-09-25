import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/auth_service.dart';
import '../../shared/app_palette.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double logoOffset = 0;
  double secondOpacity = 0;
  double screenOpacity = 1;

  @override
  void initState() {
    super.initState();
    _startAnimation();
  }

  Future<void> _startAnimation() async {
    // 애니메이션과 토큰 검증 병렬 실행
    final results = await Future.wait([_checkToken(), _playAnimation()]);

    if (!mounted) return;
    // 토큰이 살아 있으면 역할에 맞는 화면으로. (사감은 관리자 화면)
    context.go(results[0] as String? ?? '/login');
  }

  /// 로그인 상태면 들어갈 경로, 아니면 null.
  Future<String?> _checkToken() async {
    try {
      return await AuthService.homeRouteForCurrentUser(throwOnError: true);
    } catch (_) {
      return null;
    }
  }

  Future<void> _playAnimation() async {
    await Future.delayed(const Duration(milliseconds: 1000));
    setState(() {
      logoOffset = -45;
      secondOpacity = 1;
    });
    await Future.delayed(const Duration(milliseconds: 1900));
    setState(() {
      screenOpacity = 0;
    });
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.of(context).bgCanvas,
      body: AnimatedOpacity(
        opacity: screenOpacity,
        duration: const Duration(milliseconds: 300),
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedSlide(
                offset: Offset(0, logoOffset / 180),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeInOut,
                child: Image.asset('assets/img/logo.png', width: 170),
              ),

              AnimatedOpacity(
                opacity: secondOpacity,
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeInOut,
                child: Padding(
                  padding: const EdgeInsets.only(top: 35),
                  child: Image.asset(
                    'assets/img/MIRMI.png', // 두 번째 이미지
                    width: 70,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
