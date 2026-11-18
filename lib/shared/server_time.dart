/// 서버가 내려준 시각 문자열을 기기 시간대로 바꿔준다.
///
/// Postgres 컬럼이 `timestamp`(타임존 없음)면 `2026-09-22T04:39:00` 처럼
/// 끝에 `Z` 도 `+09:00` 도 없이 내려온다. 이걸 `DateTime.parse` 에 그대로
/// 넣으면 Dart 는 **기기 로컬 시간**으로 읽어버린다. 서버는 UTC 로 저장하므로
/// 한국에서는 9시간이 어긋나 오후 1시 39분이 오전 4시 39분으로 보인다.
///
/// 타임존 표기가 있으면(`Z` 또는 `+09:00`) 그 값을 믿고, 없을 때만 UTC 로
/// 간주한다. 그래서 `timestamptz` 컬럼에 대해서는 동작이 달라지지 않는다.
DateTime? parseServerTime(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return null;
  if (_hasTimeZone(raw)) return parsed.toLocal();
  return DateTime.utc(
    parsed.year,
    parsed.month,
    parsed.day,
    parsed.hour,
    parsed.minute,
    parsed.second,
    parsed.millisecond,
    parsed.microsecond,
  ).toLocal();
}

/// 날짜만 있는 문자열(`2026-09-22`)은 시각이 아니므로 타임존이 없어도
/// 변환하면 안 된다. 여기서는 시간까지 있는 경우만 본다.
final _zonePattern = RegExp(r'([Zz]|[+-]\d{2}:?\d{2})$');

bool _hasTimeZone(String raw) =>
    !raw.contains('T') || _zonePattern.hasMatch(raw.trim());

/// 서버가 타임존 없이 내려주는 **한국시간** 문자열을 읽는다.
///
/// 대부분의 시각은 UTC 벽시계로 와서 [parseServerTime] 이 맞지만, 일부
/// 컬럼은 한국시간 벽시계를 그대로 담아 보낸다. 그걸 UTC 로 읽으면 9시간이
/// 밀린다. (저녁 7시 40분에 찍은 복귀가 새벽 4시 40분으로 보였다)
///
/// 어느 쪽인지는 문자열만 봐서는 알 수 없다. 그래서 필드마다 골라 써야 한다.
/// 서버가 나중에 `+09:00` 을 붙여 주면 그때는 이 함수도 그 값을 그대로 믿는다.
DateTime? parseKstTime(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  // 타임존이 붙어 있으면 추측할 이유가 없다.
  if (_hasTimeZone(raw)) return parseServerTime(raw);
  return DateTime.tryParse('${raw.trim()}+09:00')?.toLocal();
}
