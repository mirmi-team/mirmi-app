import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/return_service.dart';
import '../../../core/services/stay_service.dart';
import '../../../shared/app_banner.dart';
import '../../../shared/app_colors.dart';
import '../../../shared/app_nav_bar.dart';
import '../../../shared/app_palette.dart';
import '../../../shared/app_refresh.dart';
import '../../../shared/app_segmented_tabs.dart';
import '../../../shared/app_skeleton.dart';
import '../../../shared/date_format.dart';
import '../admin_player.dart';

/// 복귀/잔류 관리.
///
/// 복귀 현황은 매일 저녁, 잔류·외박은 주 1회 보는 것이라 세그먼트로 가른다.
/// QR 스캔 버튼은 어느 세그먼트에 있든 떠 있다. 복귀 시간대에는 그게 사감의
/// 주된 작업이라 한 번 더 눌러 찾아가게 하면 안 된다.
class AdminReturnTab extends StatefulWidget {
  const AdminReturnTab({super.key});

  @override
  State<AdminReturnTab> createState() => _AdminReturnTabState();
}

class _AdminReturnTabState extends State<AdminReturnTab> with AppBannerMixin {
  /// 0 = 복귀 현황, 1 = 잔류·외박
  int _tabIndex = 0;

  bool _loading = true;
  List<FloorReturnStatus> _floors = const [];
  StayWeek? _week;

  /// 보고 있는 주. 지난주를 넘겨볼 수 있다.
  DateTime _weekDate = DateTime.now();

  /// 펼쳐 둔 호실. 한 번에 하나만 연다.
  int? _openRoom;

  /// 아직 안 들어온 학생만 추리기. 20:30 에 제일 많이 누를 버튼이다.
  bool _onlyMissing = false;

  bool get _isReturn => _tabIndex == 0;

  /// 기상송 미니 플레이어가 떠 있으면 그만큼 더 비워 둔다.
  double get _playerInset => AdminPlayerScope.of(context).isOpen ? 70.0 : 0.0;

  /// 스캔 버튼에 가리지 않도록 넉넉히 비운다.
  EdgeInsets get _listPadding =>
      EdgeInsets.fromLTRB(20, 10, 20, 160 + _playerInset);

  int get _missingCount => _floors.fold(
    0,
    (sum, floor) => sum + floor.students.where((s) => !s.returned).length,
  );

  int get _studentCount =>
      _floors.fold(0, (sum, floor) => sum + floor.students.length);

  String get _countLabel {
    if (!_isReturn) {
      final week = _week;
      if (week == null) return '';
      // 사감이 이 화면을 여는 이유는 안 낸 사람을 찾기 위해서다.
      if (week.notSubmittedCount > 0) return '미신청 ${week.notSubmittedCount}명';
      return '잔류 ${week.stayCount} · 외박 ${week.outingCount}';
    }
    if (_missingCount == 0 && _studentCount > 0) return '전원 복귀';
    return '미복귀 $_missingCount명';
  }

  /// 머리말 숫자를 빨갛게 띄울지. 손봐야 할 것이 남았다는 뜻이다.
  bool get _countIsAlert =>
      _isReturn ? _missingCount > 0 : (_week?.notSubmittedCount ?? 0) > 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    try {
      // 세그먼트를 옮길 때마다 다시 부르지 않도록 둘 다 받아 둔다.
      final results = await Future.wait<Object>([
        ReturnService.getTodayStatus(),
        StayService.getWeek(_weekDate),
      ]);
      if (!mounted) return;
      setState(() {
        _floors = results[0] as List<FloorReturnStatus>;
        _week = results[1] as StayWeek;
        _loading = false;
      });
    } on SessionExpiredException {
      if (mounted) context.go('/login');
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      showErrorBanner('현황을 불러오지 못했습니다.');
    }
  }

  /// 주를 넘길 때는 잔류 쪽만 다시 받는다.
  Future<void> _moveWeek(int weeks) async {
    final next = _weekDate.add(Duration(days: 7 * weeks));
    setState(() {
      _weekDate = next;
      _week = null;
    });
    try {
      final week = await StayService.getWeek(next);
      if (mounted) setState(() => _week = week);
    } on SessionExpiredException {
      if (mounted) context.go('/login');
    } catch (_) {
      if (!mounted) return;
      showErrorBanner('잔류 현황을 불러오지 못했습니다.');
    }
  }

  Future<void> _openScanner() async {
    await context.push('/qr-scan');
    // 스캔하고 돌아오면 현황이 달라져 있다.
    if (mounted) await _load(silent: true);
  }

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone.replaceAll('-', ''));
    if (!await launchUrl(uri)) {
      if (mounted) showErrorBanner('전화를 걸지 못했습니다.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 머리말 ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(
                          '복귀/잔류 관리',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: palette.textPrimary,
                          ),
                        ),
                      ),
                      if (!_loading)
                        Text(
                          _countLabel,
                          style: TextStyle(
                            fontSize: 13,
                            color: _countIsAlert
                                ? palette.statusError
                                : palette.textTertiary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    // 지금 찍으면 어느 칸에 들어가는지 미리 알려준다.
                    _isReturn ? returnSlotNotice() : '이번 주 잔류·외박 신청 현황',
                    style: TextStyle(fontSize: 13, color: palette.textTertiary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AppSegmentedTabs(
                index: _tabIndex,
                labels: const ['복귀 현황', '잔류·외박'],
                onChanged: (i) => setState(() => _tabIndex = i),
              ),
            ),
            const SizedBox(height: 20),

            Expanded(
              child: _isReturn ? _buildReturns(palette) : _buildStay(palette),
            ),
          ],
        ),

        // 세그먼트와 무관하게 항상 떠 있다.
        if (!_loading) _ScanButton(onTap: _openScanner, inset: _playerInset),

        buildBanner(),
      ],
    );
  }

  // ── 복귀 현황 ──────────────────────────────────────────────

  Widget _buildReturns(AppPalette palette) {
    if (_loading) return _skeleton();

    return AppRefreshScrollView(
      onRefresh: () => _load(silent: true),
      slivers: [
        SliverPadding(
          padding: _listPadding,
          sliver: _floors.isEmpty
              ? _empty('복귀 현황이 없습니다.', palette)
              : SliverList.list(
                  children: [
                    _missingToggle(palette),
                    const SizedBox(height: 14),
                    for (final floor in _floors) ...[
                      ?_floorSection(floor, palette),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _missingToggle(AppPalette palette) => Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _onlyMissing = !_onlyMissing),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _onlyMissing ? AppBrand.primary : palette.bgSurface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '미복귀만',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _onlyMissing ? Colors.white : palette.textTertiary,
            ),
          ),
        ),
      ),
    ],
  );

  /// 한 층. 추려서 남는 호실이 없으면 층째로 뺀다.
  Widget? _floorSection(FloorReturnStatus floor, AppPalette palette) {
    final rooms = _roomsOf(floor);
    if (rooms.isEmpty) return null;

    final missing = floor.students.where((s) => !s.returned).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FloorHeader(
          floor: floor.floor,
          label: missing == 0
              ? '전원 복귀'
              : '미복귀 $missing/${floor.students.length}',
          highlight: missing > 0,
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: palette.bgSurface,
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < rooms.length; i++) ...[
                if (i > 0) Divider(color: palette.borderSubtle, height: 1),
                _RoomTile(
                  number: rooms[i].number,
                  students: rooms[i].students,
                  expanded: rooms[i].number == _openRoom,
                  onToggle: () => setState(
                    () => _openRoom = _openRoom == rooms[i].number
                        ? null
                        : rooms[i].number,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }

  /// 서버는 층 단위로만 묶어 준다. 호실별로 다시 묶는 건 여기서 한다.
  List<({int number, List<StudentReturnStatus> students})> _roomsOf(
    FloorReturnStatus floor,
  ) {
    final map = <int, List<StudentReturnStatus>>{};
    for (final student in floor.students) {
      if (_onlyMissing && student.returned) continue;
      (map[student.roomNumber] ??= []).add(student);
    }
    final numbers = map.keys.toList()..sort();
    return [
      for (final number in numbers) (number: number, students: map[number]!),
    ];
  }

  // ── 잔류 · 외박 ────────────────────────────────────────────

  Widget _buildStay(AppPalette palette) {
    final week = _week;
    if (_loading || week == null) return _skeleton();

    return AppRefreshScrollView(
      onRefresh: () => _load(silent: true),
      slivers: [
        SliverPadding(
          padding: _listPadding,
          sliver: SliverList.list(
            children: [
              _weekNav(week, palette),
              const SizedBox(height: 20),
              if (week.entries.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      '이번 주 신청 내역이 없습니다.',
                      style: TextStyle(
                        fontSize: 14,
                        color: palette.textTertiary,
                      ),
                    ),
                  ),
                )
              else ...[
                // 사감이 움직여야 할 것부터 위에 둔다.
                _StayGroup(
                  title: '미신청',
                  entries: week.notSubmitted,
                  alert: true,
                ),
                _StayGroup(title: '잔류', entries: week.staying, onCall: _call),
                _StayGroup(title: '외박', entries: week.outing, onCall: _call),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _weekNav(StayWeek week, AppPalette palette) => Row(
    children: [
      _ArrowButton(icon: Icons.chevron_left, onTap: () => _moveWeek(-1)),
      Expanded(
        child: Column(
          children: [
            Text(
              week.rangeLabel,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '잔류 ${week.stayCount} · 외박 ${week.outingCount}'
              '${week.notSubmittedCount > 0 ? ' · 미신청 ${week.notSubmittedCount}' : ''}',
              style: TextStyle(fontSize: 12, color: palette.textTertiary),
            ),
          ],
        ),
      ),
      _ArrowButton(
        icon: Icons.chevron_right,
        // 다음 주는 아직 신청 기간이 아니라 볼 것이 없다.
        onTap:
            StayService.mondayOf(_weekDate) ==
                StayService.mondayOf(DateTime.now())
            ? null
            : () => _moveWeek(1),
      ),
    ],
  );

  // ── 공통 ──────────────────────────────────────────────────

  Widget _skeleton() => ListView.separated(
    padding: _listPadding,
    itemCount: 3,
    separatorBuilder: (_, _) => const SizedBox(height: 28),
    itemBuilder: (_, _) => const AppSkeleton(height: 170, radius: 12),
  );

  Widget _empty(String text, AppPalette palette) => SliverFillRemaining(
    hasScrollBody: false,
    child: Center(
      child: Text(
        text,
        style: TextStyle(fontSize: 14, color: palette.textTertiary),
      ),
    ),
  );
}

/// 어느 세그먼트에 있든 떠 있는 스캔 버튼.
class _ScanButton extends StatelessWidget {
  const _ScanButton({required this.onTap, required this.inset});

  final VoidCallback onTap;
  final double inset;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 20,
      bottom: appNavBarTotalHeight(context) + inset + 16,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          decoration: BoxDecoration(
            color: AppBrand.primary,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: AppBrand.primary.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.qr_code_scanner, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'QR 스캔',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FloorHeader extends StatelessWidget {
  const _FloorHeader({
    required this.floor,
    required this.label,
    required this.highlight,
  });

  final int floor;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Row(
      children: [
        Text(
          '$floor층',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Divider(color: palette.borderSubtle, height: 1)),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: highlight ? palette.statusError : palette.textTertiary,
          ),
        ),
      ],
    );
  }
}

class _RoomTile extends StatelessWidget {
  const _RoomTile({
    required this.number,
    required this.students,
    required this.expanded,
    required this.onToggle,
  });

  final int number;
  final List<StudentReturnStatus> students;
  final bool expanded;
  final VoidCallback onToggle;

  int get _returned => students.where((s) => s.returned).length;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final allIn = _returned == students.length;
    return Column(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Text(
                  '$number',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
                const Spacer(),
                // 접은 채로도 어느 방이 덜 들어왔는지 보여야 한다.
                Text(
                  '$_returned/${students.length}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: allIn ? FontWeight.w400 : FontWeight.w700,
                    color: allIn ? palette.textTertiary : palette.statusError,
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    size: 22,
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: expanded
              ? Column(
                  children: [
                    Divider(
                      color: palette.borderSubtle,
                      height: 1,
                      indent: 18,
                      endIndent: 18,
                    ),
                    const _SlotHeader(),
                    for (final student in students)
                      _StudentRow(student: student),
                    const SizedBox(height: 6),
                  ],
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// 시간대 세 칸의 머리글. 학생 줄과 같은 너비로 맞춰야 칸이 어긋나지 않는다.
class _SlotHeader extends StatelessWidget {
  const _SlotHeader();

  static const cellWidth = 54.0;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final style = TextStyle(fontSize: 11, color: palette.textTertiary);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 2),
      child: Row(
        children: [
          const Spacer(),
          for (final label in ['바로', '석식', '8시'])
            SizedBox(
              width: cellWidth,
              child: Text(label, textAlign: TextAlign.center, style: style),
            ),
        ],
      ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({required this.student});

  final StudentReturnStatus student;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final checkins = student.checkins;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 11, 18, 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.username,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    // 안 들어온 학생이 눈에 걸려야 한다.
                    color: student.returned
                        ? palette.textPrimary
                        : palette.statusError,
                  ),
                ),
                // 시간대 밖 복귀는 세 칸 어디에도 안 들어간다. 묻히면 안 된다.
                if (checkins.other != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    '기타 ${timeLabel(checkins.other!)}',
                    style: TextStyle(fontSize: 11, color: palette.textTertiary),
                  ),
                ],
              ],
            ),
          ),
          _cell(checkins.immediate, palette),
          _cell(checkins.dinner, palette),
          _cell(checkins.eightPm, palette),
        ],
      ),
    );
  }

  Widget _cell(DateTime? at, AppPalette palette) => SizedBox(
    width: _SlotHeader.cellWidth,
    child: Text(
      at == null ? '—' : timeLabel(at),
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 12,
        fontWeight: at == null ? FontWeight.w400 : FontWeight.w600,
        color: at == null ? palette.textTertiary : palette.textPrimary,
      ),
    ),
  );
}

class _StayGroup extends StatelessWidget {
  const _StayGroup({
    required this.title,
    required this.entries,
    this.onCall,
    this.alert = false,
  });

  final String title;
  final List<StayEntry> entries;

  /// 손봐야 할 묶음. 머리글과 이름을 빨갛게 띄운다.
  final bool alert;

  /// 잔류 학생만 보호자에게 연락할 일이 생긴다. 외박은 집에 있다.
  final void Function(String phone)? onCall;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    if (entries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: alert ? palette.statusError : palette.textPrimary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Divider(color: palette.borderSubtle, height: 1)),
            const SizedBox(width: 12),
            Text(
              '${entries.length}명',
              style: TextStyle(
                fontSize: 12,
                color: alert ? palette.statusError : palette.textTertiary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: palette.bgSurface,
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < entries.length; i++) ...[
                if (i > 0) Divider(color: palette.borderSubtle, height: 1),
                _StayRow(entry: entries[i], onCall: onCall, alert: alert),
              ],
            ],
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }
}

class _StayRow extends StatelessWidget {
  const _StayRow({required this.entry, this.onCall, this.alert = false});

  final StayEntry entry;
  final void Function(String phone)? onCall;

  /// 아직 안 낸 학생. 스크롤 중에도 눈에 걸려야 한다.
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 10, 14),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              entry.roomNumber?.toString() ?? '-',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              entry.username ?? '-',
              style: TextStyle(
                fontSize: 14,
                fontWeight: alert ? FontWeight.w600 : FontWeight.w400,
                color: alert ? palette.statusError : palette.textPrimary,
              ),
            ),
          ),
          // 아이콘만 두면 누구 번호인지 알 수 없다. 줄마다 적어 둔다.
          if (onCall != null && entry.hasPhone) ...[
            Text(
              '보호자 연락처',
              style: TextStyle(fontSize: 12, color: palette.textTertiary),
            ),
            IconButton(
              onPressed: () => onCall!(entry.parentPhone!),
              icon: Icon(Icons.call, size: 19, color: AppBrand.primary),
              tooltip: '보호자에게 전화',
            ),
          ] else
            const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return IconButton(
      onPressed: onTap,
      icon: Icon(
        icon,
        size: 26,
        color: onTap == null ? palette.textDisabled : palette.textSecondary,
      ),
    );
  }
}
