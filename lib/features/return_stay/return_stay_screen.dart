import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/auth_service.dart';
import '../../shared/app_banner.dart';
import '../../shared/app_colors.dart';
import '../../shared/app_refresh.dart';
import '../../shared/submit_button.dart';

/// 복귀 체크 + 이번 주 외박/잔류 신청.
///
/// 복귀 체크는 백엔드(`return-requests`)가 아직 빈 스캐폴드라 화면만 있다.
/// 외박/잔류 신청은 `POST /stay-status` 에 실제로 연결되어 있다.
class ReturnStayScreen extends StatefulWidget {
  const ReturnStayScreen({super.key});

  @override
  State<ReturnStayScreen> createState() => _ReturnStayScreenState();
}

class _ReturnStayScreenState extends State<ReturnStayScreen>
    with AppBannerMixin {
  static const _textColor = AppColors.mainText;

  static const _returnOptions = ['바로 복귀', '석식 복귀', '8시 복귀'];

  bool _loading = true;
  String? _username;

  /// 잔류 신청 대상자인지. false 면 외박/잔류 신청 자체를 보여주지 않는다.
  /// (서버도 대상자가 아니면 403 으로 막는다.)
  bool _canStay = false;

  /// 이번 주에 이미 신청한 상태. 있으면 폼을 잠근다.
  /// (백엔드에 수정 API 가 없어 한 주에 한 번만 신청할 수 있다.)
  String? _submittedStatus;

  /// 'STAY' | 'OUTING'
  String? _selected;

  final _phoneController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  /// 이번 주 월요일. 서버(KST 기준)와 같은 방식으로 계산한다.
  String get _weekStart {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final mm = monday.month.toString().padLeft(2, '0');
    final dd = monday.day.toString().padLeft(2, '0');
    return '${monday.year}-$mm-$dd';
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        AuthService.getMe(),
        AuthService.getMyStayStatus(),
      ]);
      if (!mounted) return;

      final user = results[0] as Map<String, dynamic>;
      final history = results[1] as List<dynamic>;
      final thisWeek = history.cast<Map<String, dynamic>>().where(
        (record) => record['week_start'] == _weekStart,
      );

      setState(() {
        _username = user['username'] as String?;
        _canStay = user['can_staying'] == true;
        _submittedStatus = thisWeek.isEmpty
            ? null
            : thisWeek.first['status'] as String?;
        _selected = _submittedStatus;
        _loading = false;
      });
    } on SessionExpiredException {
      if (mounted) context.go('/login');
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      showErrorBanner('정보를 불러오지 못했습니다.');
    }
  }

  /// 선택된 항목을 다시 누르면 선택을 해제한다.
  void _toggle(String status) {
    setState(() => _selected = _selected == status ? null : status);
  }

  Future<void> _submit() async {
    if (_selected == null || _submitting) return;
    setState(() => _submitting = true);
    try {
      // 부모님 연락처는 백엔드에 저장할 곳이 없어 아직 보내지 않는다.
      await AuthService.createStayStatus(_selected!);
      if (!mounted) return;
      setState(() {
        _submittedStatus = _selected;
        _submitting = false;
      });
      showSuccessBanner('이번 주 신청이 완료되었습니다.');
    } on SessionExpiredException {
      if (mounted) context.go('/login');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showErrorBanner(e.message); // 403 잔류 대상자 아님 / 409 이미 신청함
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showErrorBanner('신청에 실패했습니다.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (_loading)
          const AppLoadingIndicator()
        else
          ListView(
            padding: const EdgeInsets.only(bottom: 100),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 인사말 ──────────────────────────────────
                    Text(
                      '${_username ?? ''}님,\n입실체크를 해주세요',
                      style: const TextStyle(
                        fontSize: 20,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                        color: _textColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '복귀 체크',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _textColor,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── 복귀 체크 (백엔드 준비 전, 화면만) ────────
                    for (final label in _returnOptions) ...[
                      _ReturnCard(
                        label: label,
                        onTap: () => showInfoBanner('복귀 체크 기능은 준비 중입니다.'),
                      ),
                      const SizedBox(height: 12),
                    ],

                    if (_canStay) ...[
                      const SizedBox(height: 28),

                      // ── 외박/잔류 신청 (잔류 대상자에게만) ──────
                      const Text(
                        '이번 주 외박/잔류 신청',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: _textColor,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const _FieldLabel('1. 외박/잔류 여부를 선택해 주세요.'),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _ChoiceButton(
                              label: '기숙사 잔류',
                              selected: _selected == 'STAY',
                              enabled: _submittedStatus == null,
                              onTap: () => _toggle('STAY'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ChoiceButton(
                              label: '금토외박',
                              selected: _selected == 'OUTING',
                              enabled: _submittedStatus == null,
                              onTap: () => _toggle('OUTING'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      const _FieldLabel('2. 부모님 연락처'),
                      const SizedBox(height: 10),
                      _PhoneField(
                        controller: _phoneController,
                        enabled: _submittedStatus == null,
                      ),
                      if (_submittedStatus != null) ...[
                        const SizedBox(height: 14),
                        const Text(
                          '이번 주는 이미 신청했습니다. 변경이 필요하면 사감실로 문의해 주세요.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: AppColors.caption,
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
                    ],
                  ],
                ),
              ),
              if (_canStay)
                SubmitButton(
                  text: _submittedStatus != null ? '이번 주 신청 완료' : '전송',
                  loadingButton: _submitting,
                  onPressed: (_submittedStatus != null || _selected == null)
                      ? null
                      : _submit,
                ),
            ],
          ),
        buildBanner(),
      ],
    );
  }
}

// ── 복귀 체크 카드 ───────────────────────────────────────────────
class _ReturnCard extends StatelessWidget {
  const _ReturnCard({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.mainText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '입실 체크 시 사감 선생님께 알림이 발송됩니다.',
                    style: TextStyle(fontSize: 12, color: AppColors.caption),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(
              Icons.chevron_right,
              color: AppColors.mainText,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}

// ── 항목 라벨 ────────────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 13, color: AppColors.body),
    );
  }
}

// ── 잔류 / 외박 선택 버튼 ────────────────────────────────────────
class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.mainColor : AppColors.card,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: AppColors.mainText,
          ),
        ),
      ),
    );
  }
}

// ── 부모님 연락처 입력 ───────────────────────────────────────────
class _PhoneField extends StatelessWidget {
  const _PhoneField({required this.controller, required this.enabled});

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(15),
      ),
      child: TextField(
        controller: controller,
        readOnly: !enabled,
        keyboardType: TextInputType.phone,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
          LengthLimitingTextInputFormatter(13),
        ],
        style: const TextStyle(color: AppColors.mainText, fontSize: 13),
        decoration: const InputDecoration(
          hintText: '010-xxxx-xxxx',
          hintStyle: TextStyle(color: AppColors.caption, fontSize: 13),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 17),
        ),
      ),
    );
  }
}
