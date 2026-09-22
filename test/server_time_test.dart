import 'package:flutter_test/flutter_test.dart';
import 'package:mirmi_app/shared/server_time.dart';

void main() {
  test('타임존 표기가 없으면 UTC 로 읽는다', () {
    final t = parseServerTime('2026-09-22T04:39:00')!;
    expect(t.toUtc().hour, 4);
  });
  test('Z 가 붙으면 그대로 믿는다', () {
    final t = parseServerTime('2026-09-22T04:39:00.000Z')!;
    expect(t.toUtc().hour, 4);
  });
  test('+09:00 오프셋도 그대로 믿는다', () {
    final t = parseServerTime('2026-09-22T13:39:00+09:00')!;
    expect(t.toUtc().hour, 4);
  });
  test('날짜만 있으면 그대로 둔다', () {
    final t = parseServerTime('2026-09-22')!;
    expect(t.day, 22);
  });
}
