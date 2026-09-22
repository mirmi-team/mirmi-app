import '../../shared/date_format.dart';
import 'package:flutter/material.dart';

import '../../core/services/schedule_service.dart';
import '../../shared/app_palette.dart';

/// 누른 날짜의 일정을 아래에서 올려 보여준다.
Future<void> showScheduleSheet(
  BuildContext context, {
  required DateTime date,
  required List<DormSchedule> schedules,
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
      maxHeight: MediaQuery.of(context).size.height * 0.7,
    ),
    builder: (_) => _ScheduleSheet(date: date, schedules: schedules),
  );
}

class _ScheduleSheet extends StatelessWidget {
  const _ScheduleSheet({required this.date, required this.schedules});

  final DateTime date;
  final List<DormSchedule> schedules;

  static const _weekdayNames = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final mm = twoDigit(date.month);
    final dd = twoDigit(date.day);
    final weekday = _weekdayNames[date.weekday - 1];

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 14),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: palette.borderSubtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              '$mm.$dd ($weekday)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: palette.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              itemCount: schedules.length,
              separatorBuilder: (_, _) =>
                  Divider(color: palette.borderSubtle, height: 32),
              itemBuilder: (context, i) => ScheduleTile(schedule: schedules[i]),
            ),
          ),
        ],
      ),
    );
  }
}

/// 일정 한 건. 제목과 내용만 보여준다. (시간·분류 없음)
class ScheduleTile extends StatelessWidget {
  const ScheduleTile({super.key, required this.schedule});

  final DormSchedule schedule;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          schedule.title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: palette.textPrimary,
          ),
        ),
        if (schedule.description.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            schedule.description,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: palette.textTertiary,
            ),
          ),
        ],
      ],
    );
  }
}
