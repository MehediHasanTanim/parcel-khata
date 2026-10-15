import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Small key/value store for secrets (PIN hash, lock flags). Backed by the
/// Android Keystore; never included in backups.
abstract class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<void> deleteAll();
}

class SecureSecretStore implements SecretStore {
  const SecureSecretStore([this._s = const FlutterSecureStorage()]);

  final FlutterSecureStorage _s;

  @override
  Future<String?> read(String key) => _s.read(key: key);

  @override
  Future<void> write(String key, String value) => _s.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _s.delete(key: key);

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

final secretStoreProvider = Provider<SecretStore>((ref) => const SecureSecretStore());
