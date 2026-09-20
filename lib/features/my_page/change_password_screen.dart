import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/auth_service.dart';
import '../../shared/app_back_button.dart';
import '../../shared/app_palette.dart';
import '../../shared/keyboard_inset.dart';
import '../../shared/app_banner.dart';
import '../../shared/submit_button.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen>
    with AppBannerMixin {
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confCtrl = TextEditingController();

  bool _oldObscure = true;
  bool _newObscure = true;
  bool _loading = false;

  String? _newError;

  AppPalette get _palette => AppPalette.of(context);
  Color get _textColor => _palette.textPrimary;
  Color get _captionColor => _palette.textTertiary;
  Color get _surfaceColor => _palette.bgSurfaceHover;
  Color get _bodyColor => _palette.textSecondary;
  Color get _errorColor => _palette.statusError;

  static final _pwRegex = RegExp(r'^(?=.*[!@#$%^&*(),.?":{}|<>]).{8,}$');

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _confCtrl.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _oldCtrl.text.isNotEmpty &&
      _newCtrl.text.isNotEmpty &&
      _confCtrl.text.isNotEmpty;

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
    if (_oldCtrl.text.isEmpty ||
        _newCtrl.text.isEmpty ||
        _confCtrl.text.isEmpty) {
      return;
    }
    if (!_validate()) return;

    setState(() => _loading = true);
    try {
      await AuthService.changePassword(
        oldPassword: _oldCtrl.text,
        newPassword: _newCtrl.text,
      );
      if (mounted) context.pop();
    } on SessionExpiredException {
      if (mounted) context.go('/login');
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showErrorBanner('$e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 배경색은 ThemeData.scaffoldBackgroundColor 가 정한다.
      // 키보드가 올라와도 하단 버튼은 제자리에 둔다.
      // 입력창은 아래 KeyboardInset 안에서 스크롤로 올라온다.
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: const AppBackButton(),
        title: Text(
          '비밀번호 변경',
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
              // 키보드가 올라오면 padding.bottom 이 0 이 되어 SafeArea 가 잡아주던
              // 하단 여백이 통째로 사라졌다가, 닫히면 다시 생긴다.
              // 여기서는 끄고 아래에서 viewPadding 으로 직접 고정한다.
              bottom: false,
              child: Column(
                children: [
                  Expanded(
                    child: KeyboardInset(
                      // 아래에 변경하기 버튼(82)과 안전영역이 이미 있다.
                      below: 82 + MediaQuery.viewPaddingOf(context).bottom,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 20),

                            Center(
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: _surfaceColor,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Image.asset(
                                    'assets/img/lock.png',
                                    width: 50,
                                    height: 50,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            Center(
                              child: Text(
                                '안전한 계정 관리를 위해\n주기적으로 비밀번호를 변경해주세요.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _bodyColor,
                                  height: 1.6,
                                ),
                              ),
                            ),

                            const SizedBox(height: 32),

                            Text(
                              '현재 비밀번호',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _textColor,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _PasswordField(
                              controller: _oldCtrl,
                              obscure: _oldObscure,
                              onToggle: () =>
                                  setState(() => _oldObscure = !_oldObscure),
                              hint: 'mirim123!',
                              onChanged: (_) => setState(() {}),
                            ),

                            const SizedBox(height: 24),

                            Text(
                              '새 비밀번호',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _textColor,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _PasswordField(
                              controller: _newCtrl,
                              obscure: _newObscure,
                              onToggle: () =>
                                  setState(() => _newObscure = !_newObscure),
                              hint: 'mirim123!',
                              onChanged: (_) =>
                                  setState(() => _newError = null),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 13,
                                  color: _newError != null
                                      ? _errorColor
                                      : _captionColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _newError ?? '특수문자를 포함해 8자리 이상 입력해주세요.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _newError != null
                                        ? _errorColor
                                        : _captionColor,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),

                            Text(
                              '새 비밀번호 확인',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _textColor,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _PasswordField(
                              controller: _confCtrl,
                              obscure: true,
                              showToggle: false,
                              hint: '비밀번호를 다시 한 번 입력해주세요.',
                              onChanged: (_) => setState(() {}),
                            ),

                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
                  ),

                  SubmitButton(
                    onPressed: _isValid ? _submit : null,
                    text: '변경하기',
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
    final palette = AppPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: palette.bgSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        onChanged: onChanged,
        style: TextStyle(fontSize: 15, color: palette.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: 13, color: palette.textTertiary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          suffixIcon: showToggle
              ? IconButton(
                  icon: Icon(
                    obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: palette.textTertiary,
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
