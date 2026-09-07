// lib/core/constants/laundry_time_slots.dart
class LaundryTimeSlot {
  const LaundryTimeSlot({
    required this.startH,
    required this.startM,
    required this.endH,
    required this.endM,
  });

  final int startH;
  final int startM;
  final int endH;
  final int endM;

  static String _twoDigit(int n) => n.toString().padLeft(2, '0');

  String get label =>
      '${_twoDigit(startH)}:${_twoDigit(startM)}~${_twoDigit(endH)}:${_twoDigit(endM)}';

  DateTime startOn(DateTime day) =>
      DateTime(day.year, day.month, day.day, startH, startM);

  DateTime endOn(DateTime day) =>
      DateTime(day.year, day.month, day.day, endH, endM);
}

const List<LaundryTimeSlot> laundryTimeSlots = [
  LaundryTimeSlot(startH: 16, startM: 30, endH: 18, endM: 40),
  LaundryTimeSlot(startH: 19, startM: 10, endH: 20, endM: 20),
  LaundryTimeSlot(startH: 20, startM: 20, endH: 21, endM: 10),
  LaundryTimeSlot(startH: 21, startM: 10, endH: 22, endM: 30),
];
