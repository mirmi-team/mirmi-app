import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _showPasswordHint = false;
  bool _loading = false;

  static const _teal = Color(0xFF00CFCD);
  static const _bgColor = Color(0xFFF2F3F5);

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_rebuild);
    _passwordController.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  bool get _isValid {
    final email = _emailController.text.trim();
    final pw = _passwordController.text;
    final hasSpecial = RegExp(
      r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\;'
      r"'`~/]",
    ).hasMatch(pw);
    return email.isNotEmpty && pw.length >= 8 && hasSpecial;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onPasswordChanged(String value) {
    final hasSpecialChar = RegExp(
      r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\;'
      r"'`~/]",
    ).hasMatch(value);
    setState(() {
      _showPasswordHint =
          value.isNotEmpty && !(value.length >= 8 && hasSpecialChar);
    });
  }

  Future<void> _onLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showError('이메일과 비밀번호를 입력해주세요.');
      return;
    }

    setState(() => _loading = true);
    try {
      await AuthService.login(email: email, password: password);
      if (!mounted) return;
      context.go('/home');
    } on ApiException catch (e) {
      if (!mounted) return;
      _showError(e.message);
    } catch (_) {
      if (!mounted) return;
      _showError('서버 연결에 실패했습니다.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: _bgColor,
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 180),
                      Image.asset('assets/img/MIRMI.png', height: 18),
                      const SizedBox(height: 40),
                      _buildLabel('학교 이메일'),
                      const SizedBox(height: 10),
                      _buildTextField(
                        controller: _emailController,
                        hintText: 'example@e-mirim.hs.kr',
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 28),
                      _buildLabel('비밀번호'),
                      const SizedBox(height: 10),
                      _buildPasswordField(),
                      if (_showPasswordHint) ...[
                        const SizedBox(height: 10),
                        const Row(
                          children: [
                            Icon(Icons.info_outline, color: _teal, size: 16),
                            SizedBox(width: 5),
                            Text(
                              '특수문자를 포함해 8자리 이상 입력해주세요.',
                              style: TextStyle(color: _teal, fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: (_loading || !_isValid) ? null : _onLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isValid
                              ? _teal
                              : const Color(0xFFA8A8A8),
                          disabledBackgroundColor: const Color(0xFFA8A8A8),
                          disabledForegroundColor: Colors.white,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                '로그인',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '이미 계정이 없다면 ',
                          style: TextStyle(color: Colors.black54, fontSize: 14),
                        ),
                        GestureDetector(
                          onTap: () => context.push('/signup'),
                          child: const Text(
                            '회원가입',
                            style: TextStyle(
                              color: _teal,
                              fontSize: 14,
                              decoration: TextDecoration.underline,
                              decorationColor: _teal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: _teal,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xffEDEDED)),
      ),
      child: TextField(
        style: const TextStyle(fontSize: 14),
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Color(0xFFA7A7A7), fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xffEDEDED)),
      ),
      child: TextField(
        style: const TextStyle(fontSize: 14),
        controller: _passwordController,
        obscureText: _obscurePassword,
        onChanged: _onPasswordChanged,
        decoration: InputDecoration(
          hintText: 'mirim123!',
          hintStyle: const TextStyle(color: Color(0xFFA7A7A7), fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 12,
          ),
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: Colors.grey,
              size: 22,
            ),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
      ),
    );
  }
}
