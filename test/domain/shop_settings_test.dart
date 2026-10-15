import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_khata/features/settings/domain/shop_settings.dart';

void main() {
  test('defaults on empty/garbage', () {
    expect(ShopSettings.decode(null).orderPrefix, 'ORD-');
    expect(ShopSettings.decode('{}').stockTrackingEnabled, isFalse);
    expect(ShopSettings.decode('not json').orderStartNumber, 1);
    expect(ShopSettings.decode('[1,2]').languageCode, 'bn');
  });

  test('round trip', () {
    final s = const ShopSettings().copyWith(
      businessName: 'Shop',
      orderPrefix: 'X-',
      orderStartNumber: 100,
      stockTrackingEnabled: true,
      defaultCourierId: 'c1',
    );
    final back = ShopSettings.decode(s.encode());
    expect(back.businessName, 'Shop');
    expect(back.orderPrefix, 'X-');
    expect(back.orderStartNumber, 100);
    expect(back.stockTrackingEnabled, isTrue);
    expect(back.defaultCourierId, 'c1');
  });

  test('new return/privacy settings round trip with defaults', () {
    expect(const ShopSettings().returnInTransitDays, 7);
    expect(const ShopSettings().hideProfitInLists, isFalse);
    final s = const ShopSettings().copyWith(returnInTransitDays: 10, hideProfitInLists: true);
    final back = ShopSettings.decode(s.encode());
    expect(back.returnInTransitDays, 10);
    expect(back.hideProfitInLists, isTrue);
  });

  test('clearDefaultCourier', () {
    final s = const ShopSettings(defaultCourierId: 'c').copyWith(clearDefaultCourier: true);
    expect(s.defaultCourierId, isNull);
  });
}
