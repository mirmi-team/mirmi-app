import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/notice_service.dart';
import '../../shared/app_palette.dart';
import '../../shared/app_top_bar.dart';
import '../../shared/app_refresh.dart';

/// 공지사항 세부 페이지.
///
/// 목록에서 카드를 누르면 들어온다. 이미지는 등록된 공지에만 표시하고,
/// 없으면 본문 아래를 그냥 비워둔다.
class NoticeDetailScreen extends StatelessWidget {
  const NoticeDetailScreen({super.key, required this.notice});

  final Notice notice;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Scaffold(
      // 배경색은 ThemeData.scaffoldBackgroundColor 가 정한다.
      appBar: const AppTopBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: [
          // ── 뒤로가기 ────────────────────────────────────────
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => context.pop(),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 0),
                child: Icon(
                  Icons.chevron_left,
                  color: palette.textPrimary,
                  size: 28,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // ── 제목 / 본문 ─────────────────────────────────────
          Text(
            notice.title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            notice.description,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: palette.textPrimary,
            ),
          ),

          // ── 첨부 이미지 (없으면 아무것도 그리지 않는다) ──────
          if (notice.imageUrl != null && notice.imageUrl!.isNotEmpty) ...[
            const SizedBox(height: 24),
            _NoticeImage(url: notice.imageUrl!),
          ],
        ],
      ),
    );
  }
}

/// 공지 첨부 이미지. 원본 비율 그대로 가로를 꽉 채운다.
class _NoticeImage extends StatelessWidget {
  const _NoticeImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        width: double.infinity,
        fit: BoxFit.fitWidth,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          // 원본 크기를 아직 모르므로 정사각형 자리만 잡아둔다.
          return AspectRatio(
            aspectRatio: 1,
            child: ColoredBox(
              color: palette.bgSurface,
              child: AppLoadingIndicator(size: 26, strokeWidth: 2.4),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => Container(
          padding: const EdgeInsets.symmetric(vertical: 40),
          decoration: BoxDecoration(
            color: palette.bgSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: palette.borderSubtle, width: 1),
          ),
          child: Column(
            children: [
              Icon(
                Icons.image_not_supported_outlined,
                color: palette.textTertiary,
                size: 26,
              ),
              SizedBox(height: 10),
              Text(
                '이미지를 불러오지 못했습니다.',
                style: TextStyle(fontSize: 13, color: palette.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
