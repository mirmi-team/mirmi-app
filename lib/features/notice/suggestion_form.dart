import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/suggestion_service.dart';
import '../../shared/app_colors.dart';
import '../../shared/keyboard_inset.dart';
import '../../shared/submit_button.dart';

/// 건의사항 작성 폼. (생활 게시판 > 건의 사항 탭)
///
/// 배너는 부모(NoticeScreen)가 Stack 안에 들고 있으므로 콜백으로 넘겨 받는다.
class SuggestionForm extends StatefulWidget {
  const SuggestionForm({
    super.key,
    required this.onSuccess,
    required this.onError,
  });

  final ValueChanged<String> onSuccess;
  final ValueChanged<String> onError;

  @override
  State<SuggestionForm> createState() => _SuggestionFormState();
}

class _SuggestionFormState extends State<SuggestionForm> {
  static const _textColor = AppDark.textPrimary;

  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String? _category;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // 빈 칸이 있으면 전송 버튼이 잠기도록
    _titleController.addListener(_onFieldChanged);
    _contentController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _titleController.removeListener(_onFieldChanged);
    _contentController.removeListener(_onFieldChanged);
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _onFieldChanged() => setState(() {});

  bool get _canSubmit =>
      !_submitting &&
      _category != null &&
      _titleController.text.trim().isNotEmpty &&
      _contentController.text.trim().isNotEmpty;

  Future<void> _pickCategory() async {
    FocusScope.of(context).unfocus();
    final picked = await showModalBottomSheet<String>(
      context: context,
      // 기본 최대 높이가 화면의 9/16 이라 항목 7개가 들어가지 않는다.
      isScrollControlled: true,
      backgroundColor: AppDark.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        // 화면이 아주 짧은 기기에서도 잘리지 않게
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 14),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppDark.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '카테고리 선택',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _textColor,
                ),
              ),
              const SizedBox(height: 8),
              for (final entry in suggestionCategoryLabels.entries)
                ListTile(
                  title: Text(
                    entry.value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: _category == entry.key
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: _category == entry.key
                          ? AppBrand.primary
                          : _textColor,
                    ),
                  ),
                  trailing: _category == entry.key
                      ? const Icon(
                          Icons.check,
                          color: AppBrand.primary,
                          size: 20,
                        )
                      : null,
                  onTap: () => Navigator.of(context).pop(entry.key),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    if (picked != null && mounted) setState(() => _category = picked);
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);

    try {
      await SuggestionService.create(
        title: _titleController.text.trim(),
        description: _contentController.text.trim(),
        category: _category!,
      );
      if (!mounted) return;
      setState(() {
        _titleController.clear();
        _contentController.clear();
        _category = null;
        _submitting = false;
      });
      widget.onSuccess('건의사항이 전송되었습니다.');
    } on SessionExpiredException {
      if (mounted) context.go('/login');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      widget.onError(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      widget.onError('전송에 실패했습니다.');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 필드가 늘어나면 화면이 짧거나 키보드가 올라왔을 때 아래가 잘리므로
    // 전송 버튼까지 전부 스크롤 안에 두고, 하단 네비게이션 바 자리를 비워둔다.
    return KeyboardInset(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: KeyboardInset.bottomReserve(context)),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '건의하기',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: _textColor,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // ── 1. 카테고리 ──────────────────────────────
                  const _FieldLabel('1. 카테고리를 선택해 주세요.'),
                  const SizedBox(height: 10),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _pickCategory,
                    child: Container(
                      height: 54,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: AppDark.bgSurface,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _category == null
                                  ? '카테고리 선택'
                                  : suggestionCategoryLabels[_category]!,
                              style: TextStyle(
                                fontSize: 13,
                                color: _category == null
                                    ? AppDark.textTertiary
                                    : _textColor,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppDark.textTertiary,
                            size: 22,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // ── 2. 제목 ──────────────────────────────────
                  const _FieldLabel('2. 제목을 작성해 주세요.'),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: AppDark.bgSurface,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: TextField(
                      controller: _titleController,
                      textInputAction: TextInputAction.next,
                      // DB 컬럼이 varchar(255)
                      inputFormatters: [LengthLimitingTextInputFormatter(255)],
                      style: const TextStyle(color: _textColor, fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: '예) 3층 샤워실 온수가 자주 끊겨요',
                        hintStyle: TextStyle(
                          color: AppDark.textTertiary,
                          fontSize: 13,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 17,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // ── 3. 건의 내용 ─────────────────────────────
                  const _FieldLabel('3. 건의할 내용을 작성해주세요.'),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: AppDark.bgSurface,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: TextField(
                      controller: _contentController,
                      maxLines: 5,
                      textInputAction: TextInputAction.newline,
                      style: const TextStyle(
                        color: _textColor,
                        fontSize: 13,
                        height: 1.5,
                      ),
                      decoration: const InputDecoration(
                        hintText:
                            '언제, 어디서 있었던 일인지 적어주세요.\n'
                            '예) 저녁 8시 이후 3층 샤워실 온수가 끊겨서\n'
                            '    씻기 불편해요. 점검 부탁드립니다.',
                        hintStyle: TextStyle(
                          color: AppDark.textTertiary,
                          fontSize: 13,
                          height: 1.5,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 17,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),

                  const Center(
                    child: Text(
                      '건의 내용은 사감선생님께 전송됩니다.',
                      style: TextStyle(fontSize: 12, color: AppDark.textTertiary),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            SubmitButton(
              text: '전송',
              loadingButton: _submitting,
              onPressed: _canSubmit ? _submit : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 13, color: AppDark.textSecondary),
    );
  }
}
