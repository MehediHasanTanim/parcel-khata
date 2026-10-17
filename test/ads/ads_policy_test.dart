import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_khata/core/ads/ads_policy.dart';

AdContext ctx({
  bool build = true,
  bool platform = true,
  bool removed = false,
  bool consent = true,
}) =>
    AdContext(
      buildEnabled: build,
      platformSupported: platform,
      adsRemoved: removed,
      consentAllowsAds: consent,
    );

List<File> dartFiles(String dir) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'))
    .toList();

void main() {
  group('gating truth table', () {
    test('initialise only for an ads build on a supported platform for a shop that did not pay',
        () {
      expect(AdsPolicy.mayInitialise(ctx()), isTrue);
      expect(AdsPolicy.mayInitialise(ctx(build: false)), isFalse);
      expect(AdsPolicy.mayInitialise(ctx(platform: false)), isFalse);
      expect(AdsPolicy.mayInitialise(ctx(removed: true)), isFalse);
    });

    test('showing additionally needs consent', () {
      expect(AdsPolicy.mayShow(ctx()), isTrue);
      expect(AdsPolicy.mayShow(ctx(consent: false)), isFalse);
      expect(AdsPolicy.mayShow(ctx(removed: true)), isFalse);
      expect(AdsPolicy.mayShow(ctx(build: false)), isFalse);
    });

    test('only banners are a supported format', () {
      expect(AdsPolicy.formatSupported('banner'), isTrue);
      for (final f in ['interstitial', 'app_open', 'rewarded', 'native']) {
        expect(AdsPolicy.formatSupported(f), isFalse, reason: f);
      }
    });
  });

  group('placement deny-list (source scan)', () {
    test('AdSlot appears only in the allowed screens', () {
      final users = [
        for (final f in dartFiles('lib'))
          if (f.readAsStringSync().contains('AdSlot(') && !f.path.endsWith('shared/ad_slot.dart'))
            f.path,
      ]..sort();
      expect(users, [
        'lib/features/more/presentation/more_screen.dart',
        'lib/features/orders/presentation/orders_screen.dart',
        'lib/features/reports/presentation/reports_screens.dart',
      ]);
    });

    test('no ad in money-critical, personal-data or security areas', () {
      for (final dir in kAdFreeAreas) {
        if (!Directory(dir).existsSync()) continue;
        for (final f in dartFiles(dir)) {
          final src = f.readAsStringSync();
          expect(src.contains('AdSlot'), isFalse, reason: f.path);
          expect(src.contains('google_mobile_ads'), isFalse, reason: f.path);
        }
      }
      for (final path in kAdFreeFiles) {
        expect(File(path).existsSync(), isTrue, reason: 'stale entry $path');
        expect(File(path).readAsStringSync().contains('AdSlot'), isFalse, reason: path);
      }
    });

    test('the orders list never shows an ad on customer-scoped or measure lists', () {
      final src = File('lib/features/orders/presentation/orders_screen.dart').readAsStringSync();
      final i = src.indexOf('AdSlot(AdPlacement.ordersListFooter)');
      final guard = src.substring(i - 200, i);
      expect(guard, contains('widget.customerId == null'));
      expect(guard, contains('!_selecting'));
    });

    test('the SDK is imported by exactly one file', () {
      final users = [
        for (final f in dartFiles('lib'))
          if (f.readAsStringSync().contains("package:google_mobile_ads")) f.path,
      ];
      expect(users, ['lib/core/ads/admob_ads_service.dart']);
    });
  });

  group('privacy: ads never see business data', () {
    test('lib/core/ads imports no feature, DB or money code', () {
      for (final f in dartFiles('lib/core/ads')) {
        final src = f.readAsStringSync();
        for (final bad in [
          'package:parcel_khata/features/',
          'package:parcel_khata/core/db/',
          'package:parcel_khata/core/money/',
        ]) {
          expect(src.contains(bad), isFalse, reason: '${f.path} imports $bad');
        }
      }
    });

    test('the ad request carries no keywords, content URL, extras or personalisation', () {
      final src = File('lib/core/ads/admob_ads_service.dart').readAsStringSync();
      expect(src, contains('AdRequest(nonPersonalizedAds: true)'));
      for (final bad in ['keywords', 'contentUrl', 'neighboringContentUrls', 'extras']) {
        expect(src.contains(bad), isFalse, reason: bad);
      }
    });

    test('ads_policy.dart is pure Dart', () {
      final src = File('lib/core/ads/ads_policy.dart').readAsStringSync();
      expect(src.contains('package:flutter'), isFalse);
      expect(src.contains('google_mobile_ads'), isFalse);
    });

    test('defaults are Google test ids, never a real unit', () {
      final src = File('lib/core/ads/ad_config.dart').readAsStringSync();
      expect(src, contains("defaultValue: testBannerAndroid"));
      expect(src, contains("defaultValue: testBannerIos"));
      expect(src, contains("bool.fromEnvironment('ADS')"));
      expect(src, contains('ca-app-pub-3940256099942544'));
    });
  });
}
