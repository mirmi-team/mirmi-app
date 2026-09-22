import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/auth_service.dart';
import '../../shared/app_sub_page_bar.dart';
import '../../shared/app_colors.dart';
import '../../shared/app_palette.dart';
import '../../shared/app_banner.dart';
import '../../shared/app_dialog.dart';
import '../../shared/submit_button.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen>
    with AppBannerMixin {
  bool _agreed = false;
  bool _loading = false;

  AppPalette get _palette => AppPalette.of(context);
  Color get _textColor => _palette.textPrimary;
  Color get _surfaceColor => _palette.bgSurfaceHover;
  Color get _bodyColor => _palette.textSecondary;
  Color get _borderColor => _palette.borderDefault;

  Future<void> _submit() async {
    if (!_agreed) return;

    final ok = await showConfirmDialog(
      context,
      title: '정말 탈퇴할까요?',
      message: '모든 정보가 삭제되며 복구할 수 없어요.',
      confirmText: '탈퇴하기',
      destructive: true,
    );
    if (ok != true || !mounted) return;

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
      // 배경색은 ThemeData.scaffoldBackgroundColor 가 정한다.
      appBar: const AppSubPageBar(title: '회원 탈퇴'),
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
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: _surfaceColor,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Image.asset(
                            'assets/img/error.png',
                            width: 50,
                            height: 50,
                          ),
                        ),
                      ),
                      const SizedBox(height: 34),
                      Text(
                        '정말 회원 탈퇴를 하시겠어요?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: _textColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '탈퇴 시 모든 정보가 삭제되며,\n복구가 불가능합니다.',
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

                // 동의 체크박스
                GestureDetector(
                  onTap: () => setState(() => _agreed = !_agreed),
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          // 체크하면 브랜드색으로 채우고, 아니면 표면색 + 테두리.
                          // (흰 박스에 흰 체크는 라이트에서 보이지 않는다)
                          color: _agreed
                              ? AppBrand.primary
                              : _palette.bgSurface,
                          border: Border.all(color: _borderColor),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: _agreed
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 14,
                              )
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
                SubmitButton(
                  onPressed: _agreed ? _submit : null,
                  text: '회원 탈퇴하기',
                  errorButton: true,
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
