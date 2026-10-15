import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:parcel_khata/core/time/clock.dart';
import 'package:parcel_khata/core/time/providers.dart';
import 'package:parcel_khata/features/security/application/secret_store.dart';
import 'package:parcel_khata/features/security/domain/pin_security.dart';

enum LockPhase { disabled, locked, unlocked }

class LockStatus {
  const LockStatus({
    required this.phase,
    this.biometric = false,
    this.timeoutSeconds = 60,
    this.attempts = const AttemptState(),
    this.pinLength = 4,
  });

  final LockPhase phase;

  /// Length of the PIN (not secret); the lock screen auto-submits at this
  /// length so partial entries never count as failed attempts.
  final int pinLength;
  final bool biometric;
  final int timeoutSeconds;
  final AttemptState attempts;

  LockStatus copyWith({
    LockPhase? phase,
    bool? biometric,
    int? timeoutSeconds,
    AttemptState? attempts,
    int? pinLength,
  }) =>
      LockStatus(
        pinLength: pinLength ?? this.pinLength,
        phase: phase ?? this.phase,
        biometric: biometric ?? this.biometric,
        timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
        attempts: attempts ?? this.attempts,
      );
}

enum UnlockResult { ok, wrong, lockedOut }

/// PIN lock. State lives in the secure store so it survives restarts and is
/// not carried by backups (restoring a backup never removes the lock).
class AppLock extends AsyncNotifier<LockStatus> {
  static const _kHash = 'lock.pin_hash';
  static const _kSalt = 'lock.pin_salt';
  static const _kBio = 'lock.biometric';
  static const _kTimeout = 'lock.timeout';
  static const _kAttempts = 'lock.attempts';
  static const _kLen = 'lock.pin_len';

  DateTime? _backgroundedAt;

  SecretStore get _store => ref.read(secretStoreProvider);
  Clock get _clock => ref.read(clockProvider);

  @override
  Future<LockStatus> build() async {
    final hash = await _store.read(_kHash);
    final timeout = int.tryParse(await _store.read(_kTimeout) ?? '') ?? 60;
    final bio = (await _store.read(_kBio)) == '1';
    final raw = await _store.read(_kAttempts);
    final attempts = raw == null
        ? const AttemptState()
        : AttemptState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    return LockStatus(
      // A fresh launch of a locked app always starts locked.
      phase: hash == null ? LockPhase.disabled : LockPhase.locked,
      biometric: bio,
      timeoutSeconds: timeout,
      attempts: attempts,
      pinLength: int.tryParse(await _store.read(_kLen) ?? '') ?? 4,
    );
  }

  LockStatus get _s => state.requireValue;

  Future<void> setPin(String pin) async {
    if (!PinHasher.isValidPin(pin)) throw ArgumentError('invalid pin');
    final salt = PinHasher.newSalt();
    final hash = await PinHasher.hash(pin, salt);
    await _store.write(_kSalt, PinHasher.hex(salt));
    await _store.write(_kHash, PinHasher.hex(hash));
    await _store.write(_kLen, '${pin.length}');
    await _saveAttempts(const AttemptState());
    state = AsyncData(_s.copyWith(
      phase: LockPhase.unlocked,
      attempts: const AttemptState(),
      pinLength: pin.length,
    ));
  }

  Future<UnlockResult> verifyPin(String pin) async {
    final now = _clock.now();
    if (_s.attempts.isLocked(now)) return UnlockResult.lockedOut;
    final salt = await _store.read(_kSalt);
    final hash = await _store.read(_kHash);
    if (salt == null || hash == null) return UnlockResult.ok;
    final ok = await PinHasher.verify(pin, PinHasher.unhex(salt), PinHasher.unhex(hash));
    if (ok) {
      await _saveAttempts(const AttemptState());
      state = AsyncData(_s.copyWith(attempts: const AttemptState()));
      return UnlockResult.ok;
    }
    final next = _s.attempts.failed(now);
    await _saveAttempts(next);
    state = AsyncData(_s.copyWith(attempts: next));
    return next.isLocked(now) ? UnlockResult.lockedOut : UnlockResult.wrong;
  }

  Future<UnlockResult> unlock(String pin) async {
    final r = await verifyPin(pin);
    if (r == UnlockResult.ok) state = AsyncData(_s.copyWith(phase: LockPhase.unlocked));
    return r;
  }

  Future<bool> unlockWithBiometric(String reason) async {
    if (!_s.biometric) return false;
    try {
      final ok = await LocalAuthentication().authenticate(
        localizedReason: reason,
        biometricOnly: true,
      );
      if (ok) state = AsyncData(_s.copyWith(phase: LockPhase.unlocked));
      return ok;
    } on Object {
      return false;
    }
  }

  Future<bool> biometricAvailable() async {
    try {
      final a = LocalAuthentication();
      return await a.isDeviceSupported() && (await a.getAvailableBiometrics()).isNotEmpty;
    } on Object {
      return false;
    }
  }

  /// Turning the lock off requires the current PIN.
  Future<bool> disable(String pin) async {
    if (await verifyPin(pin) != UnlockResult.ok) return false;
    await _store.delete(_kHash);
    await _store.delete(_kSalt);
    await _store.delete(_kBio);
    state = AsyncData(_s.copyWith(phase: LockPhase.disabled, biometric: false));
    return true;
  }

  Future<void> setBiometric({required bool enabled}) async {
    await _store.write(_kBio, enabled ? '1' : '0');
    state = AsyncData(_s.copyWith(biometric: enabled));
  }

  Future<void> setTimeout(int seconds) async {
    await _store.write(_kTimeout, '$seconds');
    state = AsyncData(_s.copyWith(timeoutSeconds: seconds));
  }

  void lock() {
    if (_s.phase == LockPhase.unlocked) state = AsyncData(_s.copyWith(phase: LockPhase.locked));
  }

  void onBackgrounded() => _backgroundedAt ??= _clock.now();

  void onResumed() {
    final at = _backgroundedAt;
    _backgroundedAt = null;
    if (_s.phase != LockPhase.unlocked) return;
    if (LockPolicy.shouldLock(
      backgroundedAt: at,
      now: _clock.now(),
      timeout: Duration(seconds: _s.timeoutSeconds),
    )) {
      lock();
    }
  }

  Future<void> _saveAttempts(AttemptState a) =>
      _store.write(_kAttempts, jsonEncode(a.toJson()));
}

final appLockProvider = AsyncNotifierProvider<AppLock, LockStatus>(AppLock.new);
