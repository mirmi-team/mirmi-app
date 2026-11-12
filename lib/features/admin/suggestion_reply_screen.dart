import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/suggestion_service.dart';
import '../../shared/app_banner.dart';
import '../../shared/app_dialog.dart';
import '../../shared/app_field_label.dart';
import '../../shared/app_palette.dart';
import '../../shared/app_skeleton.dart';
import '../../shared/app_sub_page_bar.dart';
import '../../shared/keyboard_inset.dart';
import '../../shared/submit_button.dart';
import '../my_page/inquiry_screen.dart' show TextInput;
import '../my_page/my_suggestions_screen.dart' show ReplyBadge;

/// 건의사항 답변 (관리자).
///
/// 답변 등록과 수정이 같은 화면이다. 서버도 같은 요청 하나로 처리한다.
/// 목록에는 본문이 없어서 들어온 뒤 상세를 다시 불러온다.
class SuggestionReplyScreen extends StatefulWidget {
  const SuggestionReplyScreen({super.key, required this.suggestion});

  /// 목록에서 넘어온 값. 본문(description)이 없다.
  final Suggestion suggestion;

  @override
  State<SuggestionReplyScreen> createState() => _SuggestionReplyScreenState();
}

class _SuggestionReplyScreenState extends State<SuggestionReplyScreen>
    with AppBannerMixin {
  AppPalette get _palette => AppPalette.of(context);

  bool _loading = true;
  late Suggestion _suggestion = widget.suggestion;

  final _replyCtrl = TextEditingController();

  bool _saving = false;
  bool _deleting = false;

  bool get _busy => _saving || _deleting;

  /// 이미 저장된 답변과 똑같으면 보낼 이유가 없다.
  bool get _canSubmit {
    final text = _replyCtrl.text.trim();
    return text.isNotEmpty && text != (_suggestion.reply ?? '').trim();
  }

  /// 아래 버튼 두 개가 차지하는 높이. (54 + 12 + 54 + 28)
  static const _bottomBarHeight = 148.0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final detail = await SuggestionService.getOne(widget.suggestion.id);
      if (!mounted) return;
      setState(() {
        _suggestion = detail;
        // 이미 답변이 있으면 그걸 채워 두고 고치게 한다.
        _replyCtrl.text = detail.reply ?? '';
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

  Future<void> _submit() async {
    if (!_canSubmit || _busy) return;

    setState(() => _saving = true);
    try {
      await SuggestionService.reply(_suggestion.id, _replyCtrl.text.trim());
      if (mounted) context.pop();
    } on SessionExpiredException {
      if (mounted) context.go('/login');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showErrorBanner(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showErrorBanner('답변을 저장하지 못했습니다.');
    }
  }

  Future<void> _delete() async {
    if (_busy) return;

    final ok = await showConfirmDialog(
      context,
      title: '이 건의를 삭제할까요?',
      message: '학생이 올린 내용과 답변이 함께 사라지고, 되돌릴 수 없습니다.',
      confirmText: '삭제하기',
      destructive: true,
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
      showErrorBanner('삭제에 실패했습니다.');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 작성자는 서버가 아직 안 내려준다. 오면 날짜 앞에 저절로 붙는다.
    final meta = [?_suggestion.writerLabel, _suggestion.dateLabel].join(' · ');

    return Scaffold(
      // 배경색은 ThemeData.scaffoldBackgroundColor 가 정한다.
      // 키보드가 올라와도 하단 버튼은 제자리에 둔다.
      resizeToAvoidBottomInset: false,
      appBar: const AppSubPageBar(title: '건의사항 답변'),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Expanded(
                    child: KeyboardInset(
                      below:
                          _bottomBarHeight +
                          MediaQuery.viewPaddingOf(context).bottom,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── 학생이 올린 건의 ──────────────────
                            ReplyBadge(hasReply: _suggestion.hasReply),
                            const SizedBox(height: 14),
                            Text(
                              _suggestion.labeledTitle,
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                                height: 1.35,
                                color: _palette.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              meta,
                              style: TextStyle(
                                fontSize: 12,
                                color: _palette.textTertiary,
                              ),
                            ),
                            const SizedBox(height: 20),

                            // 본문은 상세에만 있어서 불러오는 동안 자리만 잡아둔다.
                            if (_loading)
                              const AppSkeleton(height: 96, radius: 10)
                            else
                              _BodyBox(text: _suggestion.description ?? ''),

                            const SizedBox(height: 28),
                            Divider(color: _palette.borderSubtle, height: 1),
                            const SizedBox(height: 28),

                            // ── 내 답변 ──────────────────────────
                            AppFieldLabel('답변'),
                            const SizedBox(height: 8),
                            TextInput(
                              hintText: '학생에게 전달할 답변을 작성해 주세요.',
                              maxLines: 6,
                              controller: _replyCtrl,
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              // 서버가 빈 답변을 거부해서 한 번 쓰면 못 지운다.
                              '등록한 답변은 내용만 고칠 수 있고, 지울 수는 없습니다.',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.5,
                                color: _palette.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  SubmitButton(
                    text: _suggestion.hasReply ? '답변 수정' : '답변 등록',
                    loadingButton: _saving,
                    onPressed: !_loading && !_deleting && _canSubmit
                        ? _submit
                        : null,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  ),
                  SubmitButton(
                    text: '건의 삭제',
                    errorButton: true,
                    loadingButton: _deleting,
                    onPressed: !_loading && !_saving ? _delete : null,
                  ),
                  SizedBox(height: MediaQuery.viewPaddingOf(context).bottom),
                ],
              ),
            ),
            buildBanner(),
          ],
        ),
      ),
    );
  }
}

// ── 학생이 쓴 본문 ───────────────────────────────────────────────
/// 내 답변 입력란과 섞이지 않게 테두리 박스에 넣는다.
class _BodyBox extends StatelessWidget {
  const _BodyBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: palette.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.borderSubtle, width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          height: 1.55,
          color: palette.textSecondary,
        ),
      ),
    );
  }
}
