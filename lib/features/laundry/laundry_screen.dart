import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/laundry_service.dart';
import '../../shared/app_colors.dart';
import 'laundry_reservation_screen.dart';
import '../../core/utils/app_clock.dart';
import '../../shared/app_refresh.dart';

class LaundryScreen extends StatefulWidget {
  const LaundryScreen({super.key});
  @override
  State<LaundryScreen> createState() => _LaundryScreenState();
}

class _LaundryScreenState extends State<LaundryScreen> {
  static const _teal = AppColors.mainColor;
  static const _bgColor = AppColors.backB;
  static const _captionColor = AppColors.caption;
  static const _textColor = AppColors.mainText;
  static const _cardColor = AppColors.card;
  static const _errorColor = AppColors.error;

  bool _isLoading = true;
  String? _errorMessage;
  int? _floor;
  List<Map<String, dynamic>> _machines = [];

  //고정 시간표
  DateTime _selectedDate = AppClock.now();
  late DateTime _weekStart;
  late DateTime _weekEnd;
  static const _weekdayNames = ['월', '화', '수', '목', '금', '토', '일'];

  // 요일별 세탁기 사용 시간표
  List<Map<String, dynamic>> _schedule = []; // 주간표에서 선택된 날짜 기준
  List<Map<String, dynamic>> _todaySchedule = []; // 실시간 사용 기준(오늘)

  String get _selectedDateLabel {
    final month = _selectedDate.month;
    final day = _selectedDate.day;
    final weekday = _weekdayNames[_selectedDate.weekday - 1];
    return '$month월 $day일($weekday)';
  }

  bool get _canGoPrev => _selectedDate.isAfter(_weekStart);
  bool get _canGoNext => _selectedDate.isBefore(_weekEnd);

  void _changeDay(int delta) {
    final newDate = _selectedDate.add(Duration(days: delta));
    if (newDate.isBefore(_weekStart) || newDate.isAfter(_weekEnd)) return;
    setState(() => _selectedDate = newDate);
    _loadSchedule(newDate);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _loadSchedule(DateTime date) async {
    if (_floor == null) return;
    if (_isSameDay(date, AppClock.now())) {
      setState(() => _schedule = _todaySchedule);
      return;
    }
    try {
      final schedule = await LaundryService.getSchedule(
        date: date,
        floor: _floor!,
      );
      if (!mounted) return;
      setState(() => _schedule = schedule);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    }
  }

  String _twoDigit(int n) => n.toString().padLeft(2, '0');

  @override
  void initState() {
    super.initState();
    final now = AppClock.now();
    final daysSinceSunday = now.weekday % 7;
    _weekStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: daysSinceSunday));
    _weekEnd = _weekStart.add(const Duration(days: 6));
    _selectedDate = DateTime(now.year, now.month, now.day);
    _loadData();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final me = await AuthService.getMe();
      final roomNumber = me['room_number'] as int;
      final floor = roomNumber ~/ 100;

      final allMachines = await LaundryService.getMachines();
      final myFloorMachines =
          allMachines.where((m) => (m['id'] as int) ~/ 10 == floor).toList()
            ..sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));

      if (!mounted) return;
      setState(() {
        _floor = floor;
        _machines = myFloorMachines;
        _isLoading = false;
      });

      await _loadTodaySchedule(floor);
    } on SessionExpiredException {
      // TODO: context.go('/login')
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '데이터를 불러오지 못했습니다: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadTodaySchedule(int floor) async {
    try {
      final schedule = await LaundryService.getSchedule(
        date: AppClock.now(),
        floor: floor,
      );
      if (!mounted) return;
      setState(() {
        _todaySchedule = schedule;
        if (_isSameDay(_selectedDate, AppClock.now())) {
          _schedule = schedule;
        }
      });
      if (!_isSameDay(_selectedDate, AppClock.now())) {
        await _loadSchedule(_selectedDate);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    }
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

  Map<String, dynamic>? _findCurrentOccupantFor(int machineNo) {
    final now = AppClock.now();
    final matches = _todaySchedule.where((s) {
      if (s['machine_no'] != machineNo || s['room_number'] == null) {
        return false;
      }
      final start = _timeOn(now, s['start_time'] as String);
      final end = _timeOn(now, s['end_time'] as String);
      return now.isAfter(start) && now.isBefore(end);
    });
    return matches.isEmpty ? null : matches.first;
  }

  List<Map<String, String>> _scheduleSlotTimes() {
    final seen = <String>{};
    final result = <Map<String, String>>[];
    for (final s in _schedule) {
      final start = s['start_time'] as String;
      final end = s['end_time'] as String;
      if (seen.add('$start-$end')) {
        result.add({'start_time': start, 'end_time': end});
      }
    }
    result.sort((a, b) => a['start_time']!.compareTo(b['start_time']!));
    return result;
  }

  Map<String, dynamic>? _findScheduleSlot(
    int machineNo,
    Map<String, String> slotTime,
  ) {
    final matches = _schedule.where(
      (s) =>
          s['machine_no'] == machineNo &&
          s['start_time'] == slotTime['start_time'] &&
          s['end_time'] == slotTime['end_time'],
    );
    return matches.isEmpty ? null : matches.first;
  }

  Future<void> _goToReservation(Map<String, dynamic> machine) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => LaundryReservationScreen(machine: machine),
      ),
    );
    if (result == true) _loadData();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _bgColor,
        body: const AppLoadingIndicator(),
      );
    }

    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: AppRefreshScrollView(
          onRefresh: () => _loadData(silent: true),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const Text(
                    '남은 세탁기를 확인하고\n빠르게 예약해 보세요.',
                    style: TextStyle(
                      color: _textColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 36),

                  if (_errorMessage != null) ...[
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: _errorColor),
                    ),
                    const SizedBox(height: 12),
                  ],

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '세탁기 사용 현황',
                        style: TextStyle(
                          color: _textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E2A2E),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_floor ?? '-'}F 세탁실',
                          style: const TextStyle(
                            color: _teal,
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      for (int i = 0; i < _machines.length; i++) ...[
                        Expanded(child: _buildMachineCard(i, _machines[i])),
                        if (i != _machines.length - 1) const SizedBox(width: 8),
                      ],
                    ],
                  ),
                  const SizedBox(height: 68),

                  _buildWeeklyScheduleTable(),
                  const SizedBox(height: 149),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMachineCard(int index, Map<String, dynamic> machine) {
    final occupant = _findCurrentOccupantFor(index + 1);
    final bool isOccupied = occupant != null;

    final Widget detailWidget = isOccupied
        ? Column(
            children: [
              Text(
                '${occupant['room_number']}호',
                style: const TextStyle(
                  color: _textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                '사용중',
                style: TextStyle(color: _captionColor, fontSize: 12),
              ),
            ],
          )
        : const Text(
            '비어 있음',
            style: TextStyle(
              color: _teal,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          );

    final card = Container(
      height: 172,
      padding: EdgeInsets.only(top: 16, bottom: isOccupied ? 5 : 16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xff3F3F46), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${index + 1}호',
            style: const TextStyle(
              color: _textColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 10),
          Icon(
            Icons.local_laundry_service,
            size: 54,
            color: isOccupied ? _teal : Colors.white,
          ),
          SizedBox(height: isOccupied ? 10 : 14),
          detailWidget,
        ],
      ),
    );

    return GestureDetector(onTap: () => _goToReservation(machine), child: card);
  }

  //시간표
  Widget _buildWeeklyScheduleTable() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: _canGoPrev ? () => _changeDay(-1) : null,
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFF2A2A2E),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.chevron_left,
                  color: _canGoPrev ? _textColor : const Color(0xFF52525B),
                ),
              ),
            ),
            Text(
              _selectedDateLabel,
              style: const TextStyle(
                color: _textColor,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            GestureDetector(
              onTap: _canGoNext ? () => _changeDay(1) : null,
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFF2A2A2E),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.chevron_right,
                  color: _canGoNext ? _textColor : const Color(0xFF52525B),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 20),
                    child: const SizedBox(
                      width: 40,
                      child: Text(
                        '시간',
                        style: TextStyle(
                          color: _captionColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),

                  ..._machines.asMap().entries.map(
                    (e) => Expanded(
                      child: Text(
                        '${e.key + 1}호',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: _textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(height: 1, color: const Color(0xFF27272A)),
              const SizedBox(height: 18),
              ..._scheduleSlotTimes().map(
                (slotTime) => _buildScheduleRow(slotTime),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleRow(Map<String, String> slotTime) {
    final startLabel = slotTime['start_time']!.substring(0, 5);
    final endLabel = '~${slotTime['end_time']!.substring(0, 5)}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: SizedBox(
              width: 47,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    startLabel,
                    style: const TextStyle(
                      color: _textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    endLabel,
                    style: const TextStyle(color: _textColor, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),

          ..._machines.asMap().entries.map((entry) {
            final machineNo = entry.key + 1;
            final matched = _findScheduleSlot(machineNo, slotTime);
            final bool isFixed = matched != null && matched['type'] == 'FIXED';
            final bool isFilled =
                matched != null && matched['room_number'] != null;
            final String label = isFilled
                ? '${matched['room_number']}호'
                : '비어있음';

            return Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isFixed
                      ? _teal
                      : (isFilled ? _textColor : _captionColor),
                  fontSize: 14,
                  fontWeight: isFilled ? FontWeight.w600 : FontWeight.w400,
                  // fontStyle: FontStyle.normal,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
