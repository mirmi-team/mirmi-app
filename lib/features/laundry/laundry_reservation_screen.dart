import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/laundry_service.dart';
import '../../shared/app_back_button.dart';
import '../../shared/app_colors.dart';
import '../../shared/app_palette.dart';
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

  late final List<Map<String, dynamic>> _timeSlots;
  List<Map<String, dynamic>> _schedule = [];

  @override
  void initState() {
    super.initState();
    final today = AppClock.now();
    _timeSlots = [
      {
        'label': '14:30~16:40',
        'start': DateTime(today.year, today.month, today.day, 14, 30),
        'end': DateTime(today.year, today.month, today.day, 16, 40),
      },
      {
        'label': '19:00~20:10',
        'start': DateTime(today.year, today.month, today.day, 19, 0),
        'end': DateTime(today.year, today.month, today.day, 20, 10),
      },
      {
        'label': '20:10~21:20',
        'start': DateTime(today.year, today.month, today.day, 20, 10),
        'end': DateTime(today.year, today.month, today.day, 21, 20),
      },
      {
        'label': '21:20~22:30',
        'start': DateTime(today.year, today.month, today.day, 21, 20),
        'end': DateTime(today.year, today.month, today.day, 22, 30),
      },
    ];
    _loadMe();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    final machineId = widget.machine['id'] as int;
    try {
      final schedule = await LaundryService.getSchedule(
        date: AppClock.now(),
        floor: machineId ~/ 10,
      );
      if (mounted) setState(() => _schedule = schedule);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  String _hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// 이미 지난 시간 || 고정 시간 || 다른 사람이 신청한 시간이면 true
  bool _isUnavailable(Map<String, dynamic> slot) {
    if (!AppClock.now().isBefore(slot['end'] as DateTime)) return true;
    final machineNo = (widget.machine['id'] as int) % 10;
    final start = _hhmm(slot['start'] as DateTime);
    final end = _hhmm(slot['end'] as DateTime);
    return _schedule.any(
      (s) =>
          s['machine_no'] == machineNo &&
          (s['start_time'] as String).startsWith(start) &&
          (s['end_time'] as String).startsWith(end) &&
          (s['type'] == 'FIXED' || s['room_number'] != null),
    );
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
      await LaundryService.createReservation(
        laundryId: widget.machine['id'] as int,
        roomNumber: _me!['room_number'] as int,
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
                  Icon(Icons.info_outline, size: 14, color: _captionColor),
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

              ...List.generate(_timeSlots.length, (index) {
                final slot = _timeSlots[index];
                final isDisabled = _isUnavailable(slot);
                final isSelected = !isDisabled && index == _selectedTimeIndex;
                return GestureDetector(
                  onTap: isDisabled
                      ? null
                      : () => setState(
                          () => _selectedTimeIndex = isSelected ? null : index,
                        ),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(24),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isSelected ? _teal : _cardColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      slot['label'],
                      style: TextStyle(
                        color: isDisabled ? _captionColor : _textColor,
                        fontSize: 15,
                        fontWeight: FontWeight(590),
                      ),
                    ),
                  ),
                );
              }),

              const Spacer(),
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
