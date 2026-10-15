# Parcel Khata (F-Commerce Order & COD Tracker)

Read `docs/feature`, `docs/plan`, `docs/design` (sprint plan) before working. Work follows the sprint plan task IDs (S0-xx ...).

## Rules
- Domain layer (`lib/**/domain/`, `lib/core/money|time|ids|result`) is pure Dart: no Flutter/Drift imports.
- Money is integer poisha via `Money`. No floats.
- Every mutation runs in ONE DB transaction via a use case and writes audit/timeline rows.
- Never call `DateTime.now()`; use the injected `Clock`.
- All user strings in `lib/l10n/app_en.arb` and `app_bn.arb` (keys must match; `test/l10n_test.dart`).
- Bug fix = failing test first. Soft delete only; financial corrections are reversals.
- Schema changes: add a new migration step + migration test; never edit a shipped step.

## Commands
- `dart run build_runner build --delete-conflicting-outputs` (Drift)
- `flutter gen-l10n`, `flutter analyze`, `flutter test`
- Host tests need Xcode command line tools (sqlite3 native build hook).
