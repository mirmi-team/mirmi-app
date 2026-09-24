import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/laundry_service.dart';
import '../../shared/app_back_button.dart';
import '../../shared/app_dialog.dart';
import '../../shared/app_colors.dart';
import '../../shared/app_palette.dart';
import '../../shared/app_skeleton.dart';
import '../../core/utils/app_clock.dart';

class LaundryReservationScreen extends StatefulWidget {
  const LaundryReservationScreen({super.key, required this.machine});
  final Map<String, dynamic> machine;

  @override
  State<LaundryReservationScreen> createState() =>
      _LaundryReservationScreenState();
}

class _LaundryReservationScreenState extends State<LaundryReservationScreen> {
  static const _teal = AppBrand.primary;

  // 테마에 따라 바뀌는 색. build 에서 현재 팔레트를 받아 쓴다.
  late AppPalette _palette;
  Color get _captionColor => _palette.textTertiary;
  Color get _textColor => _palette.textPrimary;
  Color get _cardColor => _palette.bgSurface;

  /// 시간을 고르기 전의 예약 버튼
  Color get _disabledBtnColor => _palette.borderDefault;

  Map<String, dynamic>? _me;
  bool _submitting = false;
  int? _selectedTimeIndex;

  List<Map<String, dynamic>> _timeSlots = [];
  bool _slotsLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMe();
    _loadSlots();
  }

  DateTime _timeOn(DateTime day, String hhmmss) {
    final parts = hhmmss.split(':');
    return DateTime(
      day.year,
      day.month,
      day.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  Future<void> _loadSlots() async {
    final machineId = widget.machine['id'] as int;
    final machineNo = widget.machine['machine_no'] as int;
    try {
      final today = AppClock.now();
      final schedule = await LaundryService.getSchedule(
        date: today,
        floor: machineId ~/ 10,
      );
      final mine = schedule.where((s) => s['machine_no'] == machineNo).toList()
        ..sort(
          (a, b) =>
              (a['start_time'] as String).compareTo(b['start_time'] as String),
        );
      if (!mounted) return;
      setState(() {
        _timeSlots = mine.map((s) {
          final startStr = s['start_time'] as String;
          final endStr = s['end_time'] as String;
          return {
            'label': '${startStr.substring(0, 5)}~${endStr.substring(0, 5)}',
            'start': _timeOn(today, startStr),
            'end': _timeOn(today, endStr),
            'taken': s['type'] == 'FIXED' || s['room_number'] != null,
            'rooms': [
              s['room_number'],
              s['room_number_2'],
            ].where((r) => r != null).map((r) => '$r호').join(', '),
          };
        }).toList();
        _slotsLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _slotsLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  // 사용 불가 카드에 붙일 거
  String _unavailableLabel(Map<String, dynamic> slot) {
    if (!AppClock.now().isBefore(slot['end'] as DateTime)) return '만료';
    final rooms = slot['rooms'] as String;
    return rooms.isEmpty ? '고정' : rooms;
  }

  /// 이미 지난 시간 || 고정 시간 || 다른 사람이 신청한 시간이면 true
  bool _isUnavailable(Map<String, dynamic> slot) {
    if (!AppClock.now().isBefore(slot['end'] as DateTime)) return true;
    return slot['taken'] as bool;
  }

  Future<void> _loadMe() async {
    final me = await AuthService.getMe();
    if (mounted) setState(() => _me = me);
  }

  Future<void> _submit() async {
    if (_selectedTimeIndex == null || _me == null) return;
    if (AppClock.now().hour < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('오전 6시 이후부터 세탁기 예약이 가능합니다.')),
      );
      return;
    }
    setState(() => _submitting = true);

    final slot = _timeSlots[_selectedTimeIndex!];
    try {
      final roomNumber = _me!['room_number'] as int;
      final today = AppClock.now();
      final schedule = await LaundryService.getSchedule(
        date: today,
        floor: (widget.machine['id'] as int) ~/ 10,
      );
      final alreadyReserved = schedule.any(
        (s) =>
            s['room_number'] == roomNumber || s['room_number_2'] == roomNumber,
      );
      if (alreadyReserved) {
        if (mounted) {
          await showConfirmDialog(
            context,
            title: '이미 예약한 시간이 있어요',
            message: '같은 날짜에는 호실당 한 번만 예약할 수 있습니다',
            cancelText: '닫기',
          );
        }
        return;
      }
      await LaundryService.createReservation(
        laundryId: widget.machine['id'] as int,
        roomNumber: roomNumber,
        start: slot['start'] as DateTime,
        end: slot['end'] as DateTime,
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    _palette = AppPalette.of(context);
    return Scaffold(
      // 배경색은 ThemeData.scaffoldBackgroundColor 가 정한다.
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: AppBackButton(onTap: () => Navigator.pop(context)),
        title: Text(
          '세탁기 예약',
          style: TextStyle(
            color: _textColor,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 33),
                      Text(
                        '예약자 정보',
                        style: TextStyle(
                          color: _textColor,
                          fontSize: 13,
                          fontWeight: FontWeight(400),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _me == null
                            ? '불러오는 중...'
                            : '${_me!['room_number']}호 ${_me!['username']}님',
                        style: TextStyle(
                          color: _textColor,
                          fontSize: 20,
                          fontWeight: FontWeight(700),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 14,
                            color: _captionColor,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '예약자 정보는 변경할 수가 없어요.',
                            style: TextStyle(
                              color: _captionColor,
                              fontSize: 13,
                              fontWeight: FontWeight(510),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      Text(
                        '세탁기 사용 신청',
                        style: TextStyle(
                          color: _textColor,
                          fontSize: 16,
                          fontWeight: FontWeight(590),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '예약 시간을 선택해 주세요.',
                        style: TextStyle(
                          color: _textColor,
                          fontSize: 13,
                          fontWeight: FontWeight(400),
                        ),
                      ),
                      const SizedBox(height: 24),

                      AppSkeletonSwitcher(
                        loading: _slotsLoading,
                        skeleton: Column(
                          children: [
                            for (int i = 0; i < 4; i++) ...[
                              const AppSkeleton(height: 68, radius: 8),
                              const SizedBox(height: 10),
                            ],
                          ],
                        ),
                        child: Column(
                          children: List.generate(_timeSlots.length, (index) {
                            final slot = _timeSlots[index];
                            final isDisabled = _isUnavailable(slot);
                            final isSelected =
                                !isDisabled && index == _selectedTimeIndex;
                            return GestureDetector(
                              onTap: isDisabled
                                  ? null
                                  : () => setState(
                                      () => _selectedTimeIndex = isSelected
                                          ? null
                                          : index,
                                    ),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(24),
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: isSelected ? _teal : _cardColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      slot['label'],
                                      style: TextStyle(
                                        color: isDisabled
                                            ? _captionColor
                                            : _textColor,
                                        fontSize: 15,
                                        fontWeight: FontWeight(590),
                                      ),
                                    ),
                                    if (isDisabled) ...[
                                      const Spacer(),
                                      Text(
                                        _unavailableLabel(slot),
                                        style: TextStyle(
                                          color: _captionColor,
                                          fontSize: 15,
                                          fontWeight: FontWeight(590),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: (_selectedTimeIndex != null && !_submitting)
                    ? _submit
                    : null,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: _selectedTimeIndex == null || _submitting
                        ? _disabledBtnColor
                        : _teal,
                    borderRadius: BorderRadius.circular(72),
                  ),
                  child: Text(
                    _submitting ? '예약중' : '예약하기',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _textColor,
                      fontSize: 15,
                      fontWeight: FontWeight(590),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
