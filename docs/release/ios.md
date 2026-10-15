# iOS (S21): status, differences, release steps

**Status: configured, not built.** This machine has Command Line Tools only (no full Xcode), so
`flutter build ios` has not been run and nothing here has executed on an iPhone. Everything below is
written to be verified by the CI macOS job and then on a real device. Treat unchecked boxes as open.

## 1. What changed for iOS

| Area | Change | Where |
|---|---|---|
| Plugin registration | `path_provider_foundation` added (the app only listed the Android implementation) | `pubspec.yaml` |
| Privacy strings | Face ID, camera, photo library; `LSApplicationQueriesSchemes`: `whatsapp`, `tel`, `sms`; `CFBundleLocalizations` en/bn | `ios/Runner/Info.plist` |
| Entitlements | default data protection `...CompleteUntilFirstUserAuthentication` (DB readable after first unlock, so the digest and background work keep functioning) | `ios/Runner/Runner.entitlements`, referenced by all 3 Runner build configs |
| Privacy manifest | `PrivacyInfo.xcprivacy`: no tracking, no collected data, required-reason APIs (UserDefaults, file timestamp, disk space) | `ios/Runner/PrivacyInfo.xcprivacy`, added to the Resources phase |
| Notifications | Darwin init (no prompt at launch), explicit permission request from Settings, foreground presentation, `UNUserNotificationCenter` delegate | `digest_service.dart`, `AppDelegate.swift` |
| Battery guide | Shown on Android only (no iOS equivalent) | `notification_settings_screen.dart` |
| Backups | No `allowBackup`: database (+WAL/SHM) and `attachments/` are flagged `NSURLIsExcludedFromBackupKey` at startup through a native channel; the only cloud copy is the encrypted `.pkb` the user exports | `backup_exclusion.dart`, `AppDelegate.swift`, `main.dart` |
| Keychain | accessibility `first_unlock_this_device` (lock works after reboot + first unlock; not restored to other devices); stale items from a previous install are cleared once via a marker file | `secret_store.dart`, `fresh_install_guard.dart` |
| Share sheet / PDF | iPad popover anchor passed to `share_plus` and `Printing.sharePdf` (omitting it crashes on iPad) | `share_origin.dart` |
| Background Drive backup | Android WorkManager only; on iOS Drive backup is manual (and could run on app open if due) | `drive_scheduler.dart` |
| CI | macOS job: analyze, platform/widget tests, `flutter build ipa --no-codesign` | `.github/workflows/ci.yml` |

## 2. Known gaps (decide / build before TestFlight)

1. **Never compiled for iOS.** First CI run will likely surface pod/Swift issues. In particular
   `AppDelegate.swift` uses `engineBridge.applicationRegistrar.messenger()` (implicit-engine template);
   confirm it against the installed Flutter version.
2. **Share target (WhatsApp -> Paste order) does not exist on iOS.** It needs a Share Extension target
   (Xcode, App Group) which cannot be created from files here. Users paste instead.
3. **Google Drive sign-in** needs an iOS OAuth client: `GIDClientID` and the reversed-client-id URL
   scheme in `Info.plist` (values only you have). Until then keep Drive backup hidden on iOS.
4. **Barcode scan** uses Apple Vision on iOS (no MLKit): test Code128/QR from courier labels on a device.
5. **sqlite3 native build hook** compiles SQLite for iOS with Xcode's toolchain: verify the first build.
6. **Export compliance**: the app implements AES-GCM + PBKDF2 for backups. Answer the App Store
   Connect encryption questions deliberately (do not set `ITSAppUsesNonExemptEncryption` blindly).
7. **App icons / launch screen** for iOS are still the Flutter defaults; supply the asset catalog.
8. **Golden tests** do not exist yet, so "run on both platforms" is not applicable; add them first.
9. **Bangla fonts**: PDFs use the bundled font; verify shaping of conjuncts in the share sheet preview.
10. **Notification timing**: the digest is a one-shot scheduled each time the app refreshes (same as
    Android); a repeating `DateTimeComponents.time` schedule would survive weeks without opening the app.

## 3. Device verification checklist (exit criteria)

- [ ] `flutter build ipa --no-codesign` green in CI
- [ ] `integration_test/` suite passes on a real iPhone
- [ ] performance test (20k orders) within budgets; record in `performance-profiling.md`
- [ ] Face ID unlock, PIN survives reboot (after first unlock), fresh install after uninstall asks for
      a new PIN (Keychain cleared)
- [ ] Digest permission prompt appears only when enabled in Settings; notification fires; no battery
      dialog
- [ ] Airplane-mode: scan, create order, export `.pkb`, restore from Files
- [ ] iCloud backup of the device does not contain the database (Settings > Storage > Backups)
- [ ] iPad: share sheets do not crash
- [ ] `grep -rn "Platform.isAndroid"` shows only intentional Android-only branches

## 4. Distribution

1. Apple Developer Program enrolment (organisation or individual), App ID `com.parcelkhata.parcelKhata`.
2. App Store Connect record; fill **App Privacy** from `app-store-privacy.md`.
3. `flutter build ipa` with a distribution profile, upload with Transporter or `xcrun altool`.
4. TestFlight internal group (same 5 to 10 sellers), then external review.
5. Keep `privacy-policy.md`, `data-safety.md` (Play) and `app-store-privacy.md` in sync every release.
