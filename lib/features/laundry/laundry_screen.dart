import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/laundry_service.dart';
import '../../shared/app_colors.dart';
import 'laundry_reservation_screen.dart';

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
  List<Map<String, dynamic>> _reservations = [];

  //고정 시간표
  DateTime _selectedDate = DateTime.now();
  static const _weekdayNames = ['월', '화', '수', '목', '금', '토', '일'];

  final List<Map<String, dynamic>> _weeklySlots = const [
    {'startH': 16, 'startM': 30, 'endH': 18, 'endM': 40},
    {'startH': 19, 'startM': 10, 'endH': 20, 'endM': 20},
    {'startH': 20, 'startM': 20, 'endH': 21, 'endM': 10},
    {'startH': 21, 'startM': 10, 'endH': 22, 'endM': 30},
  ];

  // 고정 시간표 데이터 --하준띠
  List<Map<String, dynamic>> _fixedSchedule = [];
  String get _selectedDateLabel {
    final month = _selectedDate.month;
    final day = _selectedDate.day;
    final weekday = _weekdayNames[_selectedDate.weekday - 1];
    return '$month월 $day일($weekday)';
  }

  void _changeDay(int delta) {
    setState(() => _selectedDate = _selectedDate.add(Duration(days: delta)));
  }

  String _twoDigit(int n) => n.toString().padLeft(2, '0');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final me = await AuthService.getMe();
      final roomNumber = me['room_number'] as int;
      final floor = roomNumber ~/ 100;

      final allMachines = await LaundryService.getMachines();
      final myFloorMachines =
          allMachines.where((m) => (m['id'] as int) ~/ 10 == floor).toList()
            ..sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));
      //다른 사람 데이터도 불러와야됨--하준띠
      final reservations = await LaundryService.getMyReservations();

      setState(() {
        _floor = floor;
        _machines = myFloorMachines;
        _reservations = reservations;
        _isLoading = false;
      });
    } on SessionExpiredException {
      // TODO: context.go('/login')
    } on ApiException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '데이터를 불러오지 못했습니다: $e';
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic>? _findRunningReservationFor(int laundryId) {
    final now = DateTime.now();
    final matches = _reservations.where((r) {
      if (r['laundry_id'] != laundryId) return false;
      final start = DateTime.parse(r['start_time']);
      final end = DateTime.parse(r['end_time']);
      return now.isAfter(start) && now.isBefore(end);
    });
    return matches.isEmpty ? null : matches.first;
  }

  Map<String, dynamic>? _findReservationForSlot(
    int laundryId,
    Map<String, dynamic> slot,
  ) {
    final slotStart = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      slot['startH'] as int,
      slot['startM'] as int,
    );
    final slotEnd = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      slot['endH'] as int,
      slot['endM'] as int,
    );

    final matches = _reservations.where((r) {
      if (r['laundry_id'] != laundryId) return false;
      if (r['status'] == 'CANCELED') return false;
      final start = DateTime.parse(r['start_time']);
      final end = DateTime.parse(r['end_time']);
      return start.isBefore(slotEnd) && end.isAfter(slotStart);
    });
    return matches.isEmpty ? null : matches.first;
  }

  Map<String, dynamic>? _findFixedScheduleFor(
    int laundryId,
    Map<String, dynamic> slot,
  ) {
    final weekday = _selectedDate.weekday;
    final matches = _fixedSchedule.where(
      (f) =>
          f['laundry_id'] == laundryId &&
          f['weekday'] == weekday &&
          f['start_time'] ==
              '${_twoDigit(slot['startH'] as int)}:${_twoDigit(slot['startM'] as int)}:00',
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
        body: const Center(child: CircularProgressIndicator(color: _teal)),
      );
    }

    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMachineCard(int index, Map<String, dynamic> machine) {
    final running = _findRunningReservationFor(machine['id'] as int);
    final bool isOccupied = running != null;

    final Widget detailWidget = isOccupied
        ? Column(
            children: [
              Text(
                '${running['room_number']}호',
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
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xff3F3F46), width: 1),
      ),
      child: Column(
        children: [
          Text(
            '${index + 1}호',
            style: const TextStyle(
              color: _textColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Icon(
            Icons.local_laundry_service,
            size: 54,
            color: isOccupied ? _teal : Colors.white,
          ),
          const SizedBox(height: 21),
          detailWidget,
        ],
      ),
    );

    return isOccupied
        ? card
        : GestureDetector(onTap: () => _goToReservation(machine), child: card);
  }

  //시간표
  Widget _buildWeeklyScheduleTable() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () => _changeDay(-1),
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFF2A2A2E),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.chevron_left, color: _textColor),
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
              onTap: () => _changeDay(1),
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFF2A2A2E),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.chevron_right, color: _textColor),
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
              ..._weeklySlots.map((slot) => _buildScheduleRow(slot)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleRow(Map<String, dynamic> slot) {
    final startLabel =
        '${_twoDigit(slot['startH'] as int)}:${_twoDigit(slot['startM'] as int)}';
    final endLabel =
        '~${_twoDigit(slot['endH'] as int)}:${_twoDigit(slot['endM'] as int)}';

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

          ..._machines.map((machine) {
            final laundryId = machine['id'] as int;
            final fixed = _findFixedScheduleFor(laundryId, slot);
            final reservation = fixed == null
                ? _findReservationForSlot(laundryId, slot)
                : null;
            final String label = fixed != null
                ? '${fixed['room_number']}호'
                : (reservation != null
                      ? '${reservation['room_number']}호'
                      : '비어있음');
            final bool isFixed = fixed != null;
            final bool isFilled = fixed != null || reservation != null;

            return Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isFilled ? _textColor : _captionColor,
                  fontSize: 14,
                  fontWeight: isFilled ? FontWeight.w600 : FontWeight.w400,
                  fontStyle: isFixed ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
