import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/return_service.dart';
import '../../shared/app_palette.dart';
import '../../shared/app_refresh.dart';

/// 복귀 입실 체크용 QR 팝업.
///
/// 학생 화면에 QR을 띄워두면 사감이 스캔한다. 서버 QR은 30초 뒤 만료되므로
/// 팝업이 열려 있는 동안 알아서 다시 받아온다.
Future<void> showReturnQrDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (_) => const _ReturnQrDialog(),
  );
}

class _ReturnQrDialog extends StatefulWidget {
  const _ReturnQrDialog();

  @override
  State<_ReturnQrDialog> createState() => _ReturnQrDialogState();
}

class _ReturnQrDialogState extends State<_ReturnQrDialog> {
  /// QR 이미지를 매번 디코딩하지 않도록 바이트로 들고 있는다.
  Uint8List? _image;
  String? _error;

  /// '515호 | 이제호'
  String _who = '';

  /// 이 QR이 만료되는 시각. 남은 시간 표시와 자동 갱신에 모두 쓴다.
  DateTime? _expiresAt;

  /// 남은 시간을 1초마다 다시 그리는 타이머.
  Timer? _tick;

  /// 만료 직전에 새 QR을 받아오는 타이머. 실패했을 때의 재시도에도 쓴다.
  Timer? _refresh;

  /// 실패 후 다시 시도하기까지 기다리는 시간.
  static const _retryDelay = Duration(seconds: 3);

  /// 지금 화면에 쓸 수 있는 QR 이 있는지. 만료된 그림은 보여줘도 소용없다.
  bool get _hasLiveQr => _image != null && _secondsLeft > 0;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadQr();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _refresh?.cancel();
    super.dispose();
  }

  /// 만료까지 남은 초. 올림해서 30초짜리 QR이 '30초'부터 시작하도록 한다.
  int get _secondsLeft {
    final expires = _expiresAt;
    if (expires == null) return 0;
    final left = expires.difference(DateTime.now());
    return left.isNegative ? 0 : (left.inMilliseconds / 1000).ceil();
  }

  Future<void> _loadUser() async {
    try {
      final user = await AuthService.getMe();
      if (!mounted) return;
      final room = user['room_number'];
      final name = user['username'] as String? ?? '';
      setState(() => _who = room == null ? name : '$room호 | $name');
    } catch (_) {
      // 이름이 없어도 QR은 동작하므로 조용히 넘어간다.
    }
  }

  Future<void> _loadQr() async {
    try {
      final qr = await ReturnService.getMyQr();
      if (!mounted) return;
      setState(() {
        _image = Uint8List.fromList(qr.bytes);
        _expiresAt = qr.expiresAt;
        _error = null;
      });

      // 만료 직전에 새 QR로 바꿔둔다. 남은 시간이 이상하게 짧게 와도
      // 최소 5초는 두고, 화면을 닫으면 dispose 에서 멈춘다.
      final refreshIn = qr.remaining - const Duration(seconds: 1);
      _schedule(
        refreshIn < const Duration(seconds: 5)
            ? const Duration(seconds: 5)
            : refreshIn,
      );
    } on SessionExpiredException {
      if (!mounted) return;
      // 팝업을 먼저 닫지 않으면 로그인 화면 위에 그대로 덮인 채 남는다.
      // 닫고 나면 이 State 가 사라지므로 라우터를 미리 들고 있어야 한다.
      final router = GoRouter.of(context);
      Navigator.of(context).pop();
      router.go('/login');
    } catch (e) {
      if (!mounted) return;
      // 실패해도 멈추지 않는다. 사감 앞에서 한 번 끊겼다고 팝업을 다시
      // 열게 만들면 안 되므로, 짧게 기다렸다가 계속 다시 시도한다.
      setState(
        () => _error = e is ApiException ? e.message : 'QR을 불러오지 못했습니다.',
      );
      _schedule(_retryDelay);
    }
  }

  void _schedule(Duration delay) {
    _refresh?.cancel();
    _refresh = Timer(delay, _loadQr);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Dialog(
      backgroundColor: palette.bgSurface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '모바일 복귀 입실 체크',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: palette.textTertiary),
            ),
            const SizedBox(height: 20),

            // ── QR ────────────────────────────────────────────
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  // QR은 흰 바탕이어야 스캐너가 읽는다. 다크에서도 흰색 유지.
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.antiAlias,
                child: _buildQr(),
              ),
            ),

            const SizedBox(height: 20),
            Text(
              _who,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: palette.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 제목 아래 설명. 쓸 수 있는 QR 이 있을 때만 남은 시간을 센다.
  String get _subtitle {
    if (_hasLiveQr) return '$_secondsLeft초 후에 만료됩니다.';
    if (_error != null) return '다시 시도하는 중입니다…';
    return 'QR을 불러오는 중입니다…';
  }

  Widget _buildQr() {
    // 아직 살아 있는 QR 이 있으면 갱신이 한 번 실패해도 그대로 보여준다.
    // (뒤에서 재시도가 돌고 있다)
    if (_hasLiveQr) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Image.memory(
          _image!,
          fit: BoxFit.contain,
          gaplessPlayback: true,
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            // 흰 바탕 위라 라이트 팔레트 색을 그대로 쓴다.
            style: TextStyle(
              fontSize: 13,
              color: AppPalette.light.textTertiary,
            ),
          ),
        ),
      );
    }
    return const Center(child: AppLoadingIndicator());
  }
}
