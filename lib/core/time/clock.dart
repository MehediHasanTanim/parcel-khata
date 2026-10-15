/// Injectable time source. Nothing else in the app may call `DateTime.now()`.
abstract class Clock {
  DateTime now();
}

class SystemClock implements Clock {
  const SystemClock();
  @override
  // ignore: avoid_dart_core_time_now
  DateTime now() => DateTime.now();
}

class FakeClock implements Clock {
  FakeClock(this._now);
  DateTime _now;

  @override
  DateTime now() => _now;

  void advance(Duration d) => _now = _now.add(d);
  void set(DateTime t) => _now = t;
}
