import 'dart:math';

import 'package:parcel_khata/core/time/clock.dart';

/// Generates time-ordered UUID v7 strings (monotonic within a millisecond).
class UuidV7 {
  UuidV7({Clock clock = const SystemClock(), Random? random})
      : _clock = clock,
        _random = random ?? Random.secure();

  final Clock _clock;
  final Random _random;
  int _lastMs = 0;
  int _seq = 0;

  String generate([DateTime? at]) {
    var ms = (at ?? _clock.now()).millisecondsSinceEpoch;
    if (ms <= _lastMs) {
      ms = _lastMs;
      _seq++;
    } else {
      _lastMs = ms;
      _seq = 0;
    }
    if (_seq > 0xFFF) {
      // Sequence overflow: move to the next millisecond.
      _lastMs = ++ms;
      _seq = 0;
    }
    final b = List<int>.generate(16, (_) => _random.nextInt(256));
    for (var i = 0; i < 6; i++) {
      b[i] = (ms >> (8 * (5 - i))) & 0xFF;
    }
    // version 7 + 12-bit sequence in rand_a keeps ordering within one ms.
    b[6] = 0x70 | ((_seq >> 8) & 0x0F);
    b[7] = _seq & 0xFF;
    b[8] = 0x80 | (b[8] & 0x3F);
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
        '${h.substring(16, 20)}-${h.substring(20)}';
  }
}
