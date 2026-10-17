import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parcel_khata/core/ads/ad_config.dart';
import 'package:parcel_khata/core/ads/admob_ads_service.dart';
import 'package:parcel_khata/core/ads/ads_policy.dart';
import 'package:parcel_khata/core/ads/ads_service.dart';
import 'package:parcel_khata/features/settings/application/settings_repository.dart';

/// Real service only when the build enables ads on a supported platform;
/// otherwise the no-op. Tests override this with a fake.
final adsServiceProvider = Provider<AdsService>((ref) =>
    AdConfig.enabled && AdConfig.platformSupported ? AdMobAdsService() : const NoAdsService());

/// Whether the shop removed ads (paid). Defaults to false while loading so
/// the policy stays conservative only for *showing*; initialisation waits for
/// the settings read.
final adsRemovedProvider = Provider<bool>(
    (ref) => ref.watch(shopSettingsProvider).value?.adsRemoved ?? false);

/// Consent + SDK init, started lazily by the first ad slot (never on the
/// cold-start path). True = ads may be requested.
final adsReadyProvider = FutureProvider<bool>((ref) async {
  final settings = await ref.watch(shopSettingsProvider.future);
  return ref.read(adsServiceProvider).start(AdContext(
        buildEnabled: AdConfig.enabled,
        platformSupported: AdConfig.platformSupported,
        adsRemoved: settings.adsRemoved,
        consentAllowsAds: true, // the service itself asks UMP before returning true
      ));
});

final privacyOptionsRequiredProvider = FutureProvider<bool>((ref) async {
  if (!await ref.watch(adsReadyProvider.future)) return false;
  return ref.read(adsServiceProvider).privacyOptionsRequired();
});
