class AppClock {
  static const Duration debugOffset = Duration(
    hours: 0,
  ); // hours 숫자 조정해서 임의로 시간 지정
  static DateTime now() => DateTime.now().add(debugOffset);
}
