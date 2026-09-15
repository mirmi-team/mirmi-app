import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/suggestion_service.dart';
import '../../shared/app_banner.dart';
import '../../shared/app_colors.dart';
import '../../shared/app_skeleton.dart';

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
  static const _bgColor = AppColors.backB;
  static const _textColor = AppColors.mainText;

  bool _loading = true;
  late Suggestion _suggestion = widget.suggestion;

  /// 작성자는 나 자신이므로 내 정보에서 가져온다. (서버가 안 내려준다)
  String? _writer;

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
                color: AppColors.surfaceHover,
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
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
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
                    color: AppColors.body,
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
                      color: AppColors.caption,
                    ),
                  ),
                  if (_writer != null && _writer!.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    Container(width: 1, height: 11, color: AppColors.border),
                    const SizedBox(width: 10),
                    Text(
                      _writer!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.caption,
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
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 13,
                backgroundColor: AppColors.surfaceHover,
                child: Icon(Icons.person, size: 15, color: AppColors.caption),
              ),
              const SizedBox(width: 10),
              const Text(
                '사감 선생님',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mainText,
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
              color: AppColors.body,
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
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: const Text(
        '아직 답변이 달리지 않았어요.',
        style: TextStyle(fontSize: 13, color: AppColors.caption),
      ),
    );
  }
}
