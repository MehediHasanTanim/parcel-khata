/// PURE rules for where and when ads may appear (docs/plan/admob-integration-plan.md).
/// No Flutter and no SDK imports: this is what the tests pin down.
library;

/// The only places an ad may render. Adding a value here is a deliberate,
/// reviewed decision (privacy and accidental-click policy).
enum AdPlacement {
  ordersListFooter,
  reportsFooter,
  moreFooter,
}

/// Feature areas that must never contain an ad (money-critical, personal
/// data, security). A source-scanning test enforces this.
const kAdFreeAreas = <String>[
  'lib/features/security',
  'lib/features/onboarding',
  'lib/features/backup',
  'lib/features/cod',
  'lib/features/customers',
  'lib/features/returns',
  'lib/features/expenses',
  'lib/features/settings',
  'lib/features/sync',
  'lib/features/export',
  'lib/features/templates',
  'lib/features/couriers',
  'lib/features/products',
  'lib/features/profit',
  'lib/features/search',
];

/// Individual screens that must stay ad-free even though their folder hosts
/// an allowed one (forms and detail pages with PII or confirm buttons).
const kAdFreeFiles = <String>[
  'lib/features/orders/presentation/order_form_screen.dart',
  'lib/features/orders/presentation/order_detail_screen.dart',
  'lib/features/orders/presentation/cn_entry_screen.dart',
  'lib/features/orders/presentation/paste_order_screen.dart',
  'lib/features/orders/presentation/status_actions.dart',
];

class AdContext {
  const AdContext({
    required this.buildEnabled,
    required this.platformSupported,
    required this.adsRemoved,
    required this.consentAllowsAds,
  });

  /// `--dart-define=ADS=1`.
  final bool buildEnabled;
  final bool platformSupported;

  /// The shop paid to remove ads (or runs a paid plan).
  final bool adsRemoved;

  /// UMP says the app may request ads.
  final bool consentAllowsAds;
}

abstract final class AdsPolicy {
  /// Whether the SDK may be initialised at all (consent is checked by the
  /// consent flow itself; this is everything we know before asking).
  static bool mayInitialise(AdContext c) =>
      c.buildEnabled && c.platformSupported && !c.adsRemoved;

  /// Whether an ad may be requested/shown right now.
  static bool mayShow(AdContext c) => mayInitialise(c) && c.consentAllowsAds;

  /// Banners are the only format shipped. Interstitial / app-open / rewarded
  /// are deliberately unsupported (they interrupt entry, collide with the PIN
  /// lock and the cold-start budget, and raise accidental-click risk).
  static bool formatSupported(String format) => format == 'banner';
}
