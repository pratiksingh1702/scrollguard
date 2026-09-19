/// Injectable clock abstraction for deterministic testing of time-dependent logic.
abstract interface class AppClock {
  DateTime now();
  int nowMillisecondsSinceEpoch();
}

/// Production system clock using real device time.
class SystemClock implements AppClock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();

  @override
  int nowMillisecondsSinceEpoch() => DateTime.now().millisecondsSinceEpoch;
}

/// Test clock that allows fixing and advancing time deterministically.
class TestClock implements AppClock {
  TestClock([DateTime? initialTime])
      : currentTime = initialTime ?? DateTime.utc(2026);

  DateTime currentTime;

  @override
  DateTime now() => currentTime;

  @override
  int nowMillisecondsSinceEpoch() => currentTime.millisecondsSinceEpoch;

  void advance(Duration duration) {
    currentTime = currentTime.add(duration);
  }
}
