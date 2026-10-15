# Release guide

## One-time setup
1. Create an upload keystore (keep it out of git):
   `keytool -genkey -v -keystore ~/pk-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
2. Create `android/key.properties` (git-ignored):
   ```
   storeFile=/absolute/path/pk-upload.jks
   storePassword=...
   keyAlias=upload
   keyPassword=...
   ```
3. Enable **Play App Signing** in the Play Console and upload the AAB signed with the upload key.
4. Application id is `com.parcelkhata.parcel_khata` (change before first upload if you want a different id: it cannot change later).

## Versioning
`pubspec.yaml` `version: MAJOR.MINOR.PATCH+BUILD`. Bump BUILD on every upload. CI passes
`--build-number $GITHUB_RUN_NUMBER`. Changelog comes from conventional commits.

## Build
```
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n
flutter test
flutter build appbundle --release --build-number <n>
```

## Tracks and staged rollout
Internal testing -> Closed beta (5-10 sellers, see beta-checklist.md) -> Production
**10% -> 50% -> 100%**, waiting at least 48 h and checking the monitoring list between steps.

## Monitoring checklist (each step)
- Crash-free sessions >= 99% (Play Console vitals; opt-in reports only).
- No new P0/P1 in the support inbox.
- "Backup created" and "payout reconciled" events not collapsing vs the previous version.
- Startup time and ANR rate not regressing in Android vitals.

## Rollback
1. Halt the rollout in Play Console.
2. Promote the previous AAB (same signing key) as a new release with a higher build number
   (Play never lets you downgrade versionCode).
3. Data is forward-only: the app refuses to open a *newer* backup, and each release ships migration
   tests; a rollback build must be built from the last tag that already contains the DB schema in use.
   If the schema changed, ship a **fix-forward** instead of a rollback.

## Data safety / compliance
See `data-safety.md` and `privacy-policy.md`.
