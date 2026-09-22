import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/return_service.dart';
import 'return_check_card.dart';
import '../../shared/app_banner.dart';
import '../../shared/app_colors.dart';
import '../../shared/app_palette.dart';
import '../../shared/app_refresh.dart';
import '../../shared/keyboard_inset.dart';
import '../../shared/app_skeleton.dart';
import '../../shared/submit_button.dart';

/// 부모님 연락처 자릿수. 하이픈 없이 숫자만 받는다.
const _phoneDigits = 11;

/// 복귀 체크 + 이번 주 외박/잔류 신청.
///
/// 복귀 체크는 카드를 누르면 QR이 뜨고, 사감이 그 QR을 스캔해 입실 처리한다.
/// 외박/잔류 신청은 `POST /stay-status` 에 실제로 연결되어 있다.
class ReturnStayScreen extends StatefulWidget {
  const ReturnStayScreen({super.key});

  @override
  State<ReturnStayScreen> createState() => _ReturnStayScreenState();
}

class _ReturnStayScreenState extends State<ReturnStayScreen>
    with AppBannerMixin {
  AppPalette get _palette => AppPalette.of(context);
  Color get _textColor => _palette.textPrimary;

  /// 화면에 보여줄 순서대로. 값은 서버가 쓰는 복귀 타입.
  static const _returnOptions = {
    'IMMEDIATE': '바로 복귀',
    'DINNER': '석식 복귀',
    'EIGHT_PM': '8시 복귀',
  };

  bool _loading = true;
  String? _username;

  /// 잔류 신청 대상자인지. false 면 외박/잔류 신청 자체를 보여주지 않는다.
  /// (서버도 대상자가 아니면 403 으로 막는다.)
  bool _canStay = false;

  /// 오늘 입실 체크 기록. 사감이 스캔할 때마다 한 건씩 쌓인다.
  List<ReturnRecord> _returnRecords = const [];

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
    // 연락처가 채워져야 전송 버튼이 열리므로 입력마다 다시 그린다.
    _phoneController.addListener(_onPhoneChanged);
    _load();
  }

  @override
  void dispose() {
    _phoneController.removeListener(_onPhoneChanged);
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

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final results = await Future.wait([
        AuthService.getMe(),
        AuthService.getMyStayStatus(),
        // 복귀 기록은 없어도 화면이 동작하므로 실패해도 넘어간다.
        ReturnService.getMine().catchError((_) => <ReturnRecord>[]),
      ]);
      if (!mounted) return;

      final user = results[0] as Map<String, dynamic>;
      final history = results[1] as List<dynamic>;
      final thisWeek = history.cast<Map<String, dynamic>>().where(
        (record) => record['week_start'] == _weekStart,
      );

      final record = thisWeek.isEmpty ? null : thisWeek.first;

      setState(() {
        _returnRecords = results[2] as List<ReturnRecord>;
        _username = user['username'] as String?;
        _canStay = user['can_staying'] == true;
        _submittedStatus = record?['status'] as String?;
        // 서버에 신청 기록이 있으면 그 값이 정답. 없으면 고르던 선택을 유지한다.
        _selected = _submittedStatus ?? _selected;
        _loading = false;
      });

      // 신청을 마친 주에는 그때 낸 연락처를 그대로 보여준다.
      final submittedPhone = record?['parent_phone'] as String?;
      if (submittedPhone != null && submittedPhone.isNotEmpty) {
        _phoneController.text = submittedPhone;
      }
    } on SessionExpiredException {
      if (mounted) context.go('/login');
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      showErrorBanner('정보를 불러오지 못했습니다.');
    }
  }

  /// 이 복귀 타입으로 찍은 시각. 여러 번 찍었으면 마지막 것.
  /// 시간대 밖에 찍어 타입이 없는 기록은 어느 칸에도 걸리지 않는다.
  DateTime? _checkedAtFor(String type) {
    final matched = _returnRecords.where((r) => r.returnType == type);
    if (matched.isEmpty) return null;
    return matched
        .map((r) => r.actualTime!)
        .reduce((a, b) => a.isAfter(b) ? a : b);
  }

  /// 선택된 항목을 다시 누르면 선택을 해제한다.
  void _toggle(String status) {
    setState(() => _selected = _selected == status ? null : status);
  }

  void _onPhoneChanged() => setState(() {});

  /// 잔류/외박 선택과 부모님 연락처가 모두 채워져야 전송할 수 있다.
  /// (서버에서 parent_phone 이 필수다)
  bool get _canSubmit =>
      _submittedStatus == null &&
      _selected != null &&
      _phoneController.text.length == _phoneDigits;

  Future<void> _submit() async {
    if (!_canSubmit || _submitting) return;
    setState(() => _submitting = true);
    try {
      await AuthService.createStayStatus(
        _selected!,
        parentPhone: _phoneController.text.trim(),
      );
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
    final palette = AppPalette.of(context);
    return Stack(
      children: [
        KeyboardInset(
          child: AppRefreshScrollView(
            onRefresh: () => _load(silent: true),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.only(
                  top: 16,
                  bottom: KeyboardInset.bottomReserve(context, navBar: 100),
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── 인사말 ──────────────────────────────────
                          AppSkeletonSwitcher(
                            loading: _loading,
                            skeleton: const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppSkeleton(width: 130, height: 24),
                                SizedBox(height: 8),
                                AppSkeleton(width: 190, height: 24),
                              ],
                            ),
                            child: Text(
                              '${_username ?? ''}님,\n입실체크를 해주세요',
                              style: TextStyle(
                                fontSize: 20,
                                height: 1.35,
                                fontWeight: FontWeight.w800,
                                color: _textColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          Text(
                            '복귀 체크',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: _textColor,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // ── 입실 체크 (QR) ────────────────────────
                          // 어떤 복귀인지는 사감이 스캔한 시각을 보고 서버가
                          // 정하므로 앱은 타입을 고르지 않는다. 버튼은 하나.
                          ReturnCheckCard(
                            label: '입실 체크하기',
                            checkedAt: lastCheckedAt(_returnRecords),
                            onChecked: () => _load(silent: true),
                          ),
                          const SizedBox(height: 12),

                          // ── 시간대별 결과 (확인용) ─────────────────
                          Row(
                            children: [
                              for (final entry in _returnOptions.entries) ...[
                                Expanded(
                                  child: _ReturnSlotCard(
                                    label: entry.value,
                                    // 체크인마다 기록이 쌓이므로 하루에 여러 칸이
                                    // 동시에 채워질 수 있다.
                                    checkedAt: _checkedAtFor(entry.key),
                                  ),
                                ),
                                if (entry.key != _returnOptions.keys.last)
                                  const SizedBox(width: 10),
                              ],
                            ],
                          ),

                          if (_canStay) ...[
                            const SizedBox(height: 28),

                            // ── 외박/잔류 신청 (잔류 대상자에게만) ──────
                            Text(
                              '이번 주 외박/잔류 신청',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
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
                              Text(
                                '이번 주는 이미 신청했습니다. 변경이 필요하면 사감실로 문의해 주세요.',
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: palette.textTertiary,
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
                        onPressed: _canSubmit ? _submit : null,
                      ),
                  ]),
                ),
              ),
            ],
          ),
        ),
        buildBanner(),
      ],
    );
  }
}

// ── 시간대별 복귀 결과 (확인용, 누를 수 없다) ────────────────────
class _ReturnSlotCard extends StatelessWidget {
  const _ReturnSlotCard({required this.label, this.checkedAt});

  final String label;

  /// 이 시간대로 입실 체크된 시각. null 이면 해당 없음.
  final DateTime? checkedAt;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final done = checkedAt != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: palette.bgSurface,
        borderRadius: BorderRadius.circular(12),
        // 완료된 칸만 테두리로 한 번 더 구분해 준다.
        border: done ? Border.all(color: AppBrand.primary) : null,
      ),
      child: Column(
        children: [
          Icon(
            done ? Icons.check_circle : Icons.circle_outlined,
            size: 18,
            color: done ? AppBrand.primary : palette.textTertiary,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: done ? AppBrand.primary : palette.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            done ? returnTimeLabel(checkedAt!) : '-',
            style: TextStyle(fontSize: 11, color: palette.textTertiary),
          ),
        ],
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
    final palette = AppPalette.of(context);
    return Text(
      text,
      style: TextStyle(fontSize: 13, color: palette.textSecondary),
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
    final palette = AppPalette.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppBrand.primary : palette.bgSurface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: palette.textPrimary,
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
    final palette = AppPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: palette.bgSurface,
        borderRadius: BorderRadius.circular(15),
      ),
      child: TextField(
        controller: controller,
        readOnly: !enabled,
        keyboardType: TextInputType.number,
        inputFormatters: [
          // 하이픈 없이 숫자 11자리만
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(_phoneDigits),
        ],
        style: TextStyle(color: palette.textPrimary, fontSize: 13),
        decoration: InputDecoration(
          hintText: '숫자만 입력',
          hintStyle: TextStyle(color: palette.textTertiary, fontSize: 13),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 17),
        ),
      ),
    );
  }
}
