import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/suggestion_service.dart';
import '../../shared/app_back_button.dart';
import '../../shared/app_banner.dart';
import '../../shared/app_colors.dart';
import '../../shared/app_refresh.dart';
import '../../shared/app_skeleton.dart';

/// 내가 보낸 건의사항 목록. 마이페이지에서 들어온다.
class MySuggestionsScreen extends StatefulWidget {
  const MySuggestionsScreen({super.key});

  @override
  State<MySuggestionsScreen> createState() => _MySuggestionsScreenState();
}

class _MySuggestionsScreenState extends State<MySuggestionsScreen>
    with AppBannerMixin {
  static const _bgColor = AppDark.bgCanvas;
  static const _textColor = AppDark.textPrimary;

  bool _loading = true;
  List<Suggestion> _suggestions = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final suggestions = await SuggestionService.getMine();
      if (!mounted) return;
      setState(() {
        _suggestions = suggestions;
        _loading = false;
      });
    } on SessionExpiredException {
      if (mounted) context.go('/login');
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      showErrorBanner('건의사항을 불러오지 못했습니다.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: const AppBackButton(),
        title: const Text(
          '내 건의사항',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: _textColor,
          ),
        ),
      ),
      body: Stack(
        children: [
          if (_loading)
            ListView.separated(
              padding: const EdgeInsets.fromLTRB(0, 20, 0, 24),
              itemCount: 3,
              separatorBuilder: (_, _) => const SizedBox(height: 1),
              itemBuilder: (_, _) => const AppSkeleton(height: 100, radius: 0),
            )
          else
            AppRefreshScrollView(
              onRefresh: () => _load(silent: true),
              slivers: [
                SliverPadding(
                  // 좌우 여백은 카드가 직접 갖는다. 구분선이 화면 끝까지 닿도록.
                  padding: const EdgeInsets.only(top: 8, bottom: 24),
                  sliver: _suggestions.isEmpty
                      ? const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Text(
                              '보낸 건의사항이 없습니다.',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppDark.textTertiary,
                              ),
                            ),
                          ),
                        )
                      : SliverList.separated(
                          itemCount: _suggestions.length,
                          separatorBuilder: (_, _) => const Divider(
                            color: AppDark.borderSubtle,
                            height: 1,
                          ),
                          itemBuilder: (context, i) => _SuggestionCard(
                            suggestion: _suggestions[i],
                            onTap: () async {
                              await context.push(
                                '/suggestion-detail',
                                extra: _suggestions[i],
                              );
                              // 답변이 달렸을 수 있으니 돌아오면 갱신
                              if (mounted) _load(silent: true);
                            },
                          ),
                        ),
                ),
              ],
            ),
          buildBanner(),
        ],
      ),
    );
  }
}

// ── 목록 카드 ────────────────────────────────────────────────────
class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.suggestion, required this.onTap});

  final Suggestion suggestion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
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
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppDark.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    suggestion.dateLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppDark.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              color: AppDark.textPrimary,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

/// 답변 완료 / 답변 대기 중 뱃지.
class ReplyBadge extends StatelessWidget {
  const ReplyBadge({super.key, required this.hasReply});

  final bool hasReply;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: hasReply
            ? AppBrand.primary.withValues(alpha: 0.9)
            : AppDark.bgSurfaceHover,
        borderRadius: BorderRadius.circular(46),
      ),
      child: Text(
        hasReply ? '답변 완료' : '답변 대기 중',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: hasReply ? AppDark.bgCanvas : AppDark.textSecondary,
        ),
      ),
    );
  }
}
