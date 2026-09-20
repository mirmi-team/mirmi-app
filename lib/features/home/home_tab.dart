import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/laundry_service.dart';
import '../../core/services/notice_service.dart';
import '../../core/services/schedule_service.dart';
import '../../core/utils/app_clock.dart';
import '../../shared/app_banner.dart';
import '../../shared/app_colors.dart';
import '../../shared/app_palette.dart';
import '../../shared/app_refresh.dart';
import '../../shared/app_skeleton.dart';
import '../laundry/laundry_status_section.dart';

/// 복귀 체크 종류. 지금 시각에 해당하는 하나만 홈에 보여준다.
enum ReturnCheckType {
  /// 8시 복귀가 끝난 뒤부터 다음 날 석식 복귀 전까지
  immediate('바로 복귀'),

  /// 17:20 ~ 18:20
  dinner('석식 복귀'),

  /// 18:20 ~ 20:30
  evening('8시 복귀');

  const ReturnCheckType(this.label);
  final String label;

  /// 분 단위 경계값. 겹치지 않고 하루 전체를 덮는다.
  static ReturnCheckType at(DateTime now) {
    final minutes = now.hour * 60 + now.minute;
    if (minutes >= 17 * 60 + 20 && minutes < 18 * 60 + 20) return dinner;
    if (minutes >= 18 * 60 + 20 && minutes < 20 * 60 + 30) return evening;
    return immediate;
  }
}

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with AppBannerMixin {
  AppPalette get _palette => AppPalette.of(context);
  Color get _textColor => _palette.textPrimary;

  bool _loading = true;

  String? _username;
  int? _roomNumber;
  Notice? _latestNotice;

  int? _floor;
  List<Map<String, dynamic>> _machines = const [];
  List<Map<String, dynamic>> _todaySchedule = const [];
  List<DormSchedule> _schedules = const [];

  ReturnCheckType _returnType = ReturnCheckType.immediate;
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _returnType = ReturnCheckType.at(AppClock.now());
    // 시간대가 바뀌면 복귀 카드도 바뀌어야 하므로 1분마다 확인한다.
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      final next = ReturnCheckType.at(AppClock.now());
      if (next != _returnType && mounted) setState(() => _returnType = next);
    });
    _load();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    try {
      // 서로 의존하지 않는 요청은 동시에 보낸다. 순서대로 기다리면
      // 요청 하나당 0.4초씩 그대로 더해진다.
      // 공지와 세탁기는 독립이라 하나가 실패해도 나머지는 보여준다.
      final userFuture = AuthService.getMe();
      final noticeFuture = NoticeService.getLatestNotice().catchError(
        (_) => null,
      );
      final machinesFuture = LaundryService.getMachines().catchError(
        (_) => <Map<String, dynamic>>[],
      );
      final schedulesFuture = ScheduleService.getAll().catchError(
        (_) => <DormSchedule>[],
      );

      final user = await userFuture;
      final roomNumber = user['room_number'] as int?;
      final floor = roomNumber == null ? null : roomNumber ~/ 100;

      // 층을 알아야 부를 수 있어서 이것만 뒤에 온다.
      // 세탁기 페이지와 같은 소스. 내 예약뿐 아니라 다른 학생 사용 현황도 들어있다.
      final todaySchedule = floor == null
          ? <Map<String, dynamic>>[]
          : await LaundryService.getSchedule(
              date: AppClock.now(),
              floor: floor,
            ).catchError((_) => <Map<String, dynamic>>[]);

      final notice = await noticeFuture;
      final machines = await machinesFuture;
      final schedules = await schedulesFuture;

      if (!mounted) return;
      setState(() {
        _username = user['username'] as String?;
        _roomNumber = roomNumber;
        _floor = floor;
        _latestNotice = notice;
        _machines = floor == null
            ? machines
            : (machines.where((m) => (m['id'] as int) ~/ 10 == floor).toList()
                ..sort((a, b) => (a['id'] as int).compareTo(b['id'] as int)));
        _todaySchedule = todaySchedule;
        _schedules = schedules;
        _loading = false;
      });
    } on SessionExpiredException {
      if (mounted) context.go('/login');
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      showErrorBanner('정보를 불러오지 못했습니다.');
    }
  }

  /// 이번 달에 있는 일정만, 날짜 순으로.
  List<DormSchedule> get _thisMonthSchedules {
    final now = DateTime.now();
    final list =
        _schedules
            .where((s) => s.date.year == now.year && s.date.month == now.month)
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AppRefreshScrollView(
          onRefresh: () => _load(silent: true),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 50, 20, 120),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ── 인사말 ────────────────────────────────
                  AppSkeletonSwitcher(
                    loading: _loading,
                    skeleton: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppSkeleton(width: 120, height: 26),
                        SizedBox(height: 8),
                        AppSkeleton(width: 200, height: 26),
                      ],
                    ),
                    child: Text(
                      '안녕하세요.\n'
                      '${_roomNumber ?? '-'}호 ${_username ?? ''}님',
                      style: TextStyle(
                        fontSize: 24,
                        height: 1.35,
                        fontWeight: FontWeight.w800,
                        color: _textColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── 최근 공지 (없으면 아예 안 보임) ────────
                  if (_loading) ...[
                    const AppSkeleton(height: 46, radius: 10),
                    const SizedBox(height: 34),
                  ] else if (_latestNotice != null) ...[
                    _NoticeStrip(notice: _latestNotice!),
                    const SizedBox(height: 34),
                  ],

                  // ── 복귀 체크 ─────────────────────────────
                  const _SectionTitle('복귀 체크'),
                  const SizedBox(height: 12),
                  _ReturnCheckCard(
                    type: _returnType,
                    onTap: () => showInfoBanner('복귀 체크 기능은 준비 중입니다.'),
                  ),
                  const SizedBox(height: 34),

                  // ── 세탁기 (세탁기 페이지와 같은 위젯) ──────
                  LaundryStatusSection(
                    floor: _floor,
                    machines: _machines,
                    todaySchedule: _todaySchedule,
                    loading: _loading,
                  ),
                  const SizedBox(height: 34),

                  // ── 이번달 기숙사 일정 ───────────────────────
                  const _SectionTitle('이번달 기숙사 일정'),
                  const SizedBox(height: 12),
                  if (_loading)
                    const AppSkeleton(height: 120, radius: 10)
                  else if (_thisMonthSchedules.isEmpty)
                    const _EmptySchedule()
                  else
                    _ScheduleList(schedules: _thisMonthSchedules),
                ]),
              ),
            ),
          ],
        ),
        buildBanner(),
      ],
    );
  }
}

// ── 이번달 일정 목록 ────────────────────────────────────────────
class _ScheduleList extends StatelessWidget {
  const _ScheduleList({required this.schedules});

  final List<DormSchedule> schedules;

  static const _weekdayNames = ['월', '화', '수', '목', '금', '토', '일'];

  /// '06.20 (금)'
  String _dateLabel(DateTime date) {
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '$mm.$dd (${_weekdayNames[date.weekday - 1]})';
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: palette.bgSurface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          for (final (i, schedule) in schedules.indexed) ...[
            if (i != 0) const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 92,
                  child: Text(
                    _dateLabel(schedule.date),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppBrand.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    schedule.title,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.35,
                      color: palette.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── 섹션 제목 ────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Text(
      text,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: palette.textPrimary,
      ),
    );
  }
}

// ── 최근 공지 한 줄 ──────────────────────────────────────────────
class _NoticeStrip extends StatelessWidget {
  const _NoticeStrip({required this.notice});
  final Notice notice;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('/notice-detail', extra: notice),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: palette.bgSurface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.campaign, color: AppBrand.primary, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                notice.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 복귀 체크 카드 ───────────────────────────────────────────────
class _ReturnCheckCard extends StatelessWidget {
  const _ReturnCheckCard({required this.type, required this.onTap});

  final ReturnCheckType type;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
        decoration: BoxDecoration(
          color: palette.bgSurface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${type.label} 입실 체크',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '입실 체크 시 사감 선생님께 알림이 발송됩니다.',
                    style: TextStyle(fontSize: 12, color: palette.textTertiary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(Icons.chevron_right, color: palette.textPrimary, size: 24),
          ],
        ),
      ),
    );
  }
}

// ── 주요 기숙사 일정 (백엔드 준비 전) ────────────────────────────
class _EmptySchedule extends StatelessWidget {
  const _EmptySchedule();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 34),
      decoration: BoxDecoration(
        color: palette.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.borderSubtle, width: 1),
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_note_outlined,
            color: palette.textTertiary,
            size: 26,
          ),
          SizedBox(height: 10),
          Text(
            '등록된 일정이 없습니다.',
            style: TextStyle(fontSize: 13, color: palette.textSecondary),
          ),
          SizedBox(height: 4),
          Text(
            '새 일정이 등록되면 이곳에 표시됩니다.',
            style: TextStyle(fontSize: 11, color: palette.textTertiary),
          ),
        ],
      ),
    );
  }
}
