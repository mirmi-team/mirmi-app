import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/auth_service.dart';

enum _Step { email, password, studentInfo, dormInfo }

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  _Step _step = _Step.email;

  // email step
  final _emailController = TextEditingController();
  final _verificationController = TextEditingController();
  bool _emailVerified = false;
  bool _codeSent = false;
  bool _sendingCode = false;
  bool _verifyingCode = false;
  Timer? _timer;
  int _remainingSeconds = 300;

  // password step
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _showPasswordHint = false;

  // student info step
  final _nameController = TextEditingController();
  final _gradeController = TextEditingController(text: '');
  final _classController = TextEditingController(text: '');
  String _gender = '남자';

  // dorm info step
  final _dormRoomController = TextEditingController();
  String _dormRegion = '서울•경기•인천';
  String? _roomFieldError;

  bool _loading = false;
  bool _goingForward = true;

  // inline field errors
  String? _emailFieldError;
  String? _codeFieldError;
  String? _confirmPasswordError;
  String? _nameFieldError;

  static const _teal = Color(0xFF00CFCD);
  static const _bgColor = Color(0xFFF2F3F5);

  @override
  void initState() {
    super.initState();
    for (final c in [
      _passwordController,
      _confirmPasswordController,
      _nameController,
      _gradeController,
      _classController,
      _dormRoomController,
    ]) {
      c.addListener(_rebuild);
    }
    _emailController.addListener(() => setState(() => _emailFieldError = null));
    _verificationController.addListener(() => setState(() => _codeFieldError = null));
    _confirmPasswordController.addListener(() => setState(() => _confirmPasswordError = null));
    _nameController.addListener(() => setState(() => _nameFieldError = null));
    _dormRoomController.addListener(() => setState(() => _roomFieldError = null));
  }

  void _rebuild() => setState(() {});

  bool get _isCurrentStepValid {
    switch (_step) {
      case _Step.email:
        return _emailVerified ||
            (_codeSent && _verificationController.text.trim().isNotEmpty);
      case _Step.password:
        final pw = _passwordController.text;
        final confirm = _confirmPasswordController.text;
        final hasSpecial = RegExp(
          r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\;'
          r"'`~/]",
        ).hasMatch(pw);
        return pw.isNotEmpty &&
            confirm.isNotEmpty &&
            pw == confirm &&
            pw.length >= 8 &&
            hasSpecial;
      case _Step.studentInfo:
        final grade = int.tryParse(_gradeController.text) ?? 0;
        final classNo = int.tryParse(_classController.text) ?? 0;
        return _nameController.text.trim().isNotEmpty &&
            grade >= 1 && grade <= 3 &&
            classNo >= 1 && classNo <= 6;
      case _Step.dormInfo:
        return _dormRoomController.text.trim().isNotEmpty;
    }
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _remainingSeconds = 300);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remainingSeconds <= 0) {
        _timer?.cancel();
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  String get _timerText {
    final m = _remainingSeconds ~/ 60;
    final s = _remainingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _emailController.dispose();
    _verificationController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _gradeController.dispose();
    _classController.dispose();
    _dormRoomController.dispose();
    super.dispose();
  }

  // ── API actions ────────────────────────────────────────────────

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _emailFieldError = '이메일을 입력해주세요.');
      return;
    }
    setState(() => _sendingCode = true);
    try {
      await AuthService.sendVerificationCode(email);
      if (!mounted) return;
      setState(() => _codeSent = true);
      _startTimer();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _emailFieldError = e.message);
    } catch (_) {
      if (!mounted) return;
      _showError('서버 연결에 실패했습니다.');
    } finally {
      if (mounted) setState(() => _sendingCode = false);
    }
  }

  Future<void> _verifyCode() async {
    final email = _emailController.text.trim();
    final code = _verificationController.text.trim();
    if (code.isEmpty) {
      setState(() => _codeFieldError = '인증번호를 입력해주세요.');
      return;
    }
    setState(() => _verifyingCode = true);
    try {
      await AuthService.verifyCode(email, code);
      if (!mounted) return;
      _timer?.cancel();
      setState(() {
        _goingForward = true;
        _emailVerified = true;
        _step = _Step.password;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _codeFieldError = e.message);
    } catch (_) {
      if (!mounted) return;
      _showError('서버 연결에 실패했습니다.');
    } finally {
      if (mounted) setState(() => _verifyingCode = false);
    }
  }

  Future<void> _onNext() async {
    switch (_step) {
      case _Step.email:
        if (_emailVerified) {
          setState(() { _goingForward = true; _step = _Step.password; });
        } else {
          await _verifyCode();
        }

      case _Step.password:
        final pw = _passwordController.text;
        final confirm = _confirmPasswordController.text;
        if (pw.isEmpty || confirm.isEmpty) {
          setState(() => _confirmPasswordError = '비밀번호를 입력해주세요.');
          return;
        }
        if (pw != confirm) {
          setState(() => _confirmPasswordError = '비밀번호가 일치하지 않습니다.');
          return;
        }
        final hasSpecial = RegExp(
          r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\;'
          r"'`~/]",
        ).hasMatch(pw);
        if (pw.length < 8 || !hasSpecial) {
          setState(() => _confirmPasswordError = '특수문자를 포함해 8자리 이상 입력해주세요.');
          return;
        }
        setState(() { _goingForward = true; _step = _Step.studentInfo; });

      case _Step.studentInfo:
        if (_nameController.text.trim().isEmpty) {
          setState(() => _nameFieldError = '이름을 입력해주세요.');
          return;
        }
        if (_gradeController.text.isEmpty || _classController.text.isEmpty) {
          setState(() => _nameFieldError = '학년과 반을 입력해주세요.');
          return;
        }
        setState(() { _goingForward = true; _step = _Step.dormInfo; });

      case _Step.dormInfo:
        await _submit();
    }
  }

  Future<void> _submit() async {
    final roomText = _dormRoomController.text.trim();
    if (roomText.isEmpty) {
      _showError('기숙사 호실을 입력해주세요.');
      return;
    }

    setState(() => _loading = true);
    try {
      await AuthService.register(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        username: _nameController.text.trim(),
        grade: int.parse(_gradeController.text),
        classNo: int.parse(_classController.text),
        roomNumber: int.parse(roomText),
        canStaying: _dormRegion == '경기 외',
      );
      if (!mounted) return;
      _showInfo('회원가입이 완료되었습니다.');
      context.go('/login');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _roomFieldError = e.message);
    } catch (_) {
      if (!mounted) return;
      _showError('서버 연결에 실패했습니다.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onBack() {
    switch (_step) {
      case _Step.email:
        context.pop();
      case _Step.password:
        setState(() { _goingForward = false; _step = _Step.email; });
      case _Step.studentInfo:
        setState(() { _goingForward = false; _step = _Step.password; });
      case _Step.dormInfo:
        setState(() { _goingForward = false; _step = _Step.studentInfo; });
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  void _showInfo(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: _teal),
    );
  }

  // ── Build ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: _bgColor,
        resizeToAvoidBottomInset: false,
        body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 4),
              child: IconButton(
                icon: const Icon(Icons.chevron_left, size: 28),
                onPressed: _onBack,
                color: Colors.black87,
              ),
            ),
            Expanded(
              child: ClipRect(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    layoutBuilder: (currentChild, previousChildren) => Stack(
                      alignment: Alignment.topLeft,
                      children: [
                        ...previousChildren,
                        ?currentChild,
                      ],
                    ),
                    transitionBuilder: (child, animation) {
                      final entering = child.key == ValueKey(_step);
                      final tween = _goingForward
                          ? (entering
                              ? Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                              : Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero))
                          : (entering
                              ? Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero)
                              : Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero));
                      return SlideTransition(
                        position: tween.animate(
                          CurvedAnimation(parent: animation, curve: Curves.easeInOut),
                        ),
                        child: child,
                      );
                    },
                    child: SizedBox(
                      key: ValueKey(_step),
                      width: double.infinity,
                      child: _buildCurrentStep(),
                    ),
                  ),
                ),
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildCurrentStep() {
    return switch (_step) {
      _Step.email => _buildEmailStep(),
      _Step.password => _buildPasswordStep(),
      _Step.studentInfo => _buildStudentInfoStep(),
      _Step.dormInfo => _buildDormInfoStep(),
    };
  }

  // ── Step 1: Email ──────────────────────────────────────────────

  Widget _buildEmailStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        _buildTitle('본인 확인을 위해\n인증을 진행해주세요.'),
        const SizedBox(height: 36),
        _buildLabel('이메일'),
        const SizedBox(height: 10),
        _buildFieldWithButton(
          controller: _emailController,
          hintText: 'example@e-mirim.hs.kr',
          keyboardType: TextInputType.emailAddress,
          enabled: !_emailVerified,
          buttonLabel: _sendingCode ? '...' : (_emailVerified ? '발송 완료' : (_codeSent ? '인증번호 다시 보내기' : '인증 번호 보내기')),
          buttonDisabled: _emailVerified || _sendingCode,
          buttonHighlighted: _codeSent && !_emailVerified,
          onButtonTap: _sendCode,
        ),
        if (_emailFieldError != null) ...[
          const SizedBox(height: 6),
          _buildInlineError(_emailFieldError!),
        ] else ...[
          const SizedBox(height: 6),
          _buildHint('미림마이스터고등학교 전용이메일을 입력해주세요.'),
        ],
        const SizedBox(height: 24),
        _buildLabel('인증번호 입력'),
        const SizedBox(height: 10),
        _buildTextField(
          controller: _verificationController,
          hintText: '이메일로 발송된 인증번호를 입력해 주세요.',
          keyboardType: TextInputType.number,
          enabled: !_emailVerified,
        ),
        if (_codeFieldError != null) ...[
          const SizedBox(height: 6),
          _buildInlineError(_codeFieldError!),
        ] else if (_codeSent && !_emailVerified) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.timer_outlined, color: _teal, size: 14),
              const SizedBox(width: 4),
              Text(
                _timerText,
                style: TextStyle(
                  fontSize: 12,
                  color: _remainingSeconds <= 60 ? Colors.redAccent : _teal,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                '후 만료됩니다.',
                style: TextStyle(fontSize: 12, color: _teal),
              ),
            ],
          ),
        ] else if (_emailVerified) ...[
          const SizedBox(height: 8),
          _buildHint('이메일 인증이 완료되었습니다.'),
        ],
        const SizedBox(height: 40),
      ],
    );
  }

  // ── Step 2: Password ───────────────────────────────────────────

  Widget _buildPasswordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        RichText(
          text: const TextSpan(
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              height: 1.4,
              color: _teal,
            ),
            children: [
              TextSpan(text: 'MIRMI'),
              TextSpan(text: '에서 사용할\n비밀번호를 입력해주세요.'),
            ],
          ),
        ),
        const SizedBox(height: 36),
        _buildLabel('비밀번호'),
        const SizedBox(height: 10),
        _buildPasswordFieldWidget(
          controller: _passwordController,
          hintText: 'mirim123!',
          obscure: _obscurePassword,
          onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
          onChanged: (v) {
            final hasSpecial = RegExp(
              r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\;'
              r"'`~/]",
            ).hasMatch(v);
            setState(() {
              _showPasswordHint = v.isNotEmpty && !(v.length >= 8 && hasSpecial);
            });
          },
        ),
        if (_showPasswordHint) ...[
          const SizedBox(height: 6),
          _buildHint('특수문자를 포함해 8자리 이상 입력해주세요.'),
        ],
        const SizedBox(height: 16),
        _buildPasswordFieldWidget(
          controller: _confirmPasswordController,
          hintText: '비밀번호를 다시 한 번 입력해주세요.',
          obscure: _obscureConfirm,
          onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
        ),
        if (_confirmPasswordError != null) ...[
          const SizedBox(height: 6),
          _buildInlineError(_confirmPasswordError!),
        ],
        const SizedBox(height: 40),
      ],
    );
  }

  // ── Step 3: Student Info ───────────────────────────────────────

  Widget _buildStudentInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        _buildTitle('학생 정보를\n입력해 주세요.'),
        const SizedBox(height: 36),
        _buildLabel('이름'),
        const SizedBox(height: 6),
        _buildHint('본인 이름을 정확하게 적어주세요.'),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _nameController,
          hintText: '',
          inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
        ),
        if (_nameFieldError != null) ...[
          const SizedBox(height: 6),
          _buildInlineError(_nameFieldError!),
        ],
        const SizedBox(height: 28),
        _buildLabel('학년과 반을 선택해주세요.'),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildNumberInput(_gradeController),
            const SizedBox(width: 8),
            const Text('학년', style: TextStyle(fontSize: 15)),
            const SizedBox(width: 16),
            _buildNumberInput(_classController),
            const SizedBox(width: 8),
            const Text('반', style: TextStyle(fontSize: 15)),
          ],
        ),
        Builder(builder: (_) {
          final grade = int.tryParse(_gradeController.text) ?? 0;
          final classNo = int.tryParse(_classController.text) ?? 0;
          final gradeInvalid = _gradeController.text.isNotEmpty && (grade < 1 || grade > 3);
          final classInvalid = _classController.text.isNotEmpty && (classNo < 1 || classNo > 6);
          if (!gradeInvalid && !classInvalid) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (gradeInvalid) _buildInlineError('학년은 1~3 사이로 입력해주세요.'),
                if (classInvalid) _buildInlineError('반은 1~6 사이로 입력해주세요.'),
              ],
            ),
          );
        }),
        const SizedBox(height: 28),
        _buildLabel('성별'),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildRadio(
                label: '남자',
                selected: _gender == '남자',
                onTap: () => setState(() => _gender = '남자')),
            const SizedBox(width: 24),
            _buildRadio(
                label: '여자',
                selected: _gender == '여자',
                onTap: () => setState(() => _gender = '여자')),
          ],
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  // ── Step 4: Dorm Info ──────────────────────────────────────────

  Widget _buildDormInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        _buildTitle('기숙사 정보를\n입력해 주세요.'),
        const SizedBox(height: 36),
        _buildLabel('기숙사 호실'),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 75,
              child: _buildTextField(
                controller: _dormRoomController,
                hintText: '515',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 10),
            const Text('호', style: TextStyle(fontSize: 15)),
          ],
        ),
        if (_roomFieldError != null) ...[
          const SizedBox(height: 6),
          _buildInlineError(_roomFieldError!),
        ] else ...[
          const SizedBox(height: 6),
          _buildHint('배정 받은 호실을 정확하게 적어주세요.'),
        ],
        const SizedBox(height: 28),
        _buildLabel('거주 지역'),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildRadio(
                label: '서울•경기•인천',
                selected: _dormRegion == '서울•경기•인천',
                onTap: () => setState(() => _dormRegion = '서울•경기•인천')),
            const SizedBox(width: 24),
            _buildRadio(
                label: '경기 외',
                selected: _dormRegion == '경기 외',
                onTap: () => setState(() => _dormRegion = '경기 외')),
          ],
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  // ── Footer ─────────────────────────────────────────────────────

  String get _footerButtonLabel {
    if (_step == _Step.dormInfo) return '완료';
    return '다음으로';
  }

  bool get _footerLoading =>
      _loading || (_step == _Step.email && _verifyingCode);

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: (_footerLoading || !_isCurrentStepValid) ? null : _onNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isCurrentStepValid ? _teal : const Color(0xFFA8A8A8),
                disabledBackgroundColor: const Color(0xFFA8A8A8),
                disabledForegroundColor: Colors.white,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: _footerLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      _footerButtonLabel,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Shared widgets ─────────────────────────────────────────────

  Widget _buildTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: _teal,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.4,
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: _teal,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildHint(String text) {
    return Row(
      children: [
        const Icon(Icons.info_outline, color: _teal, size: 14),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: _teal, fontSize: 12)),
      ],
    );
  }

  Widget _buildInlineError(String text) {
    return Row(
      children: [
        const Icon(Icons.info_outline, color: Colors.redAccent, size: 14),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    bool enabled = true,
    TextAlign textAlign = TextAlign.start,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: enabled ? Colors.white : const Color(0xFFEEEEEE),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEDEDED)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        enabled: enabled,
        textAlign: textAlign,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Color(0xFFA7A7A7), fontSize: 13),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildPasswordFieldWidget({
    required TextEditingController controller,
    required String hintText,
    required bool obscure,
    required VoidCallback onToggle,
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEDEDED)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Color(0xFFA7A7A7), fontSize: 13),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          suffixIcon: IconButton(
            icon: Icon(
              obscure
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: Colors.grey,
              size: 20,
            ),
            onPressed: onToggle,
          ),
        ),
      ),
    );
  }

  Widget _buildFieldWithButton({
    required TextEditingController controller,
    required String hintText,
    required String buttonLabel,
    required bool buttonDisabled,
    required VoidCallback onButtonTap,
    TextInputType? keyboardType,
    bool enabled = true,
    bool buttonHighlighted = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: enabled ? Colors.white : const Color(0xFFEEEEEE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEDEDED)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              enabled: enabled,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: const TextStyle(color: Color(0xFFA7A7A7), fontSize: 13),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
              ),
            ),
          ),
          GestureDetector(
            onTap: buttonDisabled ? null : onButtonTap,
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: buttonDisabled
                      ? const Color(0xFFDDDDDD)
                      : buttonHighlighted
                          ? _teal
                          : const Color(0xFFA7A7A7),
                ),
              ),
              child: Text(
                buttonLabel,
                style: TextStyle(
                  fontSize: 12,
                  color: buttonDisabled
                      ? Colors.grey
                      : buttonHighlighted
                          ? _teal
                          : Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberInput(TextEditingController controller) {
    return SizedBox(
      width: 56,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFEDEDED)),
        ),
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14),
          decoration: const InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildRadio({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? _teal : const Color(0xFFD0D0D0),
            ),
            child: selected
                ? const Icon(Icons.check, color: Colors.white, size: 14)
                : null,
          ),
          const SizedBox(width: 8),
          Text(label,
              style:
                  const TextStyle(fontSize: 14, color: Colors.black87)),
        ],
      ),
    );
  }
}
