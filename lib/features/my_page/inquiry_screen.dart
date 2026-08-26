import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';
import 'package:mirmi_app/shared/submit_button.dart';
import '../../core/services/auth_service.dart';
import '../../shared/app_banner.dart';
import '../../shared/app_colors.dart';

class InquiryScreen extends StatefulWidget {
  const InquiryScreen({super.key});

  @override
  State<InquiryScreen> createState() => _InquiryScreenState();
}

class _InquiryScreenState extends State<InquiryScreen> with AppBannerMixin {
  static const _bgColor = AppColors.backB;
  static const _textColor = AppColors.mainText;
  static const _captionColor = AppColors.caption;
  static const _surfaceColor = AppColors.surfaceHover;
  static const _teal = AppColors.mainColor;
  static const _bodyColor = AppColors.body;

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
          '문의 메일보내기',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: _textColor,
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 40,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
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
                              GuideText(text: '1. 제목을 작성하여 주세요.'),
                              const SizedBox(height: 8),
                              TextInput(
                                hintText: '제목을 입력해 주세요.',
                                maxLines: 1,
                                controller: _subjectCtrl,
                                onChanged: (_) => setState(() {}),
                              ),
                              const SizedBox(height: 16),
                              GuideText(text: '2. 문의 내용을 자세히 작성해 주세요.'),
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
                                  Icon(Icons.info_outline_rounded, color: _captionColor, size: 16),
                                  const SizedBox(width: 8),
                                  Text('이 메일은 mirmi.dev@gmail.com으로 발송됩니다.', style: TextStyle(color: _captionColor, fontSize: 13)),
                                ],
                              )
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  SubmitButton(
                    onPressed: _isValid ? _submit : null,
                    text: '문의 보내기',
                    loadingButton: _loading,
                  ),
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

class GuideText extends StatelessWidget {
  final String text;
  const GuideText({super.key, required this.text});

  static const _textColor = AppColors.mainText;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: TextStyle(color: _textColor, fontSize: 13));
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

  static const _textColor = AppColors.mainText;
  static const _cardColor = AppColors.card2;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: TextStyle(color: _textColor, fontSize: 14),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: AppColors.hint, fontSize: 14),
        filled: true,
        fillColor: _cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
      maxLines: maxLines,
    );
  }
}
