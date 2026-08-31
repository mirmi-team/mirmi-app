import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/laundry_service.dart';
import '../../shared/app_colors.dart';

class LaundryReservationScreen extends StatefulWidget {
  const LaundryReservationScreen({super.key, required this.machine});
  final Map<String, dynamic> machine;

  @override
  State<LaundryReservationScreen> createState() =>
      _LaundryReservationScreenState();
}

class _LaundryReservationScreenState extends State<LaundryReservationScreen> {
  static const _teal = AppColors.mainColor;
  static const _bgColor = AppColors.backB;
  static const _captionColor = AppColors.caption;
  static const _textColor = AppColors.mainText;
  static const _cardColor = AppColors.card;

  Map<String, dynamic>? _me;
  bool _submitting = false;
  int? _selectedTimeIndex;

  late final List<Map<String, dynamic>> _timeSlots;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
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
  }

  Future<void> _loadMe() async {
    final me = await AuthService.getMe();
    if (mounted) setState(() => _me = me);
  }

  Future<void> _submit() async {
    if (_selectedTimeIndex == null || _me == null) return;
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
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: _textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
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
              const Text(
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
                style: const TextStyle(
                  color: _textColor,
                  fontSize: 20,
                  fontWeight: FontWeight(700),
                ),
              ),
              const SizedBox(height: 4),
              const Row(
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

              const Text(
                '세탁기 사용 신청',
                style: TextStyle(
                  color: _textColor,
                  fontSize: 16,
                  fontWeight: FontWeight(590),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
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
                final isSelected = index == _selectedTimeIndex;
                return GestureDetector(
                  onTap: () => setState(() => _selectedTimeIndex = index),
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
                        color: _textColor,
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
                        ? const Color(0xffA1A1AA)
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
