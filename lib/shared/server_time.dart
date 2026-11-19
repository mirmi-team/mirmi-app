/// 서버가 내려준 시각 문자열을 기기 시간대로 바꿔준다.
///
/// 서버는 모든 시각에 타임존을 붙여 준다. `Date` 로 나가는 값은
/// `DateFormatInterceptor` 가, 문자열 컬럼은 `localDateTimeTransformer` 가
/// 각각 `+09:00` 을 붙인다. 그 표기가 있으면 그대로 믿는다.
///
/// 표기가 빠진 채로 오면 **한국시간**으로 읽는다. 서버 DB 가 한국시간
/// 벽시계를 그대로 담고 있어서, 표기가 없다면 그 값이기 때문이다.
///
/// 예전에는 이걸 UTC 로 읽어서 9시간이 밀렸다. (저녁 7시 40분에 찍은 복귀가
/// 새벽 4시 40분으로 보였다) 서버가 `+09:00` 을 붙이기 전의 값이나 아직
/// 고쳐지지 않은 필드가 섞여 와도 여기서 맞게 읽힌다.
DateTime? parseServerTime(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final trimmed = raw.trim();
  if (_hasTimeZone(trimmed)) return DateTime.tryParse(trimmed)?.toLocal();
  // 표기가 없으면 한국시간이라고 적어 넣고 읽는다. 9시간을 더하는 게 아니라
  // 빠진 단위를 채우는 것이라, 기기가 어느 시간대에 있든 같은 순간이 된다.
  return DateTime.tryParse('$trimmed+09:00')?.toLocal();
}

/// 날짜만 있는 문자열(`2026-09-22`)은 시각이 아니므로 타임존을 붙이면 안 된다.
/// 여기서는 시간까지 있는 경우만 본다.
final _zonePattern = RegExp(r'([Zz]|[+-]\d{2}:?\d{2})$');

bool _hasTimeZone(String raw) =>
    !raw.contains('T') || _zonePattern.hasMatch(raw);
