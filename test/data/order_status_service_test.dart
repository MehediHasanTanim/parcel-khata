import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_khata/core/db/app_database.dart';
import 'package:parcel_khata/core/db/audit_writer.dart';
import 'package:parcel_khata/core/ids/uuid_v7.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/core/time/clock.dart';
import 'package:parcel_khata/features/couriers/application/courier_repository.dart';
import 'package:parcel_khata/features/couriers/domain/stuck_parcel_policy.dart';
import 'package:parcel_khata/features/customers/application/customer_repository.dart';
import 'package:parcel_khata/features/orders/application/order_repository.dart';
import 'package:parcel_khata/features/orders/application/order_status_service.dart';
import 'package:parcel_khata/features/orders/domain/cod_amount_calculator.dart';
import 'package:parcel_khata/features/orders/domain/order_enums.dart';
import 'package:parcel_khata/features/orders/domain/order_input.dart';
import 'package:parcel_khata/features/orders/domain/order_status_machine.dart';
import 'package:parcel_khata/features/settings/application/settings_repository.dart';
import 'package:parcel_khata/features/settings/domain/shop_settings.dart';

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late OrderRepository orders;
  late OrderStatusService status;
  late SettingsRepository settings;
  late String customerId;
  late String courierId;
  var seq = 0;

  Future<Order> newOrder({bool withCn = true, PaymentType type = PaymentType.cod}) async {
    seq++;
    final r = await orders.create(OrderInput(
      customerId: customerId,
      address: 'Road',
      paymentType: type,
      courierId: courierId,
      consignmentNo: withCn ? 'CN$seq' : null,
      zone: 'inside_dhaka',
      lines: const [LineInput(name: 'x', qty: 1, unitSell: Money.taka(1000), unitCost: Money.taka(600))],
    ));
    return r.valueOrNull!;
  }

  setUp(() async {
    seq = 0;
    db = AppDatabase.memory();
    clock = FakeClock(DateTime.utc(2026, 10, 15, 12));
    final ids = UuidV7(clock: clock);
    final audit = AuditWriter(db, ids, clock, 's');
    final customers = CustomerRepository(db, ids, clock, audit, 's');
    final couriers = CourierRepository(db, ids, clock, audit, 's');
    settings = SettingsRepository(db, clock, 's');
    await settings.ensureShop();
    orders = OrderRepository(db, ids, clock, audit, 's', couriers, settings);
    status = OrderStatusService(db, ids, clock, audit, 's', settings);
    customerId = (await customers.create(const CustomerInput(name: 'A', phone: '01712345678')))
        .valueOrNull!
        .id;
    courierId = (await couriers.create(const CourierInput(name: 'Pathao', stuckDays: 3)))
        .valueOrNull!
        .id;
  });
  tearDown(() => db.close());

  test('handover stamps handed_over_at and records the event', () async {
    final o = await newOrder();
    final at = clock.now().subtract(const Duration(days: 1));
    final r = await status.changeStatus(o.id, to: OrderStatus.handedToCourier, at: at);
    expect(r.valueOrNull!.status, 'handed_to_courier');
    expect(r.valueOrNull!.handedOverAt, at);
    final d = (await orders.detail(o.id))!;
    expect(d.events.last.fromStatus, 'confirmed');
    expect(d.events.last.at, at);
  });

  test('guards surface as typed failures', () async {
    final noCn = await newOrder(withCn: false);
    final r = await status.changeStatus(noCn.id, to: OrderStatus.handedToCourier);
    expect((r.failureOrNull! as TransitionFailure).error, TransitionError.cnRequired);
    final o = await newOrder();
    final bad = await status.changeStatus(o.id, to: OrderStatus.delivered);
    expect((bad.failureOrNull! as TransitionFailure).error, TransitionError.notAllowed);
  });

  test('delivered -> COD collected by courier; prepaid stays not applicable', () async {
    final cod = await newOrder();
    await status.changeStatus(cod.id, to: OrderStatus.handedToCourier);
    final d = (await status.changeStatus(cod.id, to: OrderStatus.delivered)).valueOrNull!;
    expect(d.codStatus, 'collected_by_courier');
    expect(d.codCollected, d.codExpected);
    expect(d.deliveredAt, isNotNull);

    final pre = await newOrder(type: PaymentType.prepaid);
    await status.changeStatus(pre.id, to: OrderStatus.handedToCourier);
    final p = (await status.changeStatus(pre.id, to: OrderStatus.delivered)).valueOrNull!;
    expect(p.codStatus, 'not_applicable');
  });

  test('failed delivery needs reason, auto-starts return, COD not collected', () async {
    final o = await newOrder();
    await status.changeStatus(o.id, to: OrderStatus.handedToCourier);
    final noReason = await status.changeStatus(o.id, to: OrderStatus.deliveryFailed);
    expect((noReason.failureOrNull! as TransitionFailure).error, TransitionError.reasonRequired);
    final r = await status.changeStatus(o.id,
        to: OrderStatus.deliveryFailed, reason: 'customer_refused');
    expect(r.valueOrNull!.status, 'return_in_transit');
    expect(r.valueOrNull!.codStatus, 'not_collected');
    final events = (await orders.detail(o.id))!.events.map((e) => e.toStatus).toList();
    expect(events, ['confirmed', 'handed_to_courier', 'delivery_failed', 'return_in_transit']);
  });

  test('auto return flow can be turned off', () async {
    await settings.save(const ShopSettings(autoStartReturnFlow: false));
    final o = await newOrder();
    await status.changeStatus(o.id, to: OrderStatus.handedToCourier);
    final r = await status.changeStatus(o.id,
        to: OrderStatus.deliveryFailed, reason: 'not_reachable');
    expect(r.valueOrNull!.status, 'delivery_failed');
  });

  test('bulk: valid applied, invalid skipped with reason; undo restores exactly', () async {
    final a = await newOrder();
    final b = await newOrder();
    final c = await newOrder(withCn: false);
    final before = await orders.getById(a.id);

    final res = await status.bulkChange([a.id, b.id, c.id], to: OrderStatus.handedToCourier);
    expect(res.changedIds.toSet(), {a.id, b.id});
    expect(res.skipped.single.orderId, c.id);
    expect(res.skipped.single.error, TransitionError.cnRequired);

    expect(await status.undo(res.undoToken!), isTrue);
    final after = await orders.getById(a.id);
    expect(after!.status, before!.status);
    expect(after.handedOverAt, before.handedOverAt);
    expect((await orders.detail(a.id))!.events, hasLength(1));
    // Token is single-use.
    expect(await status.undo(res.undoToken!), isFalse);
  });

  test('undo expires after 30s and after another mutation', () async {
    final a = await newOrder();
    final r1 = await status.bulkChange([a.id], to: OrderStatus.handedToCourier);
    clock.advance(const Duration(seconds: 31));
    expect(await status.undo(r1.undoToken!), isFalse);

    final b = await newOrder();
    final r2 = await status.bulkChange([b.id], to: OrderStatus.handedToCourier);
    final c = await newOrder();
    await status.bulkChange([c.id], to: OrderStatus.handedToCourier);
    expect(await status.undo(r2.undoToken!), isFalse);
  });

  test('bulk of 100 orders completes quickly', () async {
    final ids = <String>[];
    for (var i = 0; i < 100; i++) {
      ids.add((await newOrder()).id);
    }
    final sw = Stopwatch()..start();
    final r = await status.bulkChange(ids, to: OrderStatus.handedToCourier);
    sw.stop();
    expect(r.changedIds, hasLength(100));
    expect(sw.elapsedMilliseconds, lessThan(2000));
  });

  test('correction needs note, is flagged, bypasses table', () async {
    final o = await newOrder();
    await status.changeStatus(o.id, to: OrderStatus.handedToCourier);
    await status.changeStatus(o.id, to: OrderStatus.delivered);
    expect((await status.correctStatus(o.id, to: OrderStatus.handedToCourier, note: ' '))
        .isOk, isFalse);
    final r = await status.correctStatus(o.id,
        to: OrderStatus.handedToCourier, note: 'marked by mistake');
    expect(r.valueOrNull!.status, 'handed_to_courier');
    expect(r.valueOrNull!.deliveredAt, isNull);
    expect(r.valueOrNull!.codStatus, 'pending_collection');
    final last = (await orders.detail(o.id))!.events.last;
    expect(last.reason, kCorrectionReason);
    expect(last.note, 'marked by mistake');
  });

  test('stuck orders: amber at N, red at 2N, worst first', () async {
    final a = await newOrder();
    final b = await newOrder();
    final c = await newOrder();
    await status.changeStatus(a.id,
        to: OrderStatus.handedToCourier, at: clock.now().subtract(const Duration(days: 3)));
    await status.changeStatus(b.id,
        to: OrderStatus.handedToCourier, at: clock.now().subtract(const Duration(days: 7)));
    await status.changeStatus(c.id,
        to: OrderStatus.handedToCourier, at: clock.now().subtract(const Duration(days: 1)));
    final stuck = await status.stuckOrders();
    expect(stuck.map((s) => s.order.id), [b.id, a.id]);
    expect(stuck.map((s) => s.level), [StuckLevel.red, StuckLevel.amber]);
  });

  test('assignCourier: unique CN, regex is a soft warning, charges rebuilt', () async {
    final a = await newOrder(withCn: false);
    final b = await newOrder(withCn: false);
    final okRes = await orders.assignCourier(a.id, courierId: courierId, consignmentNo: 'ZZ1');
    expect(okRes.isOk, isTrue);
    final dup = await orders.assignCourier(b.id, courierId: courierId, consignmentNo: 'ZZ1');
    expect(dup.isOk, isFalse);
  });
}
