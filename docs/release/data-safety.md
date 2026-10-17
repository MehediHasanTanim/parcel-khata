# Google Play "Data safety" answers

| Question | Answer |
|---|---|
| Does the app collect or share user data? | **No** by default. Optional anonymous diagnostics only if the user opts in. |
| Data collected (if opted in) | App activity: in-app events (names/counts/durations). Diagnostics: crash logs with personal data scrubbed. |
| Data shared with Google (AdMob) | Device or other IDs (advertising ID), App interactions (ad events), Diagnostics; not linked to business data; purpose: advertising. Never customer, order or financial data |
| Is data shared with third parties? | No. The optional Drive backup is a user-initiated transfer to the user's own Google Drive (`drive.appdata` scope, passphrase-encrypted before upload) |
| Is all data encrypted in transit? | Not applicable: nothing is transmitted except opt-in diagnostics (HTTPS) |
| Can users request data deletion? | Yes: Settings > Security & privacy > Erase all data; uninstall |
| Is the data processed ephemerally? | Diagnostics are not tied to an identity |
| Sensitive permissions | POST_NOTIFICATIONS (optional digest), USE_BIOMETRIC (optional unlock), CAMERA (optional barcode scan; on-device only, camera hardware not required) |
| Account required | No (Google sign-in only if the user enables Drive backup) |
| Account required | No |
| Ads | **Yes** (Google AdMob banners in the free version; ads removable by purchase once implemented) |
| Advertising ID | Used by the AdMob SDK for ads (non-personalised); declare in Play Console. `AD_ID` permission comes from the SDK |
| Target audience | Adults / small business owners |

Keep this file in sync with `privacy-policy.md` and the manifest permissions on every release.
