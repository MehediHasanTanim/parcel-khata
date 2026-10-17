# AdMob integration plan

Status: **plan only, nothing implemented.** Date: 2026-10-17.
Package/version facts below come from search snippets and third-party wrappers (the official pages
did not load): verify `google_mobile_ads` (reported 9.x; needs a recent Flutter, Android minSdk 24,
iOS 13+) against pub.dev and Google's AdMob docs before starting. The project targets iOS 15 and
`flutter.minSdkVersion`, so check minSdk (24 is not guaranteed by the Flutter default).

## 0. Decision gate (do this first)

Ads contradict three things the product currently promises and documents:

1. **"Your data never leaves the device"**: `privacy-policy.md`, store listing.
2. **Play Data safety "Ads: None"** and "Is data shared with third parties? No" (`data-safety.md`);
   the App Store label is "No tracking / no data collected" (`app-store-privacy.md`,
   `PrivacyInfo.xcprivacy`).
3. **Trust**: the app holds customers' phone numbers, addresses and the seller's margins. Sellers
   are small businesses who will notice an ad network near that data.

So before any code, decide and record (ADR `005-monetization.md`):

| Option | Revenue | Privacy cost | Verdict to validate |
|---|---|---|---|
| A. No ads; paid tier / subscription (helpers, sync, Drive) | per paying seller | none | Fits the product; sync/helpers already imply a paid tier |
| B. Free with ads, paid "remove ads" | ad eCPM x impressions | policy, label and consent changes | What this plan covers |
| C. Ads only on the free tier of the synced/account product | as B | as B, only for account users | Reasonable compromise |

**Revenue sanity check (inputs are unknown, measure before committing):**
`monthly ad revenue = DAU x screens-with-ad/day x fill x eCPM / 1000`. Example only: 1,000 DAU x 20
banner impressions x 0.8 fill x US$0.10 eCPM / 1000 = about US$48/month. Bangladeshi eCPMs are low
and I have no verified figure; get real numbers from an AdMob test with the beta sellers (S-A1
exit) before building the rest. Compare with option A at an assumed price and conversion.

Decision owner: you. The rest assumes **B or C**.

## 1. Principles (non-negotiable if we ship ads)

1. **Ads never see business data.** No customer names, phones, order contents, amounts or tags in ad
   requests: no keywords, no content URL, no custom targeting. Contextual placement only.
2. **No ads on sensitive or money-critical screens:** app lock/PIN, onboarding, order form, customer
   form and detail, COD/payout flow, statement import, backup/restore/export, security, settings,
   activity log, and any screen with a primary destructive/confirming button within a thumb's reach
   (accidental-click policy).
3. **Offline-first stays true.** Ads load best-effort and collapse to zero height on failure; the app
   must be fully usable offline and never wait for an ad.
4. **Never block entry.** No interstitial between "Save" and the next screen; none during an active
   order/payout flow.
5. **Consent first.** The SDK is not initialised (no ad request) until consent allows it.
6. **Helpers (S19)** see no ads on a shop whose owner is on a paid plan; policy for helpers on free
   shops is part of the decision gate.

## 2. Architecture

```
lib/core/ads/
  ad_config.dart        ad unit ids per platform/format from --dart-define (test ids by default)
  ads_service.dart      abstract AdsService { init(), banner(placement), interstitial(placement), dispose }
  admob_ads_service.dart  google_mobile_ads implementation (only file that imports the SDK)
  no_ads_service.dart     no-op (paid users, disabled, tests, unsupported platforms)
  ads_consent.dart      UMP flow: request info, show form if required, canRequestAds, privacy options entry
  ads_policy.dart       PURE: which placements are allowed, frequency caps, cool-downs (unit-tested)
lib/shared/ad_slot.dart  widget: reserves/collapses space, adaptive anchored banner, never throws
```

- **Riverpod:** `adsServiceProvider` returns `NoAdsService` unless `adsEnabled` (build flag
  `--dart-define=ADS=1`) AND consent allows AND the user is not on the paid/ad-free tier. Tests
  override with a fake.
- **Placement registry** (in `ads_policy.dart`): an enum of allowed placements (`ordersListFooter`,
  `reportsFooter`, `moreScreenFooter`, `homeBelowFold`) and a deny-list test that asserts no sensitive
  route renders an `AdSlot`.
- **Settings:** `ads.removed` (purchase state), `ads.lastInterstitialAt`, `ads.sessionCount` stored in
  settings JSON; frequency logic uses the injected `Clock` (project rule: no `DateTime.now()`).
- **Config:** ad unit ids and the AdMob app id come from `--dart-define` and CI secrets, never
  committed; the default is Google's test ids, so debug/CI can never show or bill real ads.
- **Layout:** adaptive anchored banner (height varies); `AdSlot` keeps a stable minimum so lists do not
  jump, and respects the 200% text-scale accessibility pass.

## 3. Formats and placement (start minimal)

| Format | Use | Notes |
|---|---|---|
| Anchored adaptive banner | footer of Orders list, Reports, More, Home below the fold | Start here; lowest risk |
| Native (list) | one card every ~15 orders in the Orders list | Phase 2, only if banner revenue justifies |
| Interstitial | **Do not ship initially.** At most after a completed export/report share, cap 1 per 20 min and 3/day | Highest annoyance and mis-click risk |
| Rewarded | Optional: watch an ad to unlock a day of a premium feature | Only if option C has a paid tier to upsell |
| App open | **No** | Conflicts with the PIN lock and cold-start budgets |

## 4. Consent and privacy

- **UMP (User Messaging Platform):** `ConsentInformation.requestConsentInfoUpdate` ->
  `loadAndShowConsentFormIfRequired` -> only then `canRequestAds` -> `MobileAds.initialize()`. Offer
  "Privacy and ad choices" in Settings (required when a form exists). Configure the consent message in
  the AdMob console (EEA/UK need it; Bangladesh may not, but the same flow is the safe default).
- **Tagging:** declare the app not directed at children (`tagForChildDirectedTreatment` unset/false,
  max content rating, e.g. `G`/`PG`) and consider disabling personalised ads for users who decline.
- **iOS App Tracking Transparency:** only if personalised ads are used. Adds
  `NSUserTrackingUsageDescription`, the ATT prompt (after UMP, with context), `GADApplicationIdentifier`
  and the SKAdNetwork identifier list in `Info.plist`; `PrivacyInfo.xcprivacy` flips to
  `NSPrivacyTracking = true` with Google's tracking domains and collected data types.
- **Android:** `APPLICATION_ID` meta-data in `AndroidManifest.xml`; the `AD_ID` permission (declared
  by the SDK; the Play Console advertising-ID declaration must match the built manifest); R8/ProGuard
  rules; `compileSdk`/`minSdk` per the plugin.
- **Documents to change (blocking for release):**
  - `privacy-policy.md`: remove "no ads / nothing leaves the device" claims; describe Google AdMob,
    advertising ID, ad interactions, how to opt out.
  - `data-safety.md`: Ads = Yes; data collected/shared with Google (device or other IDs, app
    interactions, diagnostics); not "No" for third-party sharing.
  - `app-store-privacy.md`: tracking, identifiers, usage data, advertising data.
  - Store listing: "Contains ads" (Play) and the age rating questionnaire.
  - `app-ads.txt` on a verified developer website (AdMob requires it for revenue; needs a domain).
- **Verification:** with a proxy/device logs, confirm ad requests contain no app data; add a unit test
  that the request builder passes no keywords/content URL/neighbouring content.

## 5. Interaction with existing features

- **PIN lock / background:** do not show ads on the lock screen; pause ads when the app is locked;
  the privacy "hide previews in app switcher" setting must still blur the screen with an ad present.
- **Performance budgets:** SDK init off the critical path (after first frame, after consent); measure
  cold start and 20k-order scroll with `AdSlot` present (budgets in `performance-profiling.md`).
- **Backups/Drive/sync:** unaffected; ad state is local and not synced or backed up.
- **Role gating (S19):** ad-free for paid shops; decide per role for free shops.
- **iOS:** deployment target 15 is fine; add the SDK pods in the first iOS build (ties to S21 CI job).
- **Localization:** consent form text is Google-provided (localised); our "Privacy and ad choices"
  and "Remove ads" strings go through the arb files (en + bn, parity test).
- **Local notifications, camera, WorkManager:** no interaction.

## 6. Phases

| Phase | Work | Exit |
|---|---|---|
| A0 Decision | ADR 005; choose B or C; price for "remove ads"; legal read on policy changes | Written decision, doc owners assigned |
| A1 Foundations (no ads shown) | `AdsService` + `NoAdsService`, `ads_policy.dart` with tests, flags, config via dart-define, AdMob accounts/app ids/ad units, `app-ads.txt` | Tests green; release build with `ADS=0` byte-identical behaviour |
| A2 Consent | UMP flow, privacy options entry, Settings strings, iOS ATT (if personalised) | Consent states tested with fakes; manual run in EEA test geography via UMP debug settings |
| A3 Banner | `AdSlot` on the 3-4 allowed screens, test ads only; deny-list test; 200% font and small-screen checks | Test ads render; collapse offline; no layout jump; budgets hold |
| A4 Policy docs + stores | Update privacy policy, data-safety, App Store label, store listings, Play ads declaration | Docs merged; Play/App Store forms answered consistently |
| A5 Closed beta | Real ad units with the 5-10 sellers; collect fill, eCPM, complaints, crash/ANR, mis-click reports | Go/no-go on revenue vs trust |
| A6 Remove-ads purchase | `in_app_purchase` (Play Billing / StoreKit), restore purchases, entitlement stored locally (+ account when sync exists) | Purchase/restore tested on both stores |
| A7 Optional | Native list ads, rewarded unlock, mediation (only with measured need) | Revenue uplift justifies added SDK weight and review risk |

## 7. Tests

- **Pure:** `ads_policy_test.dart`: placement allow/deny, interstitial caps and cool-downs with a
  fake clock, paid/consent/flag gating truth table.
- **Widget:** `AdSlot` renders nothing when disabled/failed, reserves no space offline, fake service
  drives loaded/failed/clicked states; deny-list test fails if a sensitive route contains an `AdSlot`
  (walk the router config or a registry of screens).
- **Privacy:** request-builder test (no keywords, content URL, extras); a check that no `Customer`,
  `Order`, `Money` types are imported by `lib/core/ads/`.
- **Integration (manual/real device):** test ids only in CI; one scripted pass with a real ad unit on a
  test device registered in AdMob.
- **Regression:** existing 562 tests must stay green with `NoAdsService` as the default.

## 8. Risks

| Risk | Mitigation |
|---|---|
| Trust loss: sellers dislike ads beside customer data | Safe-screen-only placement, paid removal, honest disclosure; beta feedback gate |
| Policy rejection (misleading disclosures, accidental clicks) | A4 docs before release; spacing from buttons; no interstitials initially |
| Low revenue | A1 measurement; option A/C as the alternative; do not build A6/A7 before data |
| SDK weight and cold start | Lazy init after first frame; measure APK/IPA size delta and startup |
| Contradiction with the sync story ("your data is private") | Keep ad code isolated from data layer; privacy test; messaging that ads never use business data |
| Consent errors (initialising before consent) | `canRequestAds` gate tested; single entry point `AdsConsent.ensure()` |
| iOS ATT drop-off | Use non-personalised ads when declined; never gate features |
| Accessibility | Test at 200% text scale, TalkBack/VoiceOver label for ad containers ("Advertisement") |

## 9. Open questions for you

1. Which option (A, B, C)? If B/C, what price for "remove ads" and which stores first?
2. Are ads acceptable for helper accounts and for shops that sync?
3. Do you have a website/domain for `app-ads.txt` and an AdMob account (needs payment profile)?
4. Is personalised advertising wanted (ATT, consent, tracking label) or non-personalised only
   (simpler labels, lower eCPM)?
