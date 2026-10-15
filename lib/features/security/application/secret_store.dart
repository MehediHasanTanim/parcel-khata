import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:parcel_khata/core/platform/fresh_install_guard.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// Small key/value store for secrets (PIN hash, lock flags). Backed by the
/// Android Keystore / iOS Keychain; never included in backups.
abstract class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<void> deleteAll();
}

/// Keychain class: readable after the first unlock following a reboot (the
/// app lock and background digest keep working), and never restored to
/// another device from a backup.
const _kIosOptions = IOSOptions(
  accessibility: KeychainAccessibility.first_unlock_this_device,
);

class SecureSecretStore implements SecretStore {
  SecureSecretStore([FlutterSecureStorage? storage])
      : _s = storage ?? const FlutterSecureStorage(iOptions: _kIosOptions);

  final FlutterSecureStorage _s;
  FreshInstallGuard? _guard;

  /// Clears Keychain items left behind by a previous install (iOS only
  /// matters; harmless elsewhere). Created lazily to avoid touching the
  /// file system until a secret is actually used.
  Future<void> _fresh() async {
    final g = _guard ??= FreshInstallGuard(
      directory: Directory(
          (await PathProviderPlatform.instance.getApplicationSupportPath()) ??
              Directory.systemTemp.path),
      clearSecrets: _s.deleteAll,
    );
    await g.ensure();
  }

  @override
  Future<String?> read(String key) async {
    await _fresh();
    return _s.read(key: key);
  }

  @override
  Future<void> write(String key, String value) async {
    await _fresh();
    return _s.write(key: key, value: value);
  }

  @override
  Future<void> delete(String key) async {
    await _fresh();
    return _s.delete(key: key);
  }

  @override
  Future<void> deleteAll() => _s.deleteAll();
}

class MemorySecretStore implements SecretStore {
  final Map<String, String> _m = {};

  @override
  Future<String?> read(String key) async => _m[key];

  @override
  Future<void> write(String key, String value) async => _m[key] = value;

  @override
  Future<void> delete(String key) async => _m.remove(key);

  @override
  Future<void> deleteAll() async => _m.clear();
}

final secretStoreProvider = Provider<SecretStore>((ref) => SecureSecretStore());
