import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/auth_service.dart';
import '../../shared/app_colors.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _oldCtrl  = TextEditingController();
  final _newCtrl  = TextEditingController();
  final _confCtrl = TextEditingController();

  bool _oldObscure  = true;
  bool _newObscure  = true;
  bool _loading     = false;

  String? _newError;

  static const _bgColor      = AppColors.backB;
  static const _textColor    = AppColors.mainText;
  static const _captionColor = AppColors.caption;
  static const _surfaceColor = AppColors.surfaceHover;
  static const _bodyColor    = AppColors.body;
  static const _errorColor   = AppColors.error;
  static const _teal         = AppColors.mainColor;

  static final _pwRegex = RegExp(r'^(?=.*[!@#$%^&*(),.?":{}|<>]).{8,}$');

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _confCtrl.dispose();
    super.dispose();
  }

  bool _validate() {
    final newPw = _newCtrl.text;
    if (!_pwRegex.hasMatch(newPw)) {
      setState(() => _newError = '특수문자를 포함해 8자리 이상 입력해주세요.');
      return false;
    }
    if (newPw != _confCtrl.text) {
      setState(() => _newError = '새 비밀번호가 일치하지 않습니다.');
      return false;
    }
    setState(() => _newError = null);
    return true;
  }

  Future<void> _submit() async {
    if (_oldCtrl.text.isEmpty || _newCtrl.text.isEmpty || _confCtrl.text.isEmpty) return;
    if (!_validate()) return;

    setState(() => _loading = true);
    try {
      await AuthService.changePassword(
        oldPassword: _oldCtrl.text,
        newPassword: _newCtrl.text,
      );
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('비밀번호가 변경되었습니다.')),
        );
      }
    } on SessionExpiredException {
      if (mounted) context.go('/login');
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: _errorColor),
        );
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
          '비밀번호 변경',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: _textColor),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: SafeArea(
          child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),

                    // 자물쇠 아이콘
                    Center(
                      child: Container(
                        width: 100, height: 100,
                        decoration: BoxDecoration(color: _surfaceColor, shape: BoxShape.circle),
                        child: Center(
                          child: Image.asset('assets/img/lock.png', width: 50, height: 50),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    const Center(
                      child: Text(
                        '안전한 계정 관리를 위해\n주기적으로 비밀번호를 변경해주세요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: _bodyColor, height: 1.6),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // 현재 비밀번호
                    const Text('현재 비밀번호',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _textColor)),
                    const SizedBox(height: 10),
                    _PasswordField(
                      controller: _oldCtrl,
                      obscure: _oldObscure,
                      onToggle: () => setState(() => _oldObscure = !_oldObscure),
                      hint: 'mirim123!',
                    ),

                    const SizedBox(height: 24),

                    // 새 비밀번호
                    const Text('새 비밀번호',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _textColor)),
                    const SizedBox(height: 10),
                    _PasswordField(
                      controller: _newCtrl,
                      obscure: _newObscure,
                      onToggle: () => setState(() => _newObscure = !_newObscure),
                      hint: 'mirim123!',
                      onChanged: (_) { if (_newError != null) setState(() => _newError = null); },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 13,
                          color: _newError != null ? _errorColor : _captionColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _newError ?? '특수문자를 포함해 8자리 이상 입력해주세요.',
                          style: TextStyle(
                            fontSize: 12,
                            color: _newError != null ? _errorColor : _captionColor,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // 새 비밀번호 확인
                    const Text('새 비밀번호 확인',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _textColor)),
                    const SizedBox(height: 10),
                    _PasswordField(
                      controller: _confCtrl,
                      obscure: true,
                      showToggle: false,
                      hint: '비밀번호를 다시 한 번 입력해주세요.',
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            // 변경하기 버튼
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
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
                      : const Text('변경하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.obscure,
    this.onToggle,
    this.hint = '',
    this.onChanged,
    this.showToggle = true,
  });

  final TextEditingController controller;
  final bool obscure;
  final VoidCallback? onToggle;
  final String hint;
  final ValueChanged<String>? onChanged;
  final bool showToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceHover,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 15, color: AppColors.mainText),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 15, color: AppColors.caption),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          suffixIcon: showToggle
              ? IconButton(
                  icon: Icon(
                    obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: AppColors.caption,
                    size: 20,
                  ),
                  onPressed: onToggle,
                )
              : null,
        ),
      ),
    );
  }
}
