import 'package:flutter_test/flutter_test.dart';
import 'package:scrollguard/core/utils/clock.dart';

void main() {
  group('AppClock', () {
    test('SystemClock returns reasonable current time', () {
      const clock = SystemClock();
      final now = clock.now();
      expect(now.year, greaterThanOrEqualTo(2025));
      expect(clock.nowMillisecondsSinceEpoch(), greaterThan(0));
    });

    test('TestClock allows fixed time and manual advance', () {
      final baseTime = DateTime.utc(2026, 1, 15, 10);
      final clock = TestClock(baseTime);

      expect(clock.now(), equals(baseTime));
      expect(clock.nowMillisecondsSinceEpoch(), equals(baseTime.millisecondsSinceEpoch));

      clock.advance(const Duration(minutes: 5));
      expect(clock.now(), equals(baseTime.add(const Duration(minutes: 5))));

      final newTime = DateTime.utc(2026, 6);
      clock.currentTime = newTime;
      expect(clock.now(), equals(newTime));
    });
  });
}
