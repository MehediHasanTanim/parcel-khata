# Bangla review checklist (native speaker)

Automated guards already run in CI (`test/l10n_parity_test.dart`): same keys in `bn`/`en`, identical
placeholders, no value left in English.

A human reviewer must still check, in `lib/l10n/app_bn.arb` and on device:
- Tone: consistent "আপনি" form, natural for small-shop sellers (not textbook Bangla).
- Courier/commerce terms: COD, CN, "রিটার্ন", "পেআউট" readable or better local words.
- Numerals: UI uses Western digits by default; confirm preference (setting exists in `Money.format`).
- Truncation at 200% font and 360 px width on: Home tiles, order form totals, payout flow, filters sheet.
- Mixed-script addresses (Bangla + English) in search and PDF output (courier statement, order slip).
- Plurals: counts such as "{n}টি অর্ডার" read correctly for 0/1/many.
- Notification digest sentence reads naturally when several parts are joined.

Record changes as a PR against `app_bn.arb`; do not edit generated `app_localizations_*.dart`.
