import 'package:flutter/material.dart';
import '../../core/services/notice_service.dart';
import '../../shared/app_banner.dart';
import '../../shared/app_colors.dart';
import '../../shared/app_refresh.dart';

class NoticeScreen extends StatefulWidget {
  const NoticeScreen({super.key});

  @override
  State<NoticeScreen> createState() => _NoticeScreenState();
}

class _NoticeScreenState extends State<NoticeScreen>
    with AppBannerMixin, WidgetsBindingObserver {
  static const _textColor = AppColors.mainText;

  /// 0 = 공지 사항, 1 = 건의사항
  int _tabIndex = 0;

  bool _loading = true;
  List<Notice> _notices = const [];

  /// 마지막으로 공지를 불러온 날짜. 날짜가 바뀌면 그날 공지로 다시 불러온다.
  DateTime? _loadedDay;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 앱으로 돌아왔을 때 날짜가 넘어갔으면 새로 불러오기
    if (state != AppLifecycleState.resumed) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_loadedDay != null && _loadedDay != today) _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final notices = await NoticeService.getTodayNotices();
      if (!mounted) return;
      final now = DateTime.now();
      setState(() {
        _notices = notices;
        _loadedDay = DateTime(now.year, now.month, now.day);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      showErrorBanner('공지사항을 불러오지 못했습니다.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Text(
                '생활 게시판',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _textColor,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── 공지 사항 / 건의사항 토글 ──────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _SegmentedTabs(
                index: _tabIndex,
                labels: const ['공지 사항', '건의사항'],
                onChanged: (i) => setState(() => _tabIndex = i),
              ),
            ),
            const SizedBox(height: 24),

            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _tabIndex == 0
                    ? _buildNoticeTab()
                    : const _SuggestionPlaceholder(),
              ),
            ),
          ],
        ),
        buildBanner(),
      ],
    );
  }

  Widget _buildNoticeTab() {
    if (_loading) {
      return const AppLoadingIndicator();
    }

    return AppRefreshScrollView(
      onRefresh: () => _load(silent: true),
      slivers: [
        SliverPadding(
          // 하단 네비게이션 바에 가리지 않도록 여유 패딩
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const Text(
                '공지 사항',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _textColor,
                ),
              ),
              const SizedBox(height: 12),
              if (_notices.isEmpty)
                const _EmptyNotice()
              else
                for (final notice in _notices) ...[
                  _NoticeCard(notice: notice),
                  const SizedBox(height: 10),
                ],
            ]),
          ),
        ),
      ],
    );
  }
}

// ── 슬라이딩 토글 바 ─────────────────────────────────────────────
class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({
    required this.index,
    required this.labels,
    required this.onChanged,
  });

  final int index;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  static const _height = 50.0;
  static const _margin = 0.0;
  static const _pillColor = Color.fromARGB(128, 6, 181, 212); // 선택된 탭 배경 (딥 틸)

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tabWidth = constraints.maxWidth / labels.length;
        return Container(
          height: _height,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(_height / 2),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                left: index * tabWidth + _margin,
                top: _margin,
                bottom: _margin,
                width: tabWidth - _margin * 2,
                child: Container(
                  decoration: BoxDecoration(
                    color: _pillColor,
                    borderRadius: BorderRadius.circular(_height / 2 - _margin),
                  ),
                ),
              ),
              Row(
                children: List.generate(labels.length, (i) {
                  final selected = index == i;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged(i),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutCubic,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected
                                ? AppColors.mainText
                                : AppColors.caption,
                          ),
                          child: Text(labels[i]),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── 공지 카드 ────────────────────────────────────────────────────
class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.notice});
  final Notice notice;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceHover,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notice.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mainText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  notice.description,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: AppColors.caption,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              notice.timeAgo,
              style: const TextStyle(fontSize: 10, color: AppColors.caption),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 오늘 공지 없음 ───────────────────────────────────────────────
class _EmptyNotice extends StatelessWidget {
  const _EmptyNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 34),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.notifications_off_outlined,
            color: AppColors.caption,
            size: 26,
          ),
          SizedBox(height: 10),
          Text(
            '오늘 등록된 공지사항이 없습니다.',
            style: TextStyle(fontSize: 13, color: AppColors.body),
          ),
          SizedBox(height: 4),
          Text(
            '새 공지가 올라오면 이곳에 표시됩니다.',
            style: TextStyle(fontSize: 11, color: AppColors.caption),
          ),
        ],
      ),
    );
  }
}

// ── 건의사항 (추후 개발) ─────────────────────────────────────────
class _SuggestionPlaceholder extends StatelessWidget {
  const _SuggestionPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        '건의사항은 준비 중입니다.',
        style: TextStyle(fontSize: 15, color: AppColors.placeholder),
      ),
    );
  }
}
