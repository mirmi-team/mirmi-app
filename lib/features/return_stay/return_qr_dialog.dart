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

  /// 만료 직전에 새 QR을 받아오는 타이머.
  Timer? _refresh;

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
      _refresh?.cancel();
      _refresh = Timer(
        refreshIn < const Duration(seconds: 5)
            ? const Duration(seconds: 5)
            : refreshIn,
        _loadQr,
      );
    } on SessionExpiredException {
      if (mounted) context.go('/login');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'QR을 불러오지 못했습니다.');
    }
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
              // QR을 받기 전에는 남은 시간을 모르니 발급 시간(30초)을 그대로 보여준다.
              _image == null ? '30초 후에 만료됩니다.' : '$_secondsLeft초 후에 만료됩니다.',
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
                child: _buildQr(palette),
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

  Widget _buildQr(AppPalette palette) {
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
    if (_image == null) return const Center(child: AppLoadingIndicator());
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Image.memory(_image!, fit: BoxFit.contain, gaplessPlayback: true),
    );
  }
}
