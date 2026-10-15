import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:meta/meta.dart';

/// Salted PBKDF2-HMAC-SHA256 PIN hashing (implementation plan §10).
abstract final class PinHasher {
  static const iterations = 100000;

  static List<int> newSalt([Random? random]) {
    final r = random ?? Random.secure();
    return List<int>.generate(16, (_) => r.nextInt(256));
  }

  static Future<List<int>> hash(String pin, List<int> salt, {int rounds = iterations}) async {
    final kdf = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: rounds, bits: 256);
    final key = await kdf.deriveKeyFromPassword(password: pin, nonce: salt);
    return key.extractBytes();
  }

  /// Constant-time comparison so timing never reveals matching bytes.
  static bool constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  static Future<bool> verify(
    String pin,
    List<int> salt,
    List<int> expected, {
    int rounds = iterations,
  }) async =>
      constantTimeEquals(await hash(pin, salt, rounds: rounds), expected);

  /// 4-8 digits.
  static bool isValidPin(String pin) => RegExp(r'^\d{4,8}$').hasMatch(pin);

  static String hex(List<int> b) =>
      b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

  static Uint8List unhex(String s) => Uint8List.fromList([
        for (var i = 0; i < s.length; i += 2) int.parse(s.substring(i, i + 2), radix: 16),
      ]);
}

/// Failed-attempt tracking with growing lockouts: the first four wrong PINs
/// are free, then 30 s, 1 min, 5 min, 15 min, 1 h.
@immutable
class AttemptState {
  const AttemptState({this.failures = 0, this.lockedUntil});

  final int failures;
  final DateTime? lockedUntil;

  static const _steps = [
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(minutes: 15),
    Duration(hours: 1),
  ];
  static const freeAttempts = 4;

  bool isLocked(DateTime now) => lockedUntil != null && now.isBefore(lockedUntil!);

  Duration remaining(DateTime now) =>
      isLocked(now) ? lockedUntil!.difference(now) : Duration.zero;

  AttemptState failed(DateTime now) {
    final n = failures + 1;
    if (n <= freeAttempts) return AttemptState(failures: n);
    final step = _steps[min(n - freeAttempts - 1, _steps.length - 1)];
    return AttemptState(failures: n, lockedUntil: now.add(step));
  }

  AttemptState success() => const AttemptState();

  Map<String, Object?> toJson() => {
        'failures': failures,
        'lockedUntil': lockedUntil?.millisecondsSinceEpoch,
      };

  factory AttemptState.fromJson(Map<String, dynamic> j) => AttemptState(
        failures: j['failures'] as int? ?? 0,
        lockedUntil: j['lockedUntil'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(j['lockedUntil'] as int),
      );
}

abstract final class LockPolicy {
  /// Lock again when the app was in the background for [timeout] or longer.
  /// A zero timeout locks on every return.
  static bool shouldLock({
    required DateTime? backgroundedAt,
    required DateTime now,
    required Duration timeout,
  }) {
    if (backgroundedAt == null) return false;
    return now.difference(backgroundedAt) >= timeout;
  }
}
