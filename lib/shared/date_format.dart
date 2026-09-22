/// 날짜·시각을 문자열로 바꾸는 공통 함수.
///
/// 화면마다 `padLeft(2, '0')` 을 직접 붙이면 표기가 조금씩 갈린다.
/// 서버에 보내는 키와 화면에 보여주는 라벨을 여기 모아 둔다.
library;

/// 한 자리 수를 '01' 처럼 두 자리로.
String twoDigit(int n) => n.toString().padLeft(2, '0');

/// '2026-09-22' — 서버에 날짜를 보내거나 날짜별로 묶을 때 쓰는 키.
String dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${twoDigit(date.month)}-${twoDigit(date.day)}';

/// '2026-09' — 월별로 묶을 때 쓰는 키.
String monthKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${twoDigit(date.month)}';

/// '09.22' — 좁은 자리에 쓰는 짧은 날짜.
String shortDateLabel(DateTime date) =>
    '${twoDigit(date.month)}.${twoDigit(date.day)}';

/// '오후 6:03' — 화면에 보여주는 시각.
String clockLabel(DateTime at) {
  final isAm = at.hour < 12;
  final hour12 = at.hour % 12 == 0 ? 12 : at.hour % 12;
  return '${isAm ? '오전' : '오후'} $hour12:${twoDigit(at.minute)}';
}

/// '05:00' — 24시간제 시:분.
String timeLabel(DateTime at) => '${twoDigit(at.hour)}:${twoDigit(at.minute)}';

/// 같은 날인지. 시·분은 보지 않는다.
bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
