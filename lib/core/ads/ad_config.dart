import 'dart:io';

/// Build-time ad configuration. Defaults are Google's public TEST ids, so a
/// debug/CI build can never show or bill real ads. Real ids are passed with
/// `--dart-define` in release builds (see docs/release/ads.md).
abstract final class AdConfig {
  /// Master switch: `--dart-define=ADS=1`. Off = no SDK call at all.
  static const enabled = bool.fromEnvironment('ADS');

  // Google sample banner units: https://developers.google.com/admob/flutter/test-ads
  static const testBannerAndroid = 'ca-app-pub-3940256099942544/6300978111';
  static const testBannerIos = 'ca-app-pub-3940256099942544/2934735716';

  static const bannerAndroid =
      String.fromEnvironment('ADMOB_BANNER_ANDROID', defaultValue: testBannerAndroid);
  static const bannerIos =
      String.fromEnvironment('ADMOB_BANNER_IOS', defaultValue: testBannerIos);

  static String get bannerUnitId => Platform.isIOS ? bannerIos : bannerAndroid;

  /// True while a Google test unit is configured (safe for development).
  static bool get usingTestUnits =>
      bannerUnitId == testBannerAndroid || bannerUnitId == testBannerIos;

  /// Ads are only supported on the two mobile platforms we ship.
  static bool get platformSupported => Platform.isAndroid || Platform.isIOS;
}
