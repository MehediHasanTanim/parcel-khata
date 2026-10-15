import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_khata/core/ids/uuid_v7.dart';
import 'package:parcel_khata/core/result/result.dart';
import 'package:parcel_khata/core/time/clock.dart';

void main() {
  test('FakeClock advances deterministically', () {
    final c = FakeClock(DateTime.utc(2026, 10, 1));
    c.advance(const Duration(days: 3));
    expect(c.now(), DateTime.utc(2026, 10, 4));
  });

  group('UuidV7', () {
    test('format and version bits', () {
      final id = UuidV7(clock: FakeClock(DateTime.utc(2026))).generate();
      expect(
        id,
        matches(RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')),
      );
    });
    test('monotonic even within one millisecond', () {
      final gen = UuidV7(clock: FakeClock(DateTime.utc(2026)));
      final ids = List.generate(5000, (_) => gen.generate());
      final sorted = [...ids]..sort();
      expect(ids, sorted);
      expect(ids.toSet().length, ids.length);
    });
    test('ordered across time', () {
      final clock = FakeClock(DateTime.utc(2026));
      final gen = UuidV7(clock: clock);
      final a = gen.generate();
      clock.advance(const Duration(seconds: 1));
      expect(gen.generate().compareTo(a), greaterThan(0));
    });
  });

  group('Result', () {
    test('ok / err', () {
      const r = Result<int>.ok(3);
      expect(r.valueOrNull, 3);
      const e = Result<int>.err(ValidationFailure('x'));
      expect(e.isOk, isFalse);
      expect(e.when(ok: (_) => 'ok', err: (f) => f.message), 'x');
    });
  });
}
