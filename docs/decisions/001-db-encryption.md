# 001: DB encryption (S0-16 spike) — PENDING

Status: not yet measured. Requires a physical low-end Android device.

Compare plain SQLite (`sqlite3_flutter_libs`) vs SQLCipher (`sqlcipher_flutter_libs`): open time, insert 20k rows, list query.
Decision rule (implementation plan §11): encrypted-by-default only if overhead is acceptable; otherwise opt-in (S8-03).
