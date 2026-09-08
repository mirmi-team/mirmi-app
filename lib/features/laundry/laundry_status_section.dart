import 'package:flutter/material.dart';

import '../../core/utils/app_clock.dart';
import '../../shared/app_colors.dart';

/// 세탁기 사용 현황 (제목 + 층 뱃지 + 기기 카드들).
///
/// 세탁기 페이지와 홈에서 같이 쓴다. 비어있는 기기를 눌렀을 때의 동작은
/// 화면마다 다르므로 [onTapEmpty] 로 받는다. (null 이면 표시 전용)
class LaundryStatusSection extends StatelessWidget {
  const LaundryStatusSection({
    super.key,
    required this.floor,
    required this.machines,
    required this.reservations,
    this.onTapEmpty,
  });

  final int? floor;
  final List<Map<String, dynamic>> machines;
  final List<Map<String, dynamic>> reservations;
  final void Function(Map<String, dynamic> machine)? onTapEmpty;

  static const _teal = AppColors.mainColor;
  static const _textColor = AppColors.mainText;
  static const _captionColor = AppColors.caption;
  static const _cardColor = AppColors.card;

  /// 지금 이 기기를 쓰고 있는 예약.
  Map<String, dynamic>? _runningOn(int laundryId) {
    final now = AppClock.now();
    final matches = reservations.where((r) {
      if (r['laundry_id'] != laundryId) return false;
      final start = DateTime.parse(r['start_time'] as String);
      final end = DateTime.parse(r['end_time'] as String);
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
        Row(
          children: [
            for (int i = 0; i < machines.length; i++) ...[
              Expanded(child: _buildMachineCard(i, machines[i])),
              if (i != machines.length - 1) const SizedBox(width: 8),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildMachineCard(int index, Map<String, dynamic> machine) {
    final running = _runningOn(machine['id'] as int);
    final bool isOccupied = running != null;

    final Widget detailWidget = isOccupied
        ? Column(
            children: [
              Text(
                '${running['room_number']}호',
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
      height: 172,
      padding: EdgeInsets.only(top: 16, bottom: isOccupied ? 7 : 16),
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
          SizedBox(height: isOccupied ? 11 : 21),
          detailWidget,
        ],
      ),
    );

    if (isOccupied || onTapEmpty == null) return card;
    return GestureDetector(onTap: () => onTapEmpty!(machine), child: card);
  }
}
