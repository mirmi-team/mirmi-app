import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../shared/submit_button.dart';
import '../../core/services/auth_service.dart';
import '../../shared/app_colors.dart';
import '../../shared/app_palette.dart';

class LoginScreen extends StatefulWidget {
  final String? successMessage;
  const LoginScreen({super.key, this.successMessage});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;
  bool _showBanner = false;
  bool _showErrorBanner = false;
  String? _errorMessage;

  static const _teal = AppBrand.primary;

  // 테마에 따라 바뀌는 색. build 에서 현재 팔레트를 받아 쓴다.
  late AppPalette _palette;
  Color get _errorColor => _palette.statusError;
  Color get _bgColor => _palette.bgCanvas;
  Color get _captainColor => _palette.textTertiary;
  Color get _cardColor => _palette.bgSurface;
  Color get _textColor => _palette.textPrimary;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_rebuild);
    _passwordController.addListener(_rebuild);

    if (widget.successMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _showBanner = true);
        Future.delayed(const Duration(milliseconds: 2800), () {
          if (mounted) setState(() => _showBanner = false);
        });
      });
    }
  }

  void _rebuild() => setState(() {});

  bool get _isValid {
    return _emailController.text.trim().isNotEmpty &&
        _passwordController.text.isNotEmpty;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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
      // 사감이면 관리자 화면으로 들어간다.
      final route = await AuthService.homeRouteForCurrentUser();
      if (!mounted) return;
      context.go(route);
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
    setState(() {
      _errorMessage = msg;
      _showErrorBanner = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _showErrorBanner = true);
      Future.delayed(const Duration(milliseconds: 2800), () {
        if (mounted) setState(() => _showErrorBanner = false);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    _palette = AppPalette.of(context);
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: _bgColor,
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            SafeArea(
              maintainBottomViewPadding: true,
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
                          const SizedBox(height: 60),
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
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: Column(
                      children: [
                        // 이미 좌우 여백이 있는 자리라 버튼 자체 여백은 뺀다.
                        SubmitButton(
                          text: '로그인',
                          loadingButton: _loading,
                          onPressed: _isValid ? _onLogin : null,
                          padding: EdgeInsets.zero,
                        ),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '아직 계정이 없다면 ',
                              style: TextStyle(
                                color: _captainColor,
                                fontSize: 14,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => context.push('/signup'),
                              child: const Text(
                                '회원가입',
                                style: TextStyle(
                                  color: _teal,
                                  fontSize: 14,
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
            if (widget.successMessage != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ClipRect(
                  child: SafeArea(
                    child: AnimatedSlide(
                      offset: _showBanner ? Offset.zero : const Offset(0, -3),
                      duration: const Duration(milliseconds: 400),
                      curve: _showBanner ? Curves.easeOut : Curves.easeIn,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: _teal,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: _teal.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: const BoxDecoration(
                                  color: Colors.white24,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                widget.successMessage!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (_errorMessage != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ClipRect(
                  child: SafeArea(
                    child: AnimatedSlide(
                      offset: _showErrorBanner
                          ? Offset.zero
                          : const Offset(0, -3),
                      duration: const Duration(milliseconds: 400),
                      curve: _showErrorBanner ? Curves.easeOut : Curves.easeIn,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: _errorColor,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: _errorColor.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: const BoxDecoration(
                                  color: Colors.white24,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.priority_high_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: _textColor,
        fontSize: 18,
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
        color: _cardColor,
        borderRadius: BorderRadius.circular(15),
      ),
      child: TextField(
        style: TextStyle(fontSize: 14, color: _textColor),
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: _captainColor, fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 17,
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(15),
      ),
      child: TextField(
        style: TextStyle(fontSize: 14, color: _textColor),
        controller: _passwordController,
        obscureText: _obscurePassword,
        decoration: InputDecoration(
          hintText: 'mirim123!',
          hintStyle: TextStyle(color: _captainColor, fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 17,
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
