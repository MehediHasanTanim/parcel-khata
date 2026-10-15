# Google Play "Data safety" answers

| Question | Answer |
|---|---|
| Does the app collect or share user data? | **No** by default. Optional anonymous diagnostics only if the user opts in. |
| Data collected (if opted in) | App activity: in-app events (names/counts/durations). Diagnostics: crash logs with personal data scrubbed. |
| Is data shared with third parties? | No |
| Is all data encrypted in transit? | Not applicable: nothing is transmitted except opt-in diagnostics (HTTPS) |
| Can users request data deletion? | Yes: Settings > Security & privacy > Erase all data; uninstall |
| Is the data processed ephemerally? | Diagnostics are not tied to an identity |
| Sensitive permissions | POST_NOTIFICATIONS (optional digest), USE_BIOMETRIC (optional unlock) |
| Account required | No |
| Ads | None |
| Target audience | Adults / small business owners |

Keep this file in sync with `privacy-policy.md` and the manifest permissions on every release.
