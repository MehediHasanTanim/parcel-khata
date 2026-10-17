import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:parcel_khata/core/ads/ad_config.dart';
import 'package:parcel_khata/core/ads/ads_policy.dart';
import 'package:parcel_khata/core/ads/ads_service.dart';

/// The ONLY file that imports the AdMob SDK.
///
/// Privacy: requests carry no targeting data at all (nothing but the
/// non-personalised flag). Nothing from the seller's data ever
/// reaches this layer (a test checks that `lib/core/ads` imports no feature
/// code).
class AdMobAdsService implements AdsService {
  bool _initialised = false;
  Future<bool>? _starting;

  /// The only request the app ever makes.
  static AdRequest buildRequest() => const AdRequest(nonPersonalizedAds: true);

  @override
  Future<bool> start(AdContext context) => _starting ??= _start(context);

  Future<bool> _start(AdContext context) async {
    if (!AdsPolicy.mayInitialise(context)) return false;
    final allowed = await _gatherConsent();
    if (!allowed) return false;
    if (!_initialised) {
      await MobileAds.instance.updateRequestConfiguration(RequestConfiguration(
        maxAdContentRating: MaxAdContentRating.pg,
        tagForChildDirectedTreatment: TagForChildDirectedTreatment.no,
        tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.no,
      ));
      await MobileAds.instance.initialize();
      _initialised = true;
    }
    return true;
  }

  /// UMP: update consent info, show the form when required, then ask whether
  /// ads may be requested. No ad request happens before this resolves.
  Future<bool> _gatherConsent() async {
    final info = ConsentInformation.instance;
    final updated = Completer<bool>();
    info.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => updated.complete(true),
      (error) => updated.complete(false),
    );
    // A failed update can still allow ads from an earlier consent.
    await updated.future;
    final shown = Completer<void>();
    unawaited(ConsentForm.loadAndShowConsentFormIfRequired((_) {
      if (!shown.isCompleted) shown.complete();
    }));
    await shown.future;
    return info.canRequestAds();
  }

  @override
  Future<bool> privacyOptionsRequired() async =>
      await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
      PrivacyOptionsRequirementStatus.required;

  @override
  Future<void> showPrivacyOptions() async {
    final done = Completer<void>();
    unawaited(ConsentForm.showPrivacyOptionsForm((_) {
      if (!done.isCompleted) done.complete();
    }));
    await done.future;
  }

  @override
  AdBannerHandle createBanner(AdPlacement placement) => _AdMobBanner();
}

class _AdMobBanner implements AdBannerHandle {
  BannerAd? _ad;

  @override
  Future<Widget?> load() {
    final done = Completer<Widget?>();
    final ad = BannerAd(
      // Fixed 320x50: stable height, so lists never jump.
      size: AdSize.banner,
      adUnitId: AdConfig.bannerUnitId,
      request: AdMobAdsService.buildRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!done.isCompleted) {
            done.complete(SizedBox(
              width: AdSize.banner.width.toDouble(),
              height: AdSize.banner.height.toDouble(),
              child: AdWidget(ad: ad as BannerAd),
            ));
          }
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (!done.isCompleted) done.complete(null);
        },
      ),
    );
    _ad = ad;
    unawaited(ad.load());
    return done.future.timeout(const Duration(seconds: 15), onTimeout: () => null);
  }

  @override
  void dispose() => _ad?.dispose();
}
