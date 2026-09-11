import 'package:flutter/material.dart';

import '../../shared/app_colors.dart';
import '../../shared/app_refresh.dart';

// ── 곡 한 줄 ─────────────────────────────────────────────────
class SongRow extends StatelessWidget {
  const SongRow({
    super.key,
    required this.thumbnail,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.busy,
    required this.onAction,
    this.destructive = false,
  });

  final String? thumbnail;
  final String title;
  final String subtitle;

  /// null 이면 버튼을 그리지 않는다.
  final String? actionLabel;
  final bool destructive;
  final bool busy;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            width: 48,
            height: 48,
            child: (thumbnail != null && thumbnail!.isNotEmpty)
                ? Image.network(
                    thumbnail!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const _ThumbFallback(),
                  )
                : const _ThumbFallback(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.mainText,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      size: 13,
                      color: AppColors.caption,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.caption,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (actionLabel != null) ...[
          const SizedBox(width: 10),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: busy ? null : onAction,
            child: Container(
              width: 56,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border)
              ),
              child: busy
                  ? const AppLoadingIndicator(size: 14, strokeWidth: 2)
                  : Text(
                      actionLabel!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: destructive
                            ? AppColors.error
                            : AppColors.mainText,
                      ),
                    ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ThumbFallback extends StatelessWidget {
  const _ThumbFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.card,
      child: const Icon(Icons.music_note, size: 20, color: AppColors.caption),
    );
  }
}
