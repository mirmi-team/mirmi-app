import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mirmi_app/shared/submit_button.dart';
import '../../core/services/auth_service.dart';
import '../../shared/app_colors.dart';

class LogoutScreen extends StatefulWidget {
  const LogoutScreen({super.key});

  @override
  State<LogoutScreen> createState() => _LogoutScreenState();
}

class _LogoutScreenState extends State<LogoutScreen> {
  bool _loading = false;

  static const _bgColor = AppColors.backB;
  static const _textColor = AppColors.mainText;
  static const _surfaceColor = AppColors.surfaceHover;
  static const _bodyColor = AppColors.body;

  Future<void> _logout() async {
    setState(() => _loading = true);
    try {
      await AuthService.logout();
    } finally {
      if (mounted) context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _surfaceColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chevron_left,
                color: _textColor,
                size: 22,
              ),
            ),
          ),
        ),
        title: const Text(
          '로그아웃',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: _textColor,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: _surfaceColor,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Image.asset(
                        'assets/img/log_out.png',
                        width: 45,
                        height: 45,
                      ),
                    ),
                  ),
                  const SizedBox(height: 34),
                  const Text(
                    '로그아웃 하시겠어요?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '로그아웃 시 현재 계정에서\n안전하게 로그아웃됩니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      color: _bodyColor,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),

            SubmitButton(onPressed: _logout, text: '로그아웃'),
          ],
        ),
      ),
    );
  }
}
