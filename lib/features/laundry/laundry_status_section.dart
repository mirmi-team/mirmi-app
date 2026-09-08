import 'package:flutter/material.dart';

import '../../core/utils/app_clock.dart';
import '../../shared/app_colors.dart';
import '../../shared/app_skeleton.dart';

/// 세탁기 사용 현황 (제목 + 층 뱃지 + 기기 카드들).
///
/// 세탁기 페이지와 홈에서 같이 쓴다. 사용 여부는 오늘 시간표
/// (`LaundryService.getSchedule`)에서 지금 시각에 걸치는 칸으로 판단한다.
class LaundryStatusSection extends StatelessWidget {
  const LaundryStatusSection({
    super.key,
    required this.floor,
    required this.machines,
    required this.todaySchedule,
    this.onTapMachine,
    this.loading = false,
  });

  final int? floor;
  final List<Map<String, dynamic>> machines;

  /// 오늘 시간표. `machine_no`, `room_number`, `start_time`, `end_time`('HH:MM:SS').
  final List<Map<String, dynamic>> todaySchedule;

  /// 카드를 눌렀을 때. null 이면 표시 전용. (홈에서는 넘기지 않는다)
  final void Function(Map<String, dynamic> machine)? onTapMachine;

  /// true 면 기기 자리에 스켈레톤을 놓는다. 제목과 층 뱃지는 그대로 보인다.
  final bool loading;

  static const _teal = AppColors.mainColor;
  static const _textColor = AppColors.mainText;
  static const _captionColor = AppColors.caption;
  static const _cardColor = AppColors.card;

  /// 한 층에 놓인 세탁기 수. 로딩 중 자리를 잡아둘 때 쓴다.
  static const _skeletonCount = 3;
  static const _cardHeight = 172.0;

  DateTime _timeOn(DateTime day, String hhmmss) {
    final parts = hhmmss.split(':');
    return DateTime(
      day.year,
      day.month,
      day.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  /// 지금 이 기기를 쓰고 있는 사람. 없으면 null.
  Map<String, dynamic>? _occupantOf(int machineNo) {
    final now = AppClock.now();
    final matches = todaySchedule.where((s) {
      if (s['machine_no'] != machineNo || s['room_number'] == null) {
        return false;
      }
      final start = _timeOn(now, s['start_time'] as String);
      final end = _timeOn(now, s['end_time'] as String);
      return now.isAfter(start) && now.isBefore(end);
    });
    return matches.isEmpty ? null : matches.first;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '세탁기 사용 현황',
              style: TextStyle(
                color: _textColor,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2A2E),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${floor ?? '-'}F 세탁실',
                style: const TextStyle(
                  color: _teal,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        AppSkeletonSwitcher(
          loading: loading,
          skeleton: Row(
            children: [
              for (int i = 0; i < _skeletonCount; i++) ...[
                const Expanded(
                  child: AppSkeleton(height: _cardHeight, radius: 10),
                ),
                if (i != _skeletonCount - 1) const SizedBox(width: 8),
              ],
            ],
          ),
          child: Row(
            children: [
              for (int i = 0; i < machines.length; i++) ...[
                Expanded(child: _buildMachineCard(i, machines[i])),
                if (i != machines.length - 1) const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMachineCard(int index, Map<String, dynamic> machine) {
    final occupant = _occupantOf(index + 1);
    final bool isOccupied = occupant != null;

    final Widget detailWidget = isOccupied
        ? Column(
            children: [
              Text(
                '${occupant['room_number']}호',
                style: const TextStyle(
                  color: _textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                '사용중',
                style: TextStyle(color: _captionColor, fontSize: 12),
              ),
            ],
          )
        : const Text(
            '비어 있음',
            style: TextStyle(
              color: _teal,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          );

    final card = Container(
      height: _cardHeight,
      padding: EdgeInsets.only(top: 16, bottom: isOccupied ? 5 : 16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xff3F3F46), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${index + 1}호',
            style: const TextStyle(
              color: _textColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Icon(
            Icons.local_laundry_service,
            size: 54,
            color: isOccupied ? _teal : Colors.white,
          ),
          SizedBox(height: isOccupied ? 10 : 14),
          detailWidget,
        ],
      ),
    );

    if (onTapMachine == null) return card;
    return GestureDetector(onTap: () => onTapMachine!(machine), child: card);
  }
}
