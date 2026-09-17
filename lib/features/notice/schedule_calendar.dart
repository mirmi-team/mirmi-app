import 'package:flutter/material.dart';

import '../../core/services/schedule_service.dart';
import '../../shared/app_colors.dart';

/// 기숙사 일정 달력.
///
/// 일정이 있는 날짜 아래에 밑줄이 그어지고, 날짜를 누르면 그날 일정이
/// 아래에서 올라온다. 처음에는 항상 이번 달을 보여준다.
class ScheduleCalendar extends StatefulWidget {
  const ScheduleCalendar({
    super.key,
    required this.schedules,
    required this.onSelectDate,
  });

  final List<DormSchedule> schedules;
  final void Function(DateTime date, List<DormSchedule> schedules) onSelectDate;

  @override
  State<ScheduleCalendar> createState() => _ScheduleCalendarState();
}

class _ScheduleCalendarState extends State<ScheduleCalendar> {
  static const _weekdayNames = ['일', '월', '화', '수', '목', '금', '토'];

  /// 현재 보고 있는 달의 1일. 처음에는 이번 달.
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  void _changeMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  /// 날짜별 일정. 키는 'YYYY-MM-DD'.
  Map<String, List<DormSchedule>> get _byDate {
    final map = <String, List<DormSchedule>>{};
    for (final s in widget.schedules) {
      (map[_key(s.date)] ??= []).add(s);
    }
    return map;
  }

  String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final byDate = _byDate;

    // 달력 첫 칸은 그 달 1일이 속한 주의 일요일부터.
    final first = DateTime(_month.year, _month.month);
    final leading = first.weekday % 7; // 일요일=0
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final cellCount = ((leading + daysInMonth) / 7).ceil() * 7;

    return Column(
      children: [
        const Text(
          '기숙사 일정',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppDark.textPrimary,
          ),
        ),
        const SizedBox(height: 18),

        // ── 월 이동 ───────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _ArrowButton(
              icon: Icons.chevron_left,
              onTap: () => _changeMonth(-1),
            ),
            Column(
              children: [
                Text(
                  _month.month.toString().padLeft(2, '0'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppBrand.primary,
                  ),
                ),
                Text(
                  '${_month.year}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppDark.textTertiary,
                  ),
                ),
              ],
            ),
            _ArrowButton(
              icon: Icons.chevron_right,
              onTap: () => _changeMonth(1),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ── 요일 ──────────────────────────────────────────
        Row(
          children: [
            for (final name in _weekdayNames)
              Expanded(
                child: Center(
                  child: Text(
                    name,
                    style: const TextStyle(fontSize: 13, color: AppDark.textSecondary),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // ── 날짜 ──────────────────────────────────────────
        for (int row = 0; row < cellCount ~/ 7; row++) ...[
          Row(
            children: [
              for (int col = 0; col < 7; col++)
                Expanded(
                  child: _buildCell(row * 7 + col - leading + 1, byDate),
                ),
            ],
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  Widget _buildCell(int day, Map<String, List<DormSchedule>> byDate) {
    // 이번 달 범위를 벗어난 칸은 비워둔다.
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    if (day < 1 || day > daysInMonth) return const SizedBox(height: 44);

    final date = DateTime(_month.year, _month.month, day);
    final schedules = byDate[_key(date)] ?? const <DormSchedule>[];
    final hasSchedule = schedules.isNotEmpty;
    final isToday = _key(date) == _key(DateTime.now());

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: hasSchedule ? () => widget.onSelectDate(date, schedules) : null,
      child: SizedBox(
        height: 44,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 오늘 표시. 다른 날도 같은 자리를 비워둬 숫자 높이가 흔들리지 않게 한다.
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: isToday ? AppBrand.primary : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '$day',
              style: TextStyle(
                fontSize: 15,
                fontWeight: hasSchedule ? FontWeight.w700 : FontWeight.w400,
                color: hasSchedule ? AppDark.textPrimary : AppDark.textSecondary,
              ),
            ),
            const SizedBox(height: 5),
            // 일정이 있는 날만 밑줄
            Container(
              width: 26,
              height: 2,
              decoration: BoxDecoration(
                color: hasSchedule ? AppBrand.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, color: AppDark.textPrimary, size: 24),
      ),
    );
  }
}
