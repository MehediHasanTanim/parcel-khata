import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_khata/features/couriers/domain/stuck_parcel_policy.dart';
import 'package:parcel_khata/features/orders/domain/order_enums.dart';

void main() {
  final now = DateTime.utc(2026, 10, 15, 12);
  StuckLevel level(int daysAgo, {int n = 3, OrderStatus s = OrderStatus.handedToCourier}) =>
      StuckParcelPolicy.level(
        status: s,
        handedOverAt: now.subtract(Duration(days: daysAgo)),
        now: now,
        stuckDays: n,
      );

  test('boundaries at N and 2N', () {
    expect(level(0), StuckLevel.none);
    expect(level(2), StuckLevel.none);
    expect(level(3), StuckLevel.amber);
    expect(level(5), StuckLevel.amber);
    expect(level(6), StuckLevel.red);
    expect(level(30), StuckLevel.red);
  });

  test('just under N days (23h) is not stuck', () {
    final l = StuckParcelPolicy.level(
      status: OrderStatus.inTransit,
      handedOverAt: now.subtract(const Duration(days: 2, hours: 23)),
      now: now,
      stuckDays: 3,
    );
    expect(l, StuckLevel.none);
  });

  test('only statuses with the courier count', () {
    expect(level(10, s: OrderStatus.delivered), StuckLevel.none);
    expect(level(10, s: OrderStatus.confirmed), StuckLevel.none);
    expect(level(10, s: OrderStatus.inTransit), StuckLevel.red);
  });

  test('missing stamp or non-positive threshold', () {
    expect(
        StuckParcelPolicy.level(
            status: OrderStatus.handedToCourier, handedOverAt: null, now: now, stuckDays: 3),
        StuckLevel.none);
    expect(level(10, n: 0), StuckLevel.none);
  });
}
