import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_khata/core/ads/ads_policy.dart';
import 'package:parcel_khata/core/ads/ads_service.dart';
import 'package:parcel_khata/features/settings/application/settings_repository.dart';
import 'package:parcel_khata/features/settings/domain/shop_settings.dart';
import 'package:parcel_khata/shared/ad_slot.dart';
import 'package:parcel_khata/shared/ads_providers.dart';

class _FakeBanner implements AdBannerHandle {
  _FakeBanner(this.result);
  final Widget? result;
  bool disposed = false;
  @override
  Future<Widget?> load() async => result;
  @override
  void dispose() => disposed = true;
}

class _FakeAds implements AdsService {
  _FakeAds({this.ready = true, this.banner});
  final bool ready;
  final Widget? banner;
  int starts = 0;
  final handles = <_FakeBanner>[];
  AdContext? lastContext;

  @override
  Future<bool> start(AdContext context) async {
    starts++;
    lastContext = context;
    return ready;
  }

  @override
  Future<bool> privacyOptionsRequired() async => false;
  @override
  Future<void> showPrivacyOptions() async {}
  @override
  AdBannerHandle createBanner(AdPlacement placement) {
    final h = _FakeBanner(banner);
    handles.add(h);
    return h;
  }
}

Widget app(_FakeAds ads, {ShopSettings settings = const ShopSettings()}) => ProviderScope(
      overrides: [
        adsServiceProvider.overrideWithValue(ads),
        shopSettingsProvider.overrideWith((ref) => Stream.value(settings)),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: Column(children: [
            Expanded(child: Text('content')),
            AdSlot(AdPlacement.moreFooter),
          ]),
        ),
      ),
    );

void main() {
  testWidgets('shows the ad once it loaded, and disposes it with the slot', (t) async {
    final ads = _FakeAds(banner: const SizedBox(key: Key('ad'), width: 320, height: 50));
    await t.pumpWidget(app(ads));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('ad')), findsOneWidget);
    expect(find.bySemanticsLabel('Advertisement'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    expect(ads.handles.single.disposed, isTrue);
  });

  testWidgets('takes no space when consent/ads are not available', (t) async {
    final ads = _FakeAds(ready: false, banner: const SizedBox(key: Key('ad'), height: 50));
    await t.pumpWidget(app(ads));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('ad')), findsNothing);
    expect(ads.handles, isEmpty, reason: 'no banner may be created without consent');
    expect(t.getSize(find.byType(AdSlot)).height, 0);
  });

  testWidgets('no fill / offline: the slot collapses', (t) async {
    final ads = _FakeAds(banner: null);
    await t.pumpWidget(app(ads));
    await t.pumpAndSettle();
    expect(t.getSize(find.byType(AdSlot)).height, 0);
    expect(find.text('content'), findsOneWidget);
  });

  testWidgets('ad-free shops are passed to the service so it never starts', (t) async {
    final ads = _FakeAds();
    await t.pumpWidget(app(ads, settings: const ShopSettings(adsRemoved: true)));
    await t.pumpAndSettle();
    expect(ads.lastContext!.adsRemoved, isTrue);
    expect(AdsPolicy.mayInitialise(ads.lastContext!), isFalse);
  });

  testWidgets('the default service is the no-op, so existing behaviour is unchanged', (t) async {
    await t.pumpWidget(ProviderScope(
      overrides: [
        shopSettingsProvider.overrideWith((ref) => Stream.value(const ShopSettings())),
      ],
      child: const MaterialApp(home: Scaffold(body: AdSlot(AdPlacement.moreFooter))),
    ));
    await t.pumpAndSettle();
    expect(t.getSize(find.byType(AdSlot)).height, 0);
  });
}
