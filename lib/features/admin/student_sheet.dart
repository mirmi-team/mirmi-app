import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/student_service.dart';
import '../../shared/app_banner.dart';
import '../../shared/app_colors.dart';
import '../../shared/app_field_label.dart';
import '../../shared/app_palette.dart';
import '../../shared/app_skeleton.dart';
import '../../shared/date_format.dart';
import '../../shared/submit_button.dart';
import 'merit_style.dart';

/// 학생 한 명을 눌렀을 때 아래에서 올라오는 시트.
///
/// 상벌점과 호실을 저장 버튼 하나로 묶지 않는다. 상벌점은 총점을 덮어쓰는 게
/// 아니라 더하는 동작이라, 호실만 고치려던 사람이 같이 눌리면 점수가 두 번
/// 들어간다. 그래서 각각 자기 버튼을 갖는다.
///
/// [onChanged] 는 서버에 뭔가 실제로 나갔을 때 불린다. 목록을 다시 받아야
/// 하는지 부모가 이것으로 판단한다. (시트는 스와이프로도 닫혀서 반환값으로는
/// 놓치는 경우가 생긴다)
Future<void> showStudentSheet(
  BuildContext context, {
  required Student student,
  required int roomNumber,
  required List<int> roomNumbers,
  required VoidCallback onChanged,
}) {
  final palette = AppPalette.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: palette.bgSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.85,
    ),
    builder: (_) => _StudentSheet(
      student: student,
      roomNumber: roomNumber,
      roomNumbers: roomNumbers,
      onChanged: onChanged,
    ),
  );
}

class _StudentSheet extends StatefulWidget {
  const _StudentSheet({
    required this.student,
    required this.roomNumber,
    required this.roomNumbers,
    required this.onChanged,
  });

  final Student student;
  final int roomNumber;
  final List<int> roomNumbers;
  final VoidCallback onChanged;

  @override
  State<_StudentSheet> createState() => _StudentSheetState();
}

class _StudentSheetState extends State<_StudentSheet> with AppBannerMixin {
  /// 현재 총점. 부여할 때마다 서버를 다시 부르지 않고 여기서 더한다.
  late int _score = widget.student.meritScore;

  late int _roomNumber = widget.roomNumber;

  List<MeritLogEntry> _logs = const [];
  List<MeritReason> _reasons = const [];
  bool _loading = true;

  /// 내역은 최근 3건만 보여주고, 눌러서 펼친다.
  bool _showAllLogs = false;

  MeritReason? _reason;

  /// 줄 점수의 크기. 사유를 고르면 그 사유의 기본 점수가 들어온다.
  int _amount = 0;

  bool _giving = false;
  bool _moving = false;

  static const _maxAmount = 50;

  AppPalette get _palette => AppPalette.of(context);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<Object>([
        StudentService.getMeritLogs(widget.student.id),
        StudentService.getReasons(),
      ]);
      if (!mounted) return;
      setState(() {
        _logs = results[0] as List<MeritLogEntry>;
        _reasons = results[1] as List<MeritReason>;
        _loading = false;
      });
    } on SessionExpiredException {
      if (!mounted) return;
      Navigator.of(context).pop();
      context.go('/login');
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      showErrorBanner('상벌점 정보를 불러오지 못했습니다.');
    }
  }

  bool get _canGive => _reason != null && _amount > 0 && !_giving;
  bool get _canMove => _roomNumber != widget.roomNumber && !_moving;

  Future<void> _give() async {
    final reason = _reason;
    if (reason == null || !_canGive) return;
    setState(() => _giving = true);
    try {
      await StudentService.giveMerit(
        userId: widget.student.id,
        type: reason.type,
        score: _amount,
        reason: reason.reason,
      );
      widget.onChanged();
      if (!mounted) return;
      // 시트는 닫지 않는다. 한 학생에게 연달아 줄 일이 있다.
      final delta = reason.isReward ? _amount : -_amount;
      setState(() {
        _score += delta;
        _logs = [
          MeritLogEntry(
            id: DateTime.now().millisecondsSinceEpoch,
            type: reason.type,
            score: delta,
            reason: reason.reason,
            createdAt: DateTime.now(),
          ),
          ..._logs,
        ];
        _reason = null;
        _amount = 0;
        _giving = false;
      });
      showSuccessBanner('${reason.reason} ${meritLabel(delta)}');
    } on SessionExpiredException {
      if (!mounted) return;
      Navigator.of(context).pop();
      context.go('/login');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _giving = false);
      showErrorBanner(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _giving = false);
      showErrorBanner('상벌점을 주지 못했습니다.');
    }
  }

  Future<void> _move() async {
    if (!_canMove) return;
    setState(() => _moving = true);
    try {
      await StudentService.changeRoom(widget.student.id, _roomNumber);
      widget.onChanged();
      if (!mounted) return;
      // 호실이 바뀌면 이 학생은 다른 방으로 가므로 시트를 닫는다.
      Navigator.of(context).pop();
    } on SessionExpiredException {
      if (!mounted) return;
      Navigator.of(context).pop();
      context.go('/login');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _moving = false);
      showErrorBanner(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _moving = false);
      showErrorBanner('호실을 옮기지 못했습니다.');
    }
  }

  Future<void> _pickReason() async {
    final picked = await showModalBottomSheet<MeritReason>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _palette.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _ReasonPicker(reasons: _reasons, selected: _reason),
    );
    if (picked != null && mounted) {
      setState(() {
        _reason = picked;
        // 사유마다 기본 점수가 정해져 있다. 매번 떠올릴 필요 없게 채워주고,
        // 그래도 다르게 주고 싶으면 ± 로 고친다.
        _amount = picked.defaultScore.abs();
      });
    }
  }

  Future<void> _pickRoom() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _palette.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      builder: (context) =>
          _RoomPicker(rooms: widget.roomNumbers, selected: _roomNumber),
    );
    if (picked != null && mounted) setState(() => _roomNumber = picked);
  }

  @override
  Widget build(BuildContext context) {
    final palette = _palette;
    return SafeArea(
      child: Stack(
        children: [
          Column(
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
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _header(palette),
                      const SizedBox(height: 18),
                      _scoreCard(palette),
                      const SizedBox(height: 24),

                      // ── 상벌점 주기 ──────────────────────────
                      const AppFieldLabel('상벌점 주기'),
                      const SizedBox(height: 10),
                      _FieldBox(
                        onTap: _loading ? null : _pickReason,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _reason?.reason ?? '사유를 선택하세요',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _reason == null
                                      ? palette.textTertiary
                                      : palette.textPrimary,
                                ),
                              ),
                            ),
                            if (_reason != null)
                              Text(
                                meritLabel(_reason!.signedScore),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: meritColor(
                                    _reason!.signedScore,
                                    palette,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.keyboard_arrow_down,
                              size: 20,
                              color: palette.textTertiary,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      _stepper(palette),
                      const SizedBox(height: 14),
                      SubmitButton(
                        text: '부여하기',
                        padding: EdgeInsets.zero,
                        loadingButton: _giving,
                        onPressed: _canGive ? _give : null,
                      ),

                      const SizedBox(height: 24),
                      Divider(color: palette.borderSubtle, height: 1),
                      const SizedBox(height: 24),

                      // ── 호실 변경 ────────────────────────────
                      const AppFieldLabel('호실 변경'),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _FieldBox(
                              onTap: _pickRoom,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '$_roomNumber호',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: palette.textPrimary,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.keyboard_arrow_down,
                                    size: 20,
                                    color: palette.textTertiary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 104,
                            child: SubmitButton(
                              text: '변경하기',
                              padding: EdgeInsets.zero,
                              loadingButton: _moving,
                              onPressed: _canMove ? _move : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // 시트는 화면 위쪽에 붙어있지 않아서 상태바 여백을 빼야 제자리에 온다.
          MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: buildBanner(),
          ),
        ],
      ),
    );
  }

  Widget _header(AppPalette palette) {
    final student = widget.student;
    final parts = [
      if (student.grade != null && student.classNo != null)
        '${student.grade}학년 ${student.classNo}반',
      '${widget.roomNumber}호',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          student.username,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          parts.join(' · '),
          style: TextStyle(fontSize: 13, color: palette.textTertiary),
        ),
      ],
    );
  }

  Widget _scoreCard(AppPalette palette) {
    final visible = _showAllLogs ? _logs : _logs.take(3).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: palette.bgSurfaceHover,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '현재 상벌점',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: palette.textPrimary,
                  ),
                ),
              ),
              Text(
                meritLabel(_score),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: meritColor(_score, palette),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: palette.borderSubtle, height: 1),
          const SizedBox(height: 4),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: AppSkeleton(height: 14),
            )
          else if (_logs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                '받은 상벌점이 없습니다.',
                style: TextStyle(fontSize: 13, color: palette.textTertiary),
              ),
            )
          else
            for (final log in visible) _logRow(log, palette),
          if (_logs.length > 3 && !_showAllLogs)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _showAllLogs = true),
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '전체 보기',
                      style: TextStyle(
                        fontSize: 13,
                        color: palette.textTertiary,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: palette.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _logRow(MeritLogEntry log, AppPalette palette) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Text(
          '${twoDigit(log.createdAt.month)}/${twoDigit(log.createdAt.day)}',
          style: TextStyle(fontSize: 12, color: palette.textTertiary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            log.reason,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: palette.textSecondary),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          meritLabel(log.score),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: meritColor(log.score, palette),
          ),
        ),
      ],
    ),
  );

  /// 사유를 고르기 전에는 만질 수 없다. 기준 점수가 정해지지 않은 상태다.
  Widget _stepper(AppPalette palette) {
    final enabled = _reason != null;
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: palette.bgSurfaceHover,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: palette.borderSubtle),
      ),
      child: Row(
        children: [
          _StepButton(
            icon: Icons.remove,
            onTap: enabled && _amount > 1
                ? () => setState(() => _amount--)
                : null,
          ),
          Expanded(
            child: Center(
              child: Text(
                enabled ? '$_amount점' : '-',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: enabled ? palette.textPrimary : palette.textTertiary,
                ),
              ),
            ),
          ),
          _StepButton(
            icon: Icons.add,
            onTap: enabled && _amount < _maxAmount
                ? () => setState(() => _amount++)
                : null,
          ),
        ],
      ),
    );
  }
}

/// 눌러서 고르는 칸. 건의 폼의 카테고리 칸과 같은 규격이되, 시트 배경이
/// 이미 bgSurface 라 한 단계 올린 색과 테두리로 구분한다.
class _FieldBox extends StatelessWidget {
  const _FieldBox({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: palette.bgSurfaceHover,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: palette.borderSubtle),
        ),
        child: child,
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 54,
        height: 54,
        child: Icon(
          icon,
          size: 20,
          color: onTap == null ? palette.textDisabled : palette.textPrimary,
        ),
      ),
    );
  }
}

/// 상점과 벌점을 한 목록에 두고 부호로 가른다.
///
/// 사유마다 상점인지 벌점인지가 정해져 있어서, 따로 토글을 두면 '청소 우수'를
/// 벌점으로 주는 모순이 생긴다.
class _ReasonPicker extends StatelessWidget {
  const _ReasonPicker({required this.reasons, required this.selected});

  final List<MeritReason> reasons;
  final MeritReason? selected;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final rewards = reasons.where((r) => r.isReward).toList();
    final penalties = reasons.where((r) => !r.isReward).toList();

    return SafeArea(
      child: SingleChildScrollView(
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
              '사유 선택',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            if (reasons.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Text(
                  '등록된 사유가 없습니다.',
                  style: TextStyle(fontSize: 14, color: palette.textTertiary),
                ),
              ),
            for (final reason in rewards) _tile(context, reason, palette),
            if (rewards.isNotEmpty && penalties.isNotEmpty)
              Divider(
                color: palette.borderSubtle,
                height: 1,
                indent: 16,
                endIndent: 16,
              ),
            for (final reason in penalties) _tile(context, reason, palette),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, MeritReason reason, AppPalette palette) {
    final isSelected = selected?.id == reason.id;
    return ListTile(
      title: Text(
        reason.reason,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? AppBrand.primary : palette.textPrimary,
        ),
      ),
      trailing: Text(
        meritLabel(reason.signedScore),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: meritColor(reason.signedScore, palette),
        ),
      ),
      onTap: () => Navigator.of(context).pop(reason),
    );
  }
}

class _RoomPicker extends StatelessWidget {
  const _RoomPicker({required this.rooms, required this.selected});

  final List<int> rooms;
  final int selected;

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
            '호실 선택',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: rooms.length,
              itemBuilder: (context, i) {
                final room = rooms[i];
                final isSelected = room == selected;
                return ListTile(
                  title: Text(
                    '$room호',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected
                          ? AppBrand.primary
                          : palette.textPrimary,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(
                          Icons.check,
                          color: AppBrand.primary,
                          size: 20,
                        )
                      : null,
                  onTap: () => Navigator.of(context).pop(room),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
