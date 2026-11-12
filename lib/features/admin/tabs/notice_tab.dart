import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/notice_service.dart';
import '../../../core/services/suggestion_service.dart';
import '../../../shared/app_banner.dart';
import '../../../shared/app_colors.dart';
import '../../../shared/app_nav_bar.dart';
import '../../../shared/app_palette.dart';
import '../../../shared/app_refresh.dart';
import '../../../shared/app_segmented_tabs.dart';
import '../../../shared/app_skeleton.dart';
import '../../my_page/my_suggestions_screen.dart' show ReplyBadge;
import '../admin_player.dart';

/// 공지/건의 관리.
///
/// 공지는 등록·수정·삭제하고, 학생이 올린 건의에는 답변한다.
/// 사감 일은 "답변 안 한 건의부터" 처리하는 쪽이라 미답변을 목록 위로 올린다.
class AdminNoticeTab extends StatefulWidget {
  const AdminNoticeTab({super.key});

  @override
  State<AdminNoticeTab> createState() => _AdminNoticeTabState();
}

class _AdminNoticeTabState extends State<AdminNoticeTab> with AppBannerMixin {
  /// 0 = 공지사항, 1 = 건의사항
  int _tabIndex = 0;

  bool _loading = true;
  List<Notice> _notices = const [];
  List<Suggestion> _suggestions = const [];

  bool get _isNotice => _tabIndex == 0;

  int get _pending => _suggestions.where((s) => !s.hasReply).length;

  /// 기상송 미니 플레이어가 떠 있으면 그만큼 더 비워 둔다.
  /// (작은 바 58 + 네비게이션 바와의 간격 12)
  ///
  /// 플레이어는 이 화면보다 위에 그려지므로, 비워두지 않으면 마지막 카드와
  /// 등록 버튼이 그 아래에 깔린다.
  double get _playerInset => AdminPlayerScope.of(context).isOpen ? 70.0 : 0.0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    try {
      // 탭을 옮길 때마다 다시 부르지 않도록 둘 다 받아 둔다.
      final results = await Future.wait<Object>([
        NoticeService.getTodayNotices(),
        SuggestionService.getAll(),
      ]);
      if (!mounted) return;
      setState(() {
        _notices = results[0] as List<Notice>;
        _suggestions = _pendingFirst(results[1] as List<Suggestion>);
        _loading = false;
      });
    } on SessionExpiredException {
      if (mounted) context.go('/login');
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      showErrorBanner('목록을 불러오지 못했습니다.');
    }
  }

  /// 답변이 필요한 건의를 위로. 각 묶음 안에서는 서버가 준 최신순을 지킨다.
  static List<Suggestion> _pendingFirst(List<Suggestion> all) => [
    ...all.where((s) => !s.hasReply),
    ...all.where((s) => s.hasReply),
  ];

  /// 공지 등록·수정 화면. [notice] 가 없으면 등록이다.
  Future<void> _openNoticeForm([Notice? notice]) async {
    await context.push('/notice-form', extra: notice);
    if (mounted) _load(silent: true);
  }

  Future<void> _openReply(Suggestion suggestion) async {
    await context.push('/suggestion-reply', extra: suggestion);
    if (mounted) _load(silent: true);
  }

  /// 머리말 오른쪽 숫자. 건의는 처리할 게 남았는지가 먼저 보여야 한다.
  String get _countLabel {
    if (_isNotice) return '총 ${_notices.length}건';
    if (_pending > 0) return '미답변 $_pending건';
    return '총 ${_suggestions.length}건';
  }

  String get _subtitle {
    // 과거 공지를 받아오는 API 가 아직 없어 오늘 것만 보인다.
    if (_isNotice) return '오늘 올린 공지만 보입니다.';
    if (_loading) return '학생들이 올린 건의사항';
    if (_suggestions.isEmpty) return '학생들이 올린 건의사항';
    if (_pending > 0) return '답변이 필요한 건의가 위에 있습니다.';
    return '모든 건의에 답변했습니다.';
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
                          '공지/건의 관리',
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
                            color: palette.textTertiary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _subtitle,
                    style: TextStyle(fontSize: 13, color: palette.textTertiary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── 공지 / 건의 ───────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AppSegmentedTabs(
                index: _tabIndex,
                labels: const ['공지사항', '건의사항'],
                onChanged: (i) => setState(() => _tabIndex = i),
              ),
            ),
            const SizedBox(height: 20),

            Expanded(
              child: _isNotice
                  ? _buildNotices(palette)
                  : _buildSuggestions(palette),
            ),
          ],
        ),

        // 등록할 수 있는 건 공지뿐이다. 건의는 학생이 올린다.
        if (_isNotice && !_loading)
          _AddNoticeButton(onTap: _openNoticeForm, bottomInset: _playerInset),

        buildBanner(),
      ],
    );
  }

  Widget _buildNotices(AppPalette palette) {
    if (_loading) return _skeletonList(height: 90);

    return AppRefreshScrollView(
      onRefresh: () => _load(silent: true),
      slivers: [
        SliverPadding(
          padding: _listPadding,
          sliver: _notices.isEmpty
              ? _empty('오늘 등록한 공지가 없습니다.', palette)
              : SliverList.separated(
                  itemCount: _notices.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _NoticeCard(
                    notice: _notices[i],
                    onTap: () => _openNoticeForm(_notices[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildSuggestions(AppPalette palette) {
    if (_loading) return _skeletonList(height: 104);

    return AppRefreshScrollView(
      onRefresh: () => _load(silent: true),
      slivers: [
        SliverPadding(
          padding: _listPadding,
          sliver: _suggestions.isEmpty
              ? _empty('올라온 건의사항이 없습니다.', palette)
              : SliverList.separated(
                  itemCount: _suggestions.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _SuggestionCard(
                    suggestion: _suggestions[i],
                    onTap: () => _openReply(_suggestions[i]),
                  ),
                ),
        ),
      ],
    );
  }

  /// 하단 네비게이션 바와 등록 버튼에 가리지 않도록 넉넉히 비운다.
  EdgeInsets get _listPadding =>
      EdgeInsets.fromLTRB(20, 10, 20, 160 + _playerInset);

  Widget _skeletonList({required double height}) => ListView.separated(
    padding: _listPadding,
    itemCount: 4,
    separatorBuilder: (_, _) => const SizedBox(height: 12),
    itemBuilder: (_, _) => AppSkeleton(height: height, radius: 10),
  );

  Widget _empty(String text, AppPalette palette) => SliverFillRemaining(
    hasScrollBody: false,
    child: Center(
      child: Text(
        text,
        style: TextStyle(fontSize: 13, color: palette.textTertiary),
      ),
    ),
  );
}

// ── 공지 등록 버튼 ───────────────────────────────────────────────
/// 목록 위에 떠 있는 동그란 버튼. 하단 네비게이션 바 위에 올려 둔다.
class _AddNoticeButton extends StatelessWidget {
  const _AddNoticeButton({required this.onTap, required this.bottomInset});

  final VoidCallback onTap;

  /// 네비게이션 바 위에 이미 자리를 차지한 것(미니 플레이어)의 높이.
  final double bottomInset;

  static const _size = 56.0;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Positioned(
      right: 20,
      bottom: appNavBarTotalHeight(context) + bottomInset + 16,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: _size,
          height: _size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppBrand.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppBrand.primary.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          // 청록 위 글자색은 '전체 재생' 버튼과 같은 규칙을 따른다.
          child: Icon(Icons.add_rounded, size: 30, color: palette.textPrimary),
        ),
      ),
    );
  }
}

// ── 공지 한 장 ───────────────────────────────────────────────────
class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.notice, required this.onTap});

  final Notice notice;
  final VoidCallback onTap;

  static const _thumbSize = 56.0;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final url = notice.imageUrl;
    final hasImage = url != null && url.isNotEmpty;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: palette.bgSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: palette.borderSubtle, width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasImage) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  url,
                  width: _thumbSize,
                  height: _thumbSize,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: _thumbSize,
                    height: _thumbSize,
                    alignment: Alignment.center,
                    color: palette.bgSurfaceHover,
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      size: 18,
                      color: palette.textTertiary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notice.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notice.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    notice.timeAgo,
                    style: TextStyle(fontSize: 11, color: palette.textTertiary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: palette.textPrimary, size: 22),
          ],
        ),
      ),
    );
  }
}

// ── 건의 한 장 ───────────────────────────────────────────────────
class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.suggestion, required this.onTap});

  final Suggestion suggestion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    // 작성자는 서버가 아직 안 내려준다. 오면 날짜 앞에 저절로 붙는다.
    final meta = [?suggestion.writerLabel, suggestion.dateLabel].join(' · ');

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: palette.bgSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: palette.borderSubtle, width: 1),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ReplyBadge(hasReply: suggestion.hasReply),
                  const SizedBox(height: 10),
                  Text(
                    suggestion.labeledTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: palette.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    meta,
                    style: TextStyle(fontSize: 11, color: palette.textTertiary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: palette.textPrimary, size: 22),
          ],
        ),
      ),
    );
  }
}
