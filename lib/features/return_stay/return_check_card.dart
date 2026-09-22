import 'package:flutter/material.dart';

import '../../core/services/return_service.dart';
import '../../shared/app_colors.dart';
import '../../shared/app_palette.dart';
import 'return_qr_dialog.dart';

/// 입실 체크 카드. 홈 탭과 복귀 탭이 같이 쓴다.
///
/// 누르면 QR 팝업이 뜨고, 닫히면 [onChecked] 로 알려 준다. 부모는 그때
/// 기록을 다시 불러오면 된다. 한 번 체크한 뒤에도 계속 누를 수 있다.
class ReturnCheckCard extends StatelessWidget {
  const ReturnCheckCard({
    super.key,
    required this.label,
    this.checkedAt,
    this.onChecked,
  });

  final String label;

  /// 마지막으로 입실 체크된 시각. null 이면 아직 전.
  final DateTime? checkedAt;

  /// QR 팝업이 닫힌 뒤 호출. 보통 기록을 다시 불러오는 데 쓴다.
  final VoidCallback? onChecked;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final done = checkedAt != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        await showReturnQrDialog(context);
        onChecked?.call();
      },
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
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    done
                        ? '${returnTimeLabel(checkedAt!)} 입실 체크 완료'
                        : 'QR코드를 생성합니다.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: done ? FontWeight.w600 : FontWeight.w400,
                      color: done ? AppBrand.primary : palette.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // 체크를 마쳐도 다시 누를 수 있으므로 화살표는 그대로 둔다.
            if (done) ...[
              const Icon(Icons.check_circle, color: AppBrand.primary, size: 20),
              const SizedBox(width: 6),
            ],
            Icon(Icons.chevron_right, color: palette.textPrimary, size: 24),
          ],
        ),
      ),
    );
  }
}

/// '오후 6:03'
String returnTimeLabel(DateTime at) {
  final isAm = at.hour < 12;
  final hour12 = at.hour % 12 == 0 ? 12 : at.hour % 12;
  return '${isAm ? '오전' : '오후'} $hour12:${at.minute.toString().padLeft(2, '0')}';
}

/// 기록 목록에서 마지막 입실 체크 시각. 없으면 null.
DateTime? lastCheckedAt(List<ReturnRecord> records) {
  if (records.isEmpty) return null;
  return records
      .map((r) => r.actualTime!)
      .reduce((a, b) => a.isAfter(b) ? a : b);
}
