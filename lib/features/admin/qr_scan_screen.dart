import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/return_service.dart';
import '../../shared/app_colors.dart';
import '../../shared/app_palette.dart';
import '../../shared/date_format.dart';

/// 시간대 밖 복귀. 기록은 됐으니 빨강이 아니고, 제 시간도 아니니 청록도
/// 아니다. 팔레트에 경고색이 없어 이 화면에서만 쓴다.
const _warning = Color(0xFFF59E0B);

/// 이미 찍은 QR. 잘못된 것도 아니고 새로 기록된 것도 아니라 무채색으로 둔다.
/// (밝은 회색은 카드의 흰 글자가 안 읽혀서 쓸 수 없다)
const _neutral = Color(0xFF52525B);

/// 한 번 처리한 QR 의 기록.
class _Handled {
  /// 마지막으로 처리를 끝낸 시각. 유예 시간과 기억 유지 기간을 여기서 잰다.
  DateTime at = DateTime.now();

  /// 복귀가 확정된 학생 이름. 만료·무효로 실패한 QR 은 null 로 남는다.
  String? name;

  /// '이미 스캔했습니다' 를 이미 띄웠는지.
  bool announced = false;
}

/// 학생 QR 을 스캔해 복귀를 확정하는 화면.
///
/// 한 명 찍고 닫지 않는다. 복귀 시간대에는 줄을 서기 때문에, 카메라는 계속
/// 떠 있고 결과 카드만 갈아끼운다.
class AdminQrScanScreen extends StatefulWidget {
  const AdminQrScanScreen({super.key});

  @override
  State<AdminQrScanScreen> createState() => _AdminQrScanScreenState();
}

class _AdminQrScanScreenState extends State<AdminQrScanScreen>
    with SingleTickerProviderStateMixin {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );

  /// 찍힌 순간 화면 전체를 한 번 물들인다.
  ///
  /// 사감은 학생 얼굴과 휴대폰을 보고 있어서 아래쪽 카드가 바뀌는 걸 놓친다.
  /// 곁눈에도 걸리도록 크게 한 번 번쩍이고 바로 걷는다.
  late final _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  Color _flashColor = AppBrand.primary;

  /// 이미 처리한 토큰과 그 시각.
  ///
  /// 카메라는 같은 QR 을 초당 여러 번 읽는다. 걸러내지 않으면 한 사람이
  /// 지나가는 동안 서버에 수십 번 보낸다.
  final _handled = <String, _Handled>{};

  /// 서버가 QR 을 30초만 인정한다. 그만큼만 기억하면 충분하다.
  static const _memory = Duration(seconds: 60);

  /// 결과 카드가 떠 있는 시간.
  static const _cardDuration = Duration(seconds: 5);

  /// 찍힌 직후 이만큼은 같은 QR 을 다시 읽어도 조용히 넘긴다.
  ///
  /// 카메라는 성공 직후에도 같은 QR 을 곧바로 다시 읽는다. 이걸 두지 않으면
  /// 성공 카드가 뜨자마자 '이미 스캔했습니다' 로 덮여서, 사감은 찍힌 걸
  /// 보지도 못하고 중복 문구만 보게 된다.
  ///
  /// 성공 카드가 다 내려간 뒤에야 중복을 알리도록 카드 수명과 같게 둔다.
  static const _grace = _cardDuration;

  final List<ReturnScan> _scanned = [];

  ReturnScan? _last;

  /// 찍힌 시각. 카드가 5초간 떠 있으면서 여러 번 다시 그려지는데,
  /// 그릴 때마다 DateTime.now() 를 읽으면 시각이 슬금슬금 바뀐다.
  DateTime? _lastAt;

  String? _error;

  /// 이미 찍은 QR 을 또 들이댄 학생 이름.
  String? _duplicate;

  bool _busy = false;

  /// 결과가 바뀔 때마다 올린다. 같은 학생을 다시 찍어도 카드가 새로
  /// 올라오도록 AnimatedSwitcher 에 줄 열쇠로 쓴다.
  int _resultSeq = 0;

  Timer? _cardTimer;

  @override
  void initState() {
    super.initState();
    // 스캔하는 동안 화면이 꺼지면 줄 세워 둔 학생을 다시 세워야 한다.
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    _cardTimer?.cancel();
    _flash.dispose();
    WakelockPlus.disable();
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_busy) return;
    final raw = capture.barcodes.isEmpty
        ? null
        : capture.barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;

    final seen = _seen(raw);
    if (seen != null) {
      // 실패했던 QR 은 조용히 넘긴다. 찍힌 적이 없으니 '이미 스캔' 이 아니다.
      if (seen.name != null) _announceDuplicate(seen);
      return;
    }
    _verify(raw);
  }

  /// 같은 QR 을 또 들이대면 알려준다.
  ///
  /// 한 QR 당 한 번만 띄운다. 카메라가 계속 읽고 있어서 그때마다 띄우면
  /// 화면이 쉴 새 없이 번쩍인다.
  void _announceDuplicate(_Handled seen) {
    if (seen.announced) return;
    // 찍은 직후에 또 읽힌 것. 학생이 아직 QR 을 내리는 중이다.
    if (DateTime.now().difference(seen.at) < _grace) return;
    seen.announced = true;
    HapticFeedback.selectionClick();
    _flashWith(_neutral);
    _showResult(duplicateName: seen.name);
  }

  /// 결과 카드를 띄우고 5초 뒤 자동으로 내린다.
  ///
  /// 계속 띄워두면 다음 학생 차례에 앞사람 이름이 남아 있어, 방금 찍은
  /// 것인지 앞사람 것인지 헷갈린다.
  void _showResult({ReturnScan? scan, String? error, String? duplicateName}) {
    _cardTimer?.cancel();
    setState(() {
      _last = scan;
      _lastAt = scan == null ? null : DateTime.now();
      _error = error;
      _duplicate = duplicateName;
      _resultSeq++;
    });
    _cardTimer = Timer(_cardDuration, () {
      if (!mounted) return;
      setState(() {
        _last = null;
        _lastAt = null;
        _error = null;
        _duplicate = null;
      });
    });
  }

  /// 색을 바꿔 물들인다. 꽉 찬 상태에서 시작해 사그라든다.
  void _flashWith(Color color) {
    setState(() => _flashColor = color);
    _flash.reverse(from: 1);
  }

  /// 이미 처리한 QR 이면 그 기록을, 처음 보는 것이면 null.
  _Handled? _seen(String token) {
    final now = DateTime.now();
    _handled.removeWhere((_, h) => now.difference(h.at) > _memory);
    return _handled[token];
  }

  Future<void> _verify(String token) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    // 성공이든 실패든 같은 토큰을 다시 보낼 이유가 없다. 만료된 QR 이면
    // 학생이 새로 띄우고, 그때는 토큰이 달라진다.
    final handled = _handled[token] = _Handled();

    try {
      final scan = await ReturnService.verify(token);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      unawaited(SystemSound.play(SystemSoundType.click));
      // 시간대 밖이면 기록은 되지만 세 칸 어디에도 안 들어간다. 색을 갈라
      // 사감이 그 자리에서 알아채게 한다.
      _flashWith(scan.returnType == null ? _warning : AppBrand.primary);
      // 이름을 남겨 둬야 같은 QR 을 또 들이댔을 때 누구인지 말해줄 수 있다.
      handled.name = scan.username;
      // 유예는 응답이 돌아온 지금부터 센다. 서버가 느렸다고 줄어들면 안 된다.
      handled.at = DateTime.now();
      setState(() {
        _scanned.insert(0, scan);
        _busy = false;
      });
      _showResult(scan: scan);
    } on SessionExpiredException {
      if (!mounted) return;
      context.go('/login');
    } on ApiException catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      _flashWith(AppDark.statusError);
      setState(() => _busy = false);
      _showResult(error: e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showResult(error: '복귀 확인에 실패했습니다.');
    }
  }

  void _openScannedList() {
    final palette = AppPalette.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      builder: (_) => _ScannedListSheet(scanned: _scanned),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final side = constraints.maxWidth * 0.68;
          final window = Rect.fromCenter(
            center: Offset(
              constraints.maxWidth / 2,
              constraints.maxHeight / 2 - 40,
            ),
            width: side,
            height: side,
          );
          return Stack(
            fit: StackFit.expand,
            children: [
              MobileScanner(
                controller: _controller,
                onDetect: _onDetect,
                // 창 밖에 비친 QR 까지 읽으면 엉뚱한 학생이 찍힌다.
                scanWindow: window,
                errorBuilder: (context, error) => _CameraError(error: error),
              ),
              CustomPaint(painter: _ScrimPainter(window: window)),
              // 틀과 글자 위로는 덮지 않는다. 번쩍이는 중에도 읽혀야 한다.
              _flashOverlay(),
              _frame(window),
              _topBar(),
              _bottom(),
            ],
          );
        },
      ),
    );
  }

  Widget _flashOverlay() => Positioned.fill(
    child: IgnorePointer(
      child: AnimatedBuilder(
        animation: _flash,
        builder: (context, _) {
          // easeOut 이라 꽉 찬 채로 잠깐 머물다 빠르게 사라진다.
          final t = Curves.easeOut.transform(_flash.value);
          return ColoredBox(color: _flashColor.withValues(alpha: t * 0.5));
        },
      ),
    ),
  );

  /// 스캔 틀. 번쩍일 때 같이 물들고 굵어져서 어디를 봐야 하는지 알려준다.
  Widget _frame(Rect window) => Positioned.fromRect(
    rect: window,
    child: IgnorePointer(
      child: AnimatedBuilder(
        animation: _flash,
        builder: (context, _) {
          final t = Curves.easeOut.transform(_flash.value);
          return Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: Color.lerp(Colors.white, _flashColor, t)!,
                width: 2 + t * 3,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
          );
        },
      ),
    ),
  );

  // Positioned 없이 Stack 에 넣으면 꽉 채우는 제약이 내려와 Row 가 화면
  // 높이를 다 먹고, 안의 것들이 세로 가운데로 내려간다.
  Widget _topBar() => Positioned(
    top: 0,
    left: 0,
    right: 0,
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 20, 0),
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
            ),
            const Spacer(),
            Text(
              returnSlotNotice(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _bottom() => Positioned(
    left: 20,
    right: 20,
    bottom: 0,
    child: SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '학생 QR을 네모 안에 비춰주세요',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          _resultCard(),
          const SizedBox(height: 12),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _scanned.isEmpty ? null : _openScannedList,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                _scanned.isEmpty
                    ? '아직 스캔한 학생이 없습니다'
                    : '방금 스캔한 학생 ${_scanned.length}명  ›',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  /// 앞 카드는 아래로 내려가고 새 카드가 아래에서 올라온다.
  ///
  /// 바뀌는 게 글자뿐이면 찍힌 건지 앞사람 것이 남은 건지 분간이 안 된다.
  /// 자리를 비켜주는 움직임이 있어야 '바뀌었다'가 읽힌다.
  Widget _resultCard() => ClipRect(
    child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      // 기본 레이아웃은 가운데 정렬이라 높이가 다르면 카드가 떠 보인다.
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: Alignment.bottomCenter,
        children: [...previousChildren, ?currentChild],
      ),
      // AnimatedSwitcher 가 나가는 쪽 애니메이션을 거꾸로 돌려 주므로,
      // '아래에서 올라온다' 한 방향만 써도 나갈 때는 아래로 내려간다.
      transitionBuilder: (child, animation) => SlideTransition(
        position: Tween(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(animation),
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: _resultChild(),
    ),
  );

  Widget _resultChild() {
    final duplicate = _duplicate;
    if (duplicate != null) {
      return _Card(
        key: ValueKey(_resultSeq),
        color: _neutral,
        icon: Icons.done_all,
        title: duplicate,
        subtitle: '이미 스캔했습니다',
      );
    }

    final error = _error;
    if (error != null) {
      return _Card(
        key: ValueKey(_resultSeq),
        color: AppDark.statusError,
        icon: Icons.priority_high_rounded,
        title: error,
      );
    }

    final scan = _last;
    if (scan == null) {
      // 빈 자리도 같은 높이를 차지해야 아래 글자가 들썩이지 않는다.
      return const SizedBox(key: ValueKey('empty'), height: 92);
    }
    // 시간대 밖이면 기록은 되지만 세 칸 어디에도 안 들어간다. 묻히면 안 된다.
    final isOther = scan.returnType == null;
    return _Card(
      key: ValueKey(_resultSeq),
      // 회색은 '아무 일도 없었다'로 읽힌다. 기록은 됐으니 경고색을 쓴다.
      color: isOther ? _warning : AppBrand.primary,
      icon: isOther ? Icons.info_outline : Icons.check,
      title: scan.username,
      subtitle: scan.detailLabel,
      trailing: '${scan.typeLabel}\n${timeLabel(_lastAt ?? DateTime.now())}',
    );
  }
}

/// 스캔 창만 남기고 바깥을 어둡게. 카메라에 잡히는 게 많아도 어디를 비춰야
/// 하는지 바로 보인다.
class _ScrimPainter extends CustomPainter {
  const _ScrimPainter({required this.window});

  final Rect window;

  @override
  void paint(Canvas canvas, Size size) {
    final outside = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()
        ..addRRect(RRect.fromRectAndRadius(window, const Radius.circular(16))),
    );
    canvas.drawPath(
      outside,
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(_ScrimPainter oldDelegate) => oldDelegate.window != window;
}

class _Card extends StatelessWidget {
  const _Card({
    super.key,
    required this.color,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 92),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: Colors.white24,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Text(
              trailing!,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            denied ? '카메라 권한이 없습니다.\n설정에서 카메라를 허용해 주세요.' : '카메라를 열지 못했습니다.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
        ),
      ),
    );
  }
}

/// 이번에 찍은 학생들. 제대로 찍혔는지 확인용이라 최신순으로만 보여준다.
class _ScannedListSheet extends StatelessWidget {
  const _ScannedListSheet({required this.scanned});

  final List<ReturnScan> scanned;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 14),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: palette.borderSubtle,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '방금 스캔한 학생 ${scanned.length}명',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              itemCount: scanned.length,
              separatorBuilder: (_, _) =>
                  Divider(color: palette.borderSubtle, height: 1),
              itemBuilder: (context, i) {
                final scan = scanned[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              scan.username,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: palette.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              scan.detailLabel,
                              style: TextStyle(
                                fontSize: 12,
                                color: palette.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        scan.typeLabel,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: scan.returnType == null
                              ? palette.textTertiary
                              : AppBrand.primary,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
