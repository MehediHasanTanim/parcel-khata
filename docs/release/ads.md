# AdMob (banner ads)

Implements `docs/plan/admob-integration-plan.md` with **option B (free with ads) chosen provisionally**.
Record the final decision in an ADR before shipping (open: price of "remove ads", ads for helpers).

## Safe by default
A build only requests ads with `--dart-define=ADS=1`. Without it (debug, tests, CI, normal
`flutter run`) the no-op service is used and the SDK is never initialised. Even with `ADS=1`, the
ad unit ids and AdMob app ids default to **Google's test ids** unless real ones are passed.

## Accounts created (AdMob console, 2026-10-17)
Publisher `pub-3379896207398236`.

| Platform | App | AdMob app id | Banner unit (`banner_footer`) |
|---|---|---|---|
| Android | Parcel Khata | `ca-app-pub-3379896207398236~5904576050` | `ca-app-pub-3379896207398236/5100042108` |
| iOS | Parcel Khata | `ca-app-pub-3379896207398236~5451570900` | `ca-app-pub-3379896207398236/2473878760` |

Both apps are **"Requires review"** and "not listed on a store" until you publish and link store
listings in AdMob (App settings > App store details). New units can take up to an hour to serve. These
ids are public identifiers, not secrets.

## Build commands
Android release (also wired in `.github/workflows/release.yml`):
```
ORG_GRADLE_PROJECT_ADMOB_APP_ID=ca-app-pub-3379896207398236~5904576050 \
flutter build appbundle --release --dart-define=ADS=1 \
  --dart-define=ADMOB_BANNER_ANDROID=ca-app-pub-3379896207398236/5100042108
```
iOS release:
```
flutter build ipa --dart-define=ADS=1 \
  --dart-define=ADMOB_BANNER_IOS=ca-app-pub-3379896207398236/2473878760
# and set ADMOB_APP_ID=ca-app-pub-3379896207398236~5451570900 (ios/Flutter/Release.xcconfig or CI)
```
Test on a device with real ids only after registering the device as an AdMob test device; never click
your own ads.

## What ships
Anchored 320x50 banners on: Orders list (not customer-scoped lists), Reports index, More. Nothing on
the lock screen, onboarding, order/customer forms or detail, COD/payouts, backup/import/export,
settings, security. Requests are non-personalised and carry no targeting data. Enforced by
`test/ads/ads_policy_test.dart` (source scan + privacy checks).

## Done in the consoles (2026-10-17)
- Privacy policy hosted (public GitHub Pages, repo `MehediHasanTanim/parcel-khata-privacy`):
  https://mehedihasantanim.github.io/parcel-khata-privacy/ (source: `site/privacy.md`; keep in sync).
- That URL is set on both Parcel Khata apps in AdMob.
- UMP consent message **"Parcel Khata consent (Android)" is published** (European regulations; apps:
  Parcel Khata Android only; Consent / Manage options / Do not consent on for all countries).

## Still to do
1. **iOS consent message**: create the same message for Parcel Khata iOS (the URL is already set).
   On iOS, also decide on the IDFA explainer (not needed while ads are non-personalised).
2. **app-ads.txt** at the root of the developer website listed on the store pages
   (`https://mehedihasantanim.github.io/app-ads.txt` only works if that user site repo exists):
   `google.com, pub-3379896207398236, DIRECT, f08c47fec0942fa0`
3. **Play Console**: Ads declaration = Yes; advertising ID declaration = used; Data safety per
   `data-safety.md`. **App Store Connect**: App Privacy per `app-store-privacy.md`.
4. Link store listings to the AdMob apps after the first release; request review ("Requires review").
5. Remove-ads purchase (`in_app_purchase`) is not implemented; `ShopSettings.adsRemoved` is the hook.
6. Add a support email to the privacy page (it currently says "developer contact on the store page").
7. Measure fill, eCPM and complaints with the beta sellers before widening.
