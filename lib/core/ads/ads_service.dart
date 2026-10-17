import 'package:flutter/widgets.dart';
import 'package:parcel_khata/core/ads/ads_policy.dart';

/// One banner slot's lifecycle. `load` resolves to the widget to show, or
/// null when no ad is available (offline, no fill, error): the slot then
/// takes no space.
abstract class AdBannerHandle {
  Future<Widget?> load();
  void dispose();
}

/// The only seam to the ad SDK. `AdMobAdsService` is the single file that
/// imports it; everything else (and every test) uses this interface.
abstract class AdsService {
  /// Consent flow + SDK initialisation. True when ads may be requested.
  /// Safe to call repeatedly.
  Future<bool> start(AdContext context);

  /// "Privacy and ad choices" must be offered when this is true.
  Future<bool> privacyOptionsRequired();
  Future<void> showPrivacyOptions();

  AdBannerHandle createBanner(AdPlacement placement);
}

class _NoBanner implements AdBannerHandle {
  @override
  Future<Widget?> load() async => null;
  @override
  void dispose() {}
}

/// Default: no ads (disabled build, ad-free shop, tests, desktop).
class NoAdsService implements AdsService {
  const NoAdsService();

  @override
  Future<bool> start(AdContext context) async => false;
  @override
  Future<bool> privacyOptionsRequired() async => false;
  @override
  Future<void> showPrivacyOptions() async {}
  @override
  AdBannerHandle createBanner(AdPlacement placement) => _NoBanner();
}
