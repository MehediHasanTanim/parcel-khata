# 001: Database encryption

**Status:** decided for v1.0 (provisional on the device spike below)

## Context
Implementation plan §2/§11 left encryption on/off to a Sprint 0 spike on a low-end Android device.
That device measurement has **not** been run (no device access during development). Everything else
in the threat model is covered without it.

## Decision for v1.0
- The SQLite file is **plain** (`sqlite3_flutter_libs`), stored in app-private storage.
  Android already encrypts app-private storage at rest on every device with a lock screen (FBE, Android 10+).
- Protection that ships in v1.0: PIN/biometric app lock (salted PBKDF2), screens hidden in recents,
  `allowBackup=false` + data-extraction rules (no cloud/device-transfer copies), optional
  passphrase-encrypted backup files (AES-256-GCM), "Erase all data".
- SQLCipher is **not** enabled. Swapping `sqlite3_flutter_libs` for `sqlcipher_flutter_libs` changes the
  native build and needs a plain->encrypted migration; doing that blind would risk data loss.

## Revisit when
1. Run the spike (open time, insert 20k rows, list query, dashboard) plain vs SQLCipher on a low-end device.
2. If overhead is under ~15% on the 20k dataset, ship SQLCipher **opt-in** in v1.1 with this migration path:
   `PRAGMA key` via `sqlcipher_export` into a new file, verify counts, swap, keep `.pre_encrypt` copy.
3. Key storage: Android Keystore via `flutter_secure_storage` (already used for the lock).

## Consequences
A rooted device or a forensic image of an unlocked phone can read the database. The backup file is the
only encrypted-at-rest artifact. This is documented in the privacy policy.
