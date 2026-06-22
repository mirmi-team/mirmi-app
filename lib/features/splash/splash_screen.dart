import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
    // 로고만 1초
    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      logoOffset = -45; // 위로 이동
      secondOpacity = 1; // 두 번째 이미지 등장
    });

    // 애니메이션 시간
    await Future.delayed(const Duration(milliseconds: 800));

    // 잠깐 유지
    await Future.delayed(const Duration(milliseconds: 700));

    // 화면 전체 페이드아웃
    setState(() {
      screenOpacity = 0;
    });

    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: AnimatedOpacity(
        opacity: screenOpacity,
        duration: const Duration(milliseconds: 500),
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedSlide(
                offset: Offset(0, logoOffset / 180),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeInOut,
                child: Image.asset(
                  'assets/img/logo.png',
                  width: 150,
                ),
              ),

              AnimatedOpacity(
                opacity: secondOpacity,
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeInOut,
                child: Padding(
                  padding: const EdgeInsets.only(top: 40),
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