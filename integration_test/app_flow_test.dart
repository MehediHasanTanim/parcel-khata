import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:parcel_khata/app/app.dart';
import 'package:parcel_khata/core/db/app_database.dart';
import 'package:parcel_khata/core/db/providers.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/features/cod/application/payout_service.dart';
import 'package:parcel_khata/features/cod/domain/payout_reconciler.dart';
import 'package:parcel_khata/features/couriers/application/courier_repository.dart';
import 'package:parcel_khata/features/customers/application/customer_repository.dart';
import 'package:parcel_khata/features/orders/application/order_repository.dart';
import 'package:parcel_khata/features/orders/application/order_status_service.dart';
import 'package:parcel_khata/features/orders/domain/cod_amount_calculator.dart';
import 'package:parcel_khata/features/orders/domain/order_enums.dart';
import 'package:parcel_khata/features/orders/domain/order_input.dart';
import 'package:parcel_khata/features/reports/application/dashboard_service.dart';
import 'package:parcel_khata/features/reports/domain/report_math.dart';
import 'package:parcel_khata/features/settings/application/settings_repository.dart';
import 'package:parcel_khata/features/settings/domain/shop_settings.dart';

/// Offline end-to-end flows (implementation plan §7 S8-11). Run on an
/// emulator/device: `flutter test integration_test`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> boot() async {
    final c = ProviderContainer(overrides: [
      databaseProvider.overrideWith((ref) {
        final db = AppDatabase.memory();
        ref.onDispose(db.close);
        return db;
      }),
    ]);
    await c.read(settingsRepositoryProvider).ensureShop();
    await c.read(settingsRepositoryProvider).save(const ShopSettings(onboardingDone: true));
    return c;
  }

  testWidgets('create -> dispatch -> deliver -> payout -> report, fully offline',
      (tester) async {
    final c = await boot();
    final customer = (await c
            .read(customerRepositoryProvider)
            .create(const CustomerInput(name: 'Rahim', phone: '01712345678')))
        .valueOrNull!;
    final courier = (await c.read(courierRepositoryProvider).create(const CourierInput(
      name: 'Pathao',
      codFeePercentBp: 100,
      rateRules: [RateRuleInput(zone: 'inside_dhaka', fee: Money.taka(60))],
    )))
        .valueOrNull!;

    final orders = c.read(orderRepositoryProvider);
    final status = c.read(orderStatusServiceProvider);
    final ids = <String>[];
    for (var i = 0; i < 3; i++) {
      final o = (await orders.create(OrderInput(
        customerId: customer.id,
        address: 'Road $i',
        deliveryCharge: const Money.taka(60),
        courierId: courier.id,
        consignmentNo: 'CN$i',
        zone: 'inside_dhaka',
        lines: const [
          LineInput(name: 'Shirt', qty: 1, unitSell: Money.taka(1000), unitCost: Money.taka(600)),
        ],
      )))
          .valueOrNull!;
      ids.add(o.id);
    }
    final bulk = await status.bulkChange(ids, to: OrderStatus.handedToCourier);
    expect(bulk.changedIds, hasLength(3));
    await status.bulkChange(ids, to: OrderStatus.delivered);

    final payouts = c.read(payoutServiceProvider);
    final payable = await payouts.payableOrders(courier.id);
    expect(payable, hasLength(3));
    final total = PayoutReconciler.expectedTotal([for (final p in payable) p.reconcile]);
    final r = await payouts.recordPayout(RecordPayoutInput(
      courierId: courier.id,
      totalReceived: total,
      selectedOrderIds: ids,
      allocations: PayoutReconciler.autoAllocate([for (final p in payable) p.reconcile], total),
    ));
    expect(r.isOk, isTrue);

    final dash = await c
        .read(dashboardServiceProvider)
        .load(DatePeriod.resolve(PeriodPreset.thisMonth, DateTime.now()));
    expect(dash.tiles[TileId.pending]!.value, 0);
    expect(dash.tiles[TileId.profitFinal]!.value, greaterThan(0));

    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: const ParcelKhataApp(),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    c.dispose();
  });

  testWidgets('return flow keeps profit and stock consistent', (tester) async {
    final c = await boot();
    final customer = (await c
            .read(customerRepositoryProvider)
            .create(const CustomerInput(name: 'A', phone: '01712345678')))
        .valueOrNull!;
    final courier = (await c
            .read(courierRepositoryProvider)
            .create(const CourierInput(name: 'RedX')))
        .valueOrNull!;
    final o = (await c.read(orderRepositoryProvider).create(OrderInput(
      customerId: customer.id,
      address: 'X',
      courierId: courier.id,
      consignmentNo: 'R1',
      zone: 'inside_dhaka',
      lines: const [
        LineInput(name: 'Bag', qty: 1, unitSell: Money.taka(800), unitCost: Money.taka(500)),
      ],
    )))
        .valueOrNull!;
    final status = c.read(orderStatusServiceProvider);
    await status.changeStatus(o.id, to: OrderStatus.handedToCourier);
    final failed = await status.changeStatus(o.id,
        to: OrderStatus.deliveryFailed, reason: 'customer_refused');
    expect(failed.valueOrNull!.status, 'return_in_transit');
    c.dispose();
  });
}
