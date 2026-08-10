import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/auth_service.dart';
import '../../shared/app_colors.dart';

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
    final results = await Future.wait([
      _checkToken(),
      _playAnimation(),
    ]);

    if (!mounted) return;
    context.go(results[0] as bool ? '/home' : '/login');
  }

  Future<bool> _checkToken() async {
    try {
      await AuthService.getMe();
      return true;
    } catch (_) {
      return false;
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
      backgroundColor: AppColors.backB,
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
                child: Image.asset(
                  'assets/img/logo.png',
                  width: 170,
                ),
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