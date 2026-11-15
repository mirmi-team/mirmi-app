import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/notice_service.dart';
import '../../shared/app_banner.dart';
import '../../shared/app_dialog.dart';
import '../../shared/app_field_label.dart';
import '../../shared/app_palette.dart';
import '../../shared/app_sub_page_bar.dart';
import '../../shared/image_pick.dart';
import '../../shared/keyboard_inset.dart';
import '../../shared/submit_button.dart';
import '../my_page/inquiry_screen.dart' show TextInput;

/// 공지 등록·수정. [notice] 를 넘기면 수정 모드로 열린다.
///
/// 등록과 수정이 같은 화면인 이유: 입력 항목과 검사 규칙이 완전히 같다.
class NoticeFormScreen extends StatefulWidget {
  const NoticeFormScreen({super.key, this.notice});

  /// null 이면 새로 등록한다.
  final Notice? notice;

  @override
  State<NoticeFormScreen> createState() => _NoticeFormScreenState();
}

class _NoticeFormScreenState extends State<NoticeFormScreen>
    with AppBannerMixin {
  late final _titleCtrl = TextEditingController(
    text: widget.notice?.title ?? '',
  );
  late final _bodyCtrl = TextEditingController(
    text: widget.notice?.description ?? '',
  );

  /// 새로 고른 사진. null 이면 첨부를 건드리지 않은 것이다.
  File? _picked;

  bool _saving = false;
  bool _deleting = false;

  bool get _isEdit => widget.notice != null;

  bool get _isValid =>
      _titleCtrl.text.trim().isNotEmpty && _bodyCtrl.text.trim().isNotEmpty;

  /// 손댄 것이 있는지. 수정 모드에서 그대로 저장하는 일을 막는다.
  /// (등록은 늘 보낼 것이 있다)
  bool get _isChanged {
    final notice = widget.notice;
    if (notice == null) return true;
    return _picked != null ||
        _titleCtrl.text.trim() != notice.title.trim() ||
        _bodyCtrl.text.trim() != notice.description.trim();
  }

  /// 아래 버튼들이 차지하는 높이. 키보드를 피해 스크롤할 때 쓴다.
  /// (버튼 54 + 여백 28, 수정 모드는 삭제 버튼까지 두 개)
  double get _bottomBarHeight => _isEdit ? 54 * 2 + 12 + 28 : 54 + 28;

  bool get _busy => _saving || _deleting;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final path = await pickImageFile();
    if (!mounted || path == null) return;
    try {
      final compressed = await compressImage(path);
      if (mounted) setState(() => _picked = File(compressed));
    } catch (_) {
      if (mounted) showErrorBanner('사진을 불러오지 못했습니다.');
    }
  }

  Future<void> _submit() async {
    if (!_isValid || !_isChanged || _busy) return;

    setState(() => _saving = true);
    final title = _titleCtrl.text.trim();
    final description = _bodyCtrl.text.trim();
    try {
      if (_isEdit) {
        await NoticeService.update(
          widget.notice!.id,
          title: title,
          description: description,
          imagePath: _picked?.path,
        );
      } else {
        await NoticeService.create(
          title: title,
          description: description,
          imagePath: _picked?.path,
        );
      }
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
      showErrorBanner(_isEdit ? '수정에 실패했습니다.' : '등록에 실패했습니다.');
    }
  }

  Future<void> _delete() async {
    if (_busy) return;

    final ok = await showConfirmDialog(
      context,
      title: '이 공지를 삭제할까요?',
      message: '첨부한 사진까지 함께 지워지고, 되돌릴 수 없습니다.',
      confirmText: '삭제하기',
      destructive: true,
    );
    if (ok != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await NoticeService.delete(widget.notice!.id);
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
    return Scaffold(
      // 배경색은 ThemeData.scaffoldBackgroundColor 가 정한다.
      // 키보드가 올라와도 하단 버튼은 제자리에 둔다. 입력창은 아래
      // KeyboardInset 안에서 스크롤로 올라온다.
      resizeToAvoidBottomInset: false,
      appBar: AppSubPageBar(title: _isEdit ? '공지 수정' : '공지 등록'),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            SafeArea(
              // 키보드가 올라오면 padding.bottom 이 0 이 되어 SafeArea 가
              // 잡아주던 여백이 사라진다. 아래에서 viewPadding 으로 고정한다.
              bottom: false,
              child: Column(
                children: [
                  Expanded(
                    child: KeyboardInset(
                      below:
                          _bottomBarHeight +
                          MediaQuery.viewPaddingOf(context).bottom,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppFieldLabel('제목'),
                            const SizedBox(height: 8),
                            TextInput(
                              hintText: '공지 제목을 입력해 주세요.',
                              maxLines: 1,
                              controller: _titleCtrl,
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 20),

                            AppFieldLabel('내용'),
                            const SizedBox(height: 8),
                            TextInput(
                              hintText: '학생들에게 전달할 내용을 작성해 주세요.',
                              maxLines: 8,
                              controller: _bodyCtrl,
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 20),

                            AppFieldLabel('사진 (선택)'),
                            const SizedBox(height: 10),
                            _ImagePickBox(
                              picked: _picked,
                              existingUrl: widget.notice?.imageUrl,
                              onPick: _pick,
                              // 서버에 올라간 사진을 떼는 API 가 없어서,
                              // 방금 고른 것만 취소할 수 있다.
                              onClear: _picked == null
                                  ? null
                                  : () => setState(() => _picked = null),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  SubmitButton(
                    text: _isEdit ? '저장하기' : '등록하기',
                    loadingButton: _saving,
                    onPressed: _isValid && _isChanged && !_deleting
                        ? _submit
                        : null,
                    padding: EdgeInsets.fromLTRB(20, 0, 20, _isEdit ? 12 : 28),
                  ),
                  if (_isEdit)
                    SubmitButton(
                      text: '공지 삭제',
                      errorButton: true,
                      loadingButton: _deleting,
                      onPressed: _saving ? null : _delete,
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

// ── 사진 첨부 ────────────────────────────────────────────────────
/// 정사각 썸네일 하나와 설명. 누르면 갤러리가 열린다.
class _ImagePickBox extends StatelessWidget {
  const _ImagePickBox({
    required this.picked,
    required this.existingUrl,
    required this.onPick,
    required this.onClear,
  });

  /// 방금 고른 사진.
  final File? picked;

  /// 이미 올라가 있는 사진. 수정 모드에서만 있다.
  final String? existingUrl;

  final VoidCallback onPick;

  /// null 이면 ✕ 를 그리지 않는다.
  final VoidCallback? onClear;

  static const _size = 88.0;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final existing = existingUrl;
    final hasExisting = existing != null && existing.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPick,
          child: Stack(
            // ✕ 가 썸네일 밖으로 조금 나간다.
            clipBehavior: Clip.none,
            children: [
              _thumbnail(palette, hasExisting ? existing : null),
              if (onClear != null)
                Positioned(
                  top: -6,
                  right: -6,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onClear,
                    child: Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: palette.bgCanvas,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: palette.borderDefault,
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: palette.textSecondary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              picked != null
                  ? '사진을 다시 누르면 다른 사진으로 바꿀 수 있습니다.'
                  : hasExisting
                  ? '새 사진을 고르면 올라가 있는 사진이 교체됩니다.'
                  : '사진을 한 장 첨부할 수 있습니다.',
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: palette.textTertiary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _thumbnail(AppPalette palette, String? url) {
    final file = picked;
    if (file != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(file, width: _size, height: _size, fit: BoxFit.cover),
      );
    }
    if (url != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          width: _size,
          height: _size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) =>
              _placeholder(palette, Icons.image_not_supported_outlined),
        ),
      );
    }
    return _placeholder(palette, Icons.add_rounded);
  }

  Widget _placeholder(AppPalette palette, IconData icon) => Container(
    width: _size,
    height: _size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: palette.bgSurface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: palette.borderDefault, width: 1),
    ),
    child: Icon(icon, size: 26, color: palette.textTertiary),
  );
}
