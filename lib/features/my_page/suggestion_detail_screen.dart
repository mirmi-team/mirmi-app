import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/suggestion_service.dart';
import '../../shared/app_banner.dart';
import '../../shared/app_colors.dart';
import '../../shared/app_dialog.dart';
import '../../shared/app_skeleton.dart';
import '../../shared/submit_button.dart';
import 'my_suggestions_screen.dart';

/// 건의사항 상세. 목록에는 없는 본문과 답변을 보여준다.
class SuggestionDetailScreen extends StatefulWidget {
  const SuggestionDetailScreen({super.key, required this.suggestion});

  /// 목록에서 넘어온 값. 본문(description)이 없어 상세를 다시 불러온다.
  final Suggestion suggestion;

  @override
  State<SuggestionDetailScreen> createState() => _SuggestionDetailScreenState();
}

class _SuggestionDetailScreenState extends State<SuggestionDetailScreen>
    with AppBannerMixin {
  static const _bgColor = AppDark.bgCanvas;
  static const _textColor = AppDark.textPrimary;

  bool _loading = true;
  late Suggestion _suggestion = widget.suggestion;

  /// 작성자는 나 자신이므로 내 정보에서 가져온다. (서버가 안 내려준다)
  String? _writer;

  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        SuggestionService.getOne(widget.suggestion.id),
        AuthService.getMe(),
      ]);
      if (!mounted) return;
      final me = results[1] as Map<String, dynamic>;
      final room = me['room_number'];
      final name = me['username'];
      setState(() {
        _suggestion = results[0] as Suggestion;
        _writer = [
          if (room != null) '$room호',
          if (name != null) '$name',
        ].join(' ');
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

  Future<void> _cancel() async {
    if (_deleting) return;

    final ok = await showConfirmDialog(
      context,
      title: '건의를 취소할까요?',
      message: '취소하면 되돌릴 수 없습니다.',
      confirmText: '건의 취소',
    );
    if (ok != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await SuggestionService.delete(_suggestion.id);
      if (mounted) context.pop();
    } on SessionExpiredException {
      if (mounted) context.go('/login');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      showErrorBanner(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _deleting = false);
      showErrorBanner('취소에 실패했습니다.');
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
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppDark.bgSurfaceHover,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chevron_left,
                color: _textColor,
                size: 22,
              ),
            ),
          ),
        ),
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
          Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                  children: [
                    // 목록과 같은 뱃지를 제목 위에 둔다.
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ReplyBadge(hasReply: _suggestion.hasReply),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _suggestion.labeledTitle,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                        color: _textColor,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 본문은 상세 조회에만 있어서 불러오는 동안 자리만 잡아둔다.
                    if (_loading)
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 8),
                          AppSkeleton(height: 15),
                        ],
                      )
                    else
                      Text(
                        _suggestion.description ?? '',
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.55,
                          color: AppDark.textSecondary,
                        ),
                      ),
                    const SizedBox(height: 22),

                    // ── 작성 정보 ─────────────────────────────────
                    Row(
                      children: [
                        Text(
                          _suggestion.dateLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppDark.textTertiary,
                          ),
                        ),
                        if (_writer != null && _writer!.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          Container(
                            width: 1,
                            height: 11,
                            color: AppDark.borderSubtle,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _writer!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppDark.textTertiary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 40),

                    // ── 답변 ─────────────────────────────────────
                    if (_suggestion.hasReply)
                      _ReplyCard(reply: _suggestion.reply!)
                    else if (!_loading)
                      const _NoReply(),
                  ],
                ),
              ),
              // 답변이 오기 전에만 취소할 수 있다.
              if (!_loading && !_suggestion.hasReply)
                SubmitButton(
                  text: '건의 취소',
                  loadingButton: _deleting,
                  onPressed: _cancel,
                ),
              SizedBox(height: MediaQuery.viewPaddingOf(context).bottom),
            ],
          ),
          buildBanner(),
        ],
      ),
    );
  }
}

// ── 사감 선생님 답변 ─────────────────────────────────────────────
class _ReplyCard extends StatelessWidget {
  const _ReplyCard({required this.reply});

  final String reply;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: AppDark.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppDark.borderSubtle, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 13,
                backgroundColor: AppDark.bgSurfaceHover,
                child: Icon(Icons.person, size: 15, color: AppDark.textTertiary),
              ),
              const SizedBox(width: 10),
              const Text(
                '사감 선생님',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppDark.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            reply,
            style: const TextStyle(
              fontSize: 13,
              height: 1.55,
              color: AppDark.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoReply extends StatelessWidget {
  const _NoReply();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppDark.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppDark.borderSubtle, width: 1),
      ),
      child: const Text(
        '아직 답변이 달리지 않았어요.',
        style: TextStyle(fontSize: 13, color: AppDark.textTertiary),
      ),
    );
  }
}
