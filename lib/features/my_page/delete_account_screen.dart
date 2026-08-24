import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/auth_service.dart';
import '../../shared/app_colors.dart';
import '../../shared/app_banner.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen>
    with AppBannerMixin {
  bool _agreed = false;
  bool _loading = false;

  static const _bgColor      = AppColors.backB;
  static const _textColor    = AppColors.mainText;
  static const _captionColor = AppColors.caption;
  static const _surfaceColor = AppColors.surfaceHover;
  static const _teal         = AppColors.mainColor;
  static const _bodyColor    = AppColors.body;

  Future<void> _submit() async {
    if (!_agreed) return;
    setState(() => _loading = true);
    try {
      await AuthService.deleteAccount();
      if (mounted) context.go('/login');
    } on SessionExpiredException {
      if (mounted) context.go('/login');
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showErrorBanner('탈퇴 실패: $e');
      }
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
              width: 36, height: 36,
              decoration: BoxDecoration(color: _surfaceColor, shape: BoxShape.circle),
              child: const Icon(Icons.chevron_left, color: _textColor, size: 22),
            ),
          ),
        ),
        title: const Text(
          '회원 탈퇴',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: _textColor),
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  SizedBox(height: 20),
                  // 경고 아이콘
                  Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      color: _surfaceColor,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Image.asset('assets/img/error.png', width: 50, height: 50),
                    ),
                  ),
                  const SizedBox(height: 34),
                  const Text(
                    '정말 회원 탈퇴를 하시겠어요?',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _textColor),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '탈퇴 시 모든 정보가 삭제되며,\n복구가 불가능합니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, color: _bodyColor, height: 1.6),
                  ),
                ],
              ),
            ),

            // 동의 체크박스
            GestureDetector(
              onTap: () => setState(() => _agreed = !_agreed),
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      color: _agreed ? _teal : Colors.white,
                      
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: _agreed
                        ? const Icon(Icons.check, color: Colors.white, size: 14)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '위 내용을 확인하였으며, 회원 탈퇴에 동의합니다.',
                    style: TextStyle(fontSize: 14, color: _textColor),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // 탈퇴 버튼
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: (_agreed && !_loading) ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _teal,
                    disabledBackgroundColor: _surfaceColor,
                    disabledForegroundColor: _captionColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: _loading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('회원 탈퇴하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
            ),
          ),
          buildBanner(),
        ],
      ),
    );
  }
}
