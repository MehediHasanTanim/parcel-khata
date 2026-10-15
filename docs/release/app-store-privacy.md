# App Store "App Privacy" (nutrition label) answers

Mirror of `data-safety.md` (Play). Keep both and `privacy-policy.md` in sync.

## Today (local-only app)

| Question | Answer |
|---|---|
| Do you or your third-party partners collect data from this app? | **No** by default. Optional diagnostics only if the user opts in. |
| Data used to track you | None |
| If diagnostics opt-in is on | Diagnostics > Crash data, Performance data; Usage data > Product interaction (event names/counts/durations). Not linked to identity. Not used for tracking. |
| Contacts / location / photos | Not collected (photo library only when the user attaches a photo; stays on device) |
| Camera | On-device barcode scan only; images are not stored or sent |
| Face ID | Local authentication only; the app receives only success/failure |

## When optional features ship

| Feature | Label impact |
|---|---|
| Google Drive backup | Data goes to the user's own Drive, passphrase-encrypted before upload; not collected by us. State it in the policy. |
| Account + cloud sync (S16+) | Contact Info (phone number), User Content (orders, customers), Financial Info (payouts/COD amounts), Identifiers (device id). Linked to the user; not used for tracking. Update **before** enabling. |
| Helpers / activity log | Same as sync; roles are enforced server-side. |

## Required-reason API declarations
See `ios/Runner/PrivacyInfo.xcprivacy`: UserDefaults (CA92.1), file timestamps (C617.1, 3B52.1), disk
space (E174.1). Re-check when adding plugins: third-party SDKs must ship their own manifests.
