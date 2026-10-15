import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_khata/features/security/domain/pin_security.dart';
import 'package:parcel_khata/features/telemetry/domain/privacy.dart';
import 'package:parcel_khata/features/telemetry/domain/telemetry.dart';

void main() {
  group('PIN hashing', () {
    test('verifies the right PIN and rejects others', () async {
      final salt = PinHasher.newSalt(Random(1));
      final h = await PinHasher.hash('4821', salt, rounds: 1000);
      expect(h, hasLength(32));
      expect(await PinHasher.verify('4821', salt, h, rounds: 1000), isTrue);
      expect(await PinHasher.verify('4822', salt, h, rounds: 1000), isFalse);
    });

    test('salt changes the hash; same salt is deterministic', () async {
      final a = await PinHasher.hash('1234', [1, 2, 3], rounds: 500);
      final b = await PinHasher.hash('1234', [1, 2, 4], rounds: 500);
      final c = await PinHasher.hash('1234', [1, 2, 3], rounds: 500);
      expect(a, isNot(b));
      expect(a, c);
    });

    test('constant time compare and length mismatch', () {
      expect(PinHasher.constantTimeEquals([1, 2], [1, 2]), isTrue);
      expect(PinHasher.constantTimeEquals([1, 2], [1, 3]), isFalse);
      expect(PinHasher.constantTimeEquals([1], [1, 2]), isFalse);
    });

    test('PIN shape', () {
      expect(PinHasher.isValidPin('1234'), isTrue);
      expect(PinHasher.isValidPin('12345678'), isTrue);
      expect(PinHasher.isValidPin('123'), isFalse);
      expect(PinHasher.isValidPin('123456789'), isFalse);
      expect(PinHasher.isValidPin('12a4'), isFalse);
    });

    test('hex round trip', () {
      final bytes = [0, 15, 16, 255];
      expect(PinHasher.unhex(PinHasher.hex(bytes)), bytes);
    });
  });

  group('failed-attempt backoff', () {
    final now = DateTime(2026, 10, 15, 12);

    test('first four failures are free, then escalating lockouts', () {
      var s = const AttemptState();
      for (var i = 0; i < 4; i++) {
        s = s.failed(now);
        expect(s.isLocked(now), isFalse, reason: 'attempt ${i + 1}');
      }
      s = s.failed(now);
      expect(s.isLocked(now), isTrue);
      expect(s.remaining(now), const Duration(seconds: 30));
      s = s.failed(now);
      expect(s.remaining(now), const Duration(minutes: 1));
      s = s.failed(now);
      expect(s.remaining(now), const Duration(minutes: 5));
      s = s.failed(now);
      expect(s.remaining(now), const Duration(minutes: 15));
      s = s.failed(now);
      expect(s.remaining(now), const Duration(hours: 1));
      s = s.failed(now);
      expect(s.remaining(now), const Duration(hours: 1)); // capped
    });

    test('lock expires and success resets', () {
      var s = const AttemptState();
      for (var i = 0; i < 5; i++) {
        s = s.failed(now);
      }
      expect(s.isLocked(now.add(const Duration(seconds: 29))), isTrue);
      expect(s.isLocked(now.add(const Duration(seconds: 30))), isFalse);
      expect(s.success().failures, 0);
    });

    test('persists through json', () {
      final s = const AttemptState(failures: 6).failed(now);
      final back = AttemptState.fromJson(s.toJson());
      expect(back.failures, s.failures);
      expect(back.lockedUntil!.millisecondsSinceEpoch, s.lockedUntil!.millisecondsSinceEpoch);
    });
  });

  group('lock timeout', () {
    final now = DateTime(2026, 10, 15, 12);
    test('locks only after the background timeout', () {
      const t = Duration(minutes: 1);
      expect(LockPolicy.shouldLock(backgroundedAt: null, now: now, timeout: t), isFalse);
      expect(
          LockPolicy.shouldLock(
              backgroundedAt: now.subtract(const Duration(seconds: 59)), now: now, timeout: t),
          isFalse);
      expect(
          LockPolicy.shouldLock(
              backgroundedAt: now.subtract(const Duration(seconds: 60)), now: now, timeout: t),
          isTrue);
      expect(
          LockPolicy.shouldLock(backgroundedAt: now, now: now, timeout: Duration.zero),
          isTrue);
    });
  });

  group('PII scrubbing', () {
    test('removes phones, numbers, emails and links', () {
      final s = PiiScrubber.scrub(
        'Failed for 01712345678 / +8801812-345678 mail a.b@x.com see https://x.com/t/AB123 id 12345678',
      );
      expect(s, isNot(contains('0171')));
      expect(s, isNot(contains('1812')));
      expect(s, isNot(contains('a.b@x.com')));
      expect(s, isNot(contains('https')));
      expect(s, isNot(contains('12345678')));
      expect(s, contains('[phone]'));
    });

    test('keeps ordinary text', () {
      expect(PiiScrubber.scrub('Null check operator used on a null value'),
          'Null check operator used on a null value');
    });

    test('bangla digit runs are scrubbed', () {
      expect(PiiScrubber.scrub('নম্বর ০১৭১২৩৪৫৬৭৮'), isNot(contains('০১৭১২৩')));
    });
  });

  group('telemetry consent', () {
    final now = DateTime(2026, 10, 15);

    test('nothing is recorded without consent', () {
      final sink = BufferedSink();
      var consent = false;
      final t = Telemetry(sink, hasConsent: () => consent, now: () => now);
      t.event('order_created', {'ms': 1200});
      t.error('boom 01712345678', null);
      expect(sink.events, isEmpty);
      expect(sink.errors, isEmpty);
      consent = true;
      t.event('order_created', {'ms': 1200});
      expect(sink.events, hasLength(1));
    });

    test('unknown events and non-whitelisted params are dropped', () {
      final sink = BufferedSink();
      final t = Telemetry(sink, hasConsent: () => true, now: () => now);
      t.event('customer_viewed', {'ms': 1});
      t.event('order_created', {
        'ms': 900,
        'customer_name': 'Rahim',
        'phone': '01712345678',
        'kind': 'cod',
        'amount': 1060,
      });
      expect(sink.events, hasLength(1));
      expect(sink.events.single.params, {'ms': 900, 'kind': 'cod'});
    });

    test('errors are scrubbed and the buffer is bounded', () {
      final sink = BufferedSink(capacity: 3);
      final t = Telemetry(sink, hasConsent: () => true, now: () => now);
      t.error('failed for 01712345678', StackTrace.fromString('at x 01898765432'));
      expect(sink.errors.single, isNot(contains('0171')));
      expect(sink.errors.single, isNot(contains('0189')));
      for (var i = 0; i < 10; i++) {
        t.event('app_open');
      }
      expect(sink.events, hasLength(3));
    });
  });
}
