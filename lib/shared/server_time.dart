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
