import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';
import 'package:mirmi_app/shared/submit_button.dart';
import '../../core/constants/api.dart';
import '../../core/services/auth_service.dart';
import '../../shared/app_field_label.dart';
import '../../shared/app_sub_page_bar.dart';
import '../../shared/app_banner.dart';
import '../../shared/app_palette.dart';
import '../../shared/keyboard_inset.dart';
import '../../shared/app_dialog.dart';

class InquiryScreen extends StatefulWidget {
  const InquiryScreen({super.key});

  @override
  State<InquiryScreen> createState() => _InquiryScreenState();
}

class _InquiryScreenState extends State<InquiryScreen> with AppBannerMixin {
  AppPalette get _palette => AppPalette.of(context);
  Color get _textColor => _palette.textPrimary;
  Color get _captionColor => _palette.textTertiary;

  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _subjectCtrl.text.trim().isNotEmpty &&
      _messageCtrl.text.trim().isNotEmpty;

  Future<void> _submit() async {
    if (!_isValid) return;

    final confirmed = await showConfirmDialog(
      context,
      title: '문의를 보낼까요?',
      message:
          '허위 사실이나 장난성 문의는 삼가주세요.\n'
          '작성자 정보(이름·이메일)가 함께 전송됩니다.',
      confirmText: '보내기',
    );
    if (confirmed != true || !mounted) return;

    setState(() => _loading = true);
    try {
      await AuthService.sendContact(
        subject: _subjectCtrl.text.trim(),
        message: _messageCtrl.text.trim(),
      );
      if (!mounted) return;
      context.pop('문의가 전송되었습니다.');
    } on SessionExpiredException {
      if (mounted) context.go('/login');
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showErrorBanner('$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 배경색은 ThemeData.scaffoldBackgroundColor 가 정한다.
      // 키보드가 올라와도 '문의 보내기' 버튼은 제자리에 둔다.
      // 입력창은 아래 KeyboardInset 안에서 스크롤로 올라온다.
      resizeToAvoidBottomInset: false,
      appBar: const AppSubPageBar(title: '문의 메일보내기'),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            SafeArea(
              // 키보드가 올라오면 padding.bottom 이 0 이 되어 SafeArea 가 잡아주던
              // 하단 여백이 통째로 사라졌다가, 닫히면 다시 생긴다.
              // 여기서는 끄고 아래에서 viewPadding 으로 직접 고정한다.
              bottom: false,
              child: Column(
                children: [
                  Expanded(
                    child: KeyboardInset(
                      // 아래에 문의 보내기 버튼(82)과 안전영역이 이미 있다.
                      below: 82 + MediaQuery.viewPaddingOf(context).bottom,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 40,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '문의하기',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: _textColor,
                              ),
                            ),

                            const SizedBox(height: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppFieldLabel('1. 제목을 작성하여 주세요.'),
                                const SizedBox(height: 8),
                                TextInput(
                                  hintText: '제목을 입력해 주세요.',
                                  maxLines: 1,
                                  controller: _subjectCtrl,
                                  onChanged: (_) => setState(() {}),
                                ),
                                const SizedBox(height: 16),
                                AppFieldLabel('2. 문의 내용을 자세히 작성해 주세요.'),
                                const SizedBox(height: 8),
                                TextInput(
                                  hintText: '이곳에 작성하여 주세요',
                                  maxLines: 5,
                                  controller: _messageCtrl,
                                  onChanged: (_) => setState(() {}),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline_rounded,
                                      color: _captionColor,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '이 메일은 $kContactEmail으로 발송됩니다.',
                                      style: TextStyle(
                                        color: _captionColor,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  SubmitButton(
                    onPressed: _isValid ? _submit : null,
                    text: '문의 보내기',
                    loadingButton: _loading,
                  ),
                  SizedBox(height: MediaQuery.viewPaddingOf(context).bottom),
                ],
              ),
            ),
            buildBanner(),
          ],
        ),
      ),
    );
  }
}

class TextInput extends StatelessWidget {
  final String hintText;
  final int maxLines;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  const TextInput({
    super.key,
    required this.hintText,
    required this.maxLines,
    this.controller,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: TextStyle(color: palette.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: palette.textTertiary, fontSize: 14),
        filled: true,
        fillColor: palette.bgSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
      maxLines: maxLines,
    );
  }
}
