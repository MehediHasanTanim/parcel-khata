import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_khata/core/db/app_database.dart';
import 'package:parcel_khata/core/db/audit_writer.dart';
import 'package:parcel_khata/core/ids/uuid_v7.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/core/result/result.dart';
import 'package:parcel_khata/core/time/clock.dart';
import 'package:parcel_khata/features/cod/application/ledger_writer.dart';
import 'package:parcel_khata/features/couriers/application/courier_repository.dart';
import 'package:parcel_khata/features/customers/application/customer_repository.dart';
import 'package:parcel_khata/features/orders/application/order_repository.dart';
import 'package:parcel_khata/features/orders/domain/cod_amount_calculator.dart';
import 'package:parcel_khata/features/orders/domain/order_enums.dart';
import 'package:parcel_khata/features/orders/domain/order_input.dart';
import 'package:parcel_khata/features/settings/application/settings_repository.dart';
import 'package:parcel_khata/features/settings/domain/shop_settings.dart';

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late OrderRepository orders;
  late CustomerRepository customers;
  late CourierRepository couriers;
  late SettingsRepository settings;
  late String customerId;
  late String courierId;

  OrderInput input({
    String? cn,
    String? courier,
    List<LineInput>? lines,
    PaymentType type = PaymentType.cod,
    Money? override,
    int delivery = 60,
  }) =>
      OrderInput(
        customerId: customerId,
        address: 'Road 1',
        lines: lines ??
            [
              const LineInput(
                  name: 'Shirt', qty: 2, unitSell: Money.taka(500), unitCost: Money.taka(300)),
            ],
        paymentType: type,
        deliveryCharge: Money.taka(delivery),
        courierId: courier,
        consignmentNo: cn,
        zone: 'inside_dhaka',
        codOverride: override,
      );

  setUp(() async {
    db = AppDatabase.memory();
    clock = FakeClock(DateTime.utc(2026, 10, 15, 10));
    final ids = UuidV7(clock: clock);
    final audit = AuditWriter(db, ids, clock, 's');
    customers = CustomerRepository(db, ids, clock, audit, 's');
    couriers = CourierRepository(db, ids, clock, audit, 's');
    settings = SettingsRepository(db, clock, 's');
    await settings.ensureShop();
    orders = OrderRepository(db, ids, clock, audit, 's', couriers, settings, LedgerWriter(db));
    customerId = (await customers
            .create(const CustomerInput(name: 'A', phone: '01712345678')))
        .valueOrNull!
        .id;
    courierId = (await couriers.create(const CourierInput(
      name: 'Pathao',
      codFeePercentBp: 100,
      rateRules: [RateRuleInput(zone: 'inside_dhaka', fee: Money.taka(60))],
    )))
        .valueOrNull!
        .id;
  });
  tearDown(() => db.close());

  test('create: totals, number, status event, charges', () async {
    await settings.save(const ShopSettings(defaultPackagingCostTaka: 10));
    final r = await orders.create(input(courier: courierId));
    final o = r.valueOrNull!;
    expect(o.orderNo, 'ORD-0001');
    expect(o.status, 'confirmed');
    expect(o.itemsTotal, 100000);
    expect(o.codExpected, 106000);
    expect(o.codStatus, 'pending_collection');
    final d = (await orders.detail(o.id))!;
    expect(d.events.single.toStatus, 'confirmed');
    expect(d.lines.single.unitCostPrice, 30000);
    final types = d.charges.map((c) => c.type).toSet();
    expect(types, {'delivery_fee', 'cod_fee', 'packaging'});
    final cod = d.charges.firstWhere((c) => c.type == 'cod_fee');
    expect(cod.expectedAmount, 1060); // 1% of 1,060
  });

  test('sequential numbers, never reused after delete', () async {
    final a = (await orders.create(input())).valueOrNull!;
    final b = (await orders.create(input())).valueOrNull!;
    expect([a.orderNo, b.orderNo], ['ORD-0001', 'ORD-0002']);
    await orders.softDelete(b.id);
    final c = (await orders.create(input())).valueOrNull!;
    expect(c.orderNo, 'ORD-0003');
  });

  test('start number and prefix from settings', () async {
    await settings.save(const ShopSettings(orderPrefix: 'KH-', orderStartNumber: 500));
    final o = (await orders.create(input())).valueOrNull!;
    expect(o.orderNo, 'KH-0500');
  });

  test('prepaid -> not applicable; override flagged', () async {
    final p = (await orders.create(input(type: PaymentType.prepaid))).valueOrNull!;
    expect(p.codExpected, 0);
    expect(p.codStatus, 'not_applicable');
    final o = (await orders.create(input(override: const Money.taka(900)))).valueOrNull!;
    expect(o.codExpected, 90000);
    expect(o.codOverridden, isTrue);
  });

  test('confirm validation; drafts allow incomplete', () async {
    final bad = await orders.create(const OrderInput(lines: []));
    expect(bad.failureOrNull, isA<ValidationFailure>());
    final draft = await orders.create(const OrderInput(lines: []), draft: true);
    expect(draft.valueOrNull!.status, 'draft');
  });

  test('drafts excluded from default list, included when asked', () async {
    await orders.create(input());
    await orders.create(input(), draft: true);
    expect(await orders.fetchPage(), hasLength(1));
    expect(await orders.fetchPage(filter: const OrderFilter(onlyDrafts: true)), hasLength(1));
    expect(await orders.fetchPage(filter: const OrderFilter(includeDrafts: true)), hasLength(2));
    expect(await orders.draftCount(), 1);
  });

  test('promote draft writes status event', () async {
    final d = (await orders.create(input(), draft: true)).valueOrNull!;
    final r = await orders.update(d.id, input(), promoteDraft: true);
    expect(r.valueOrNull!.order.status, 'confirmed');
    final detail = (await orders.detail(d.id))!;
    expect(detail.events.map((e) => e.toStatus), ['draft', 'confirmed']);
  });

  test('duplicate CN blocked with link; allowed on different courier', () async {
    final a = (await orders.create(input(courier: courierId, cn: 'CN1'))).valueOrNull!;
    final dup = await orders.create(input(courier: courierId, cn: 'CN1'));
    final f = dup.failureOrNull! as ConflictFailure;
    expect(f.conflictingId, a.id);
    final other = (await couriers.create(const CourierInput(name: 'RedX'))).valueOrNull!;
    expect((await orders.create(input(courier: other.id, cn: 'CN1'))).isOk, isTrue);
  });

  test('update logs field diffs', () async {
    final o = (await orders.create(input())).valueOrNull!;
    await orders.update(o.id, input(delivery: 100));
    final d = (await orders.detail(o.id))!;
    final fields = d.edits.map((e) => e.field).toSet();
    expect(fields, containsAll(['delivery_charge', 'cod_expected']));
    final e = d.edits.firstWhere((e) => e.field == 'delivery_charge');
    expect([e.oldValue, e.newValue], ['6000', '10000']);
  });

  test('editing amounts after handover warns', () async {
    final o = (await orders.create(input(courier: courierId, cn: 'CN9'))).valueOrNull!;
    await (db.update(db.orders)..where((x) => x.id.equals(o.id)))
        .write(const OrdersCompanion(status: Value('handed_to_courier')));
    final r = await orders.update(o.id, input(courier: courierId, cn: 'CN9', delivery: 200));
    expect(r.valueOrNull!.warnings, [OrderWarning.amountsChangedAfterHandover]);
  });

  test('editing amounts of delivered order needs confirmation', () async {
    final o = (await orders.create(input())).valueOrNull!;
    await (db.update(db.orders)..where((x) => x.id.equals(o.id)))
        .write(const OrdersCompanion(status: Value('delivered')));
    final changed = input(delivery: 500);
    final first = await orders.update(o.id, changed);
    expect(first.failureOrNull, isA<ConfirmationRequiredFailure>());
    final second = await orders.update(o.id, changed, confirmed: true);
    expect(second.isOk, isTrue);
    expect(second.valueOrNull!.order.deliveryChargeCustomer, 50000);
  });

  test('duplicate copies lines and resets status, CN, date', () async {
    final o = (await orders.create(input(courier: courierId, cn: 'CN5'))).valueOrNull!;
    clock.advance(const Duration(days: 2));
    final d = (await orders.duplicate(o.id)).valueOrNull!;
    expect(d.id, isNot(o.id));
    expect(d.status, 'confirmed');
    expect(d.consignmentNo, isNull);
    expect(d.itemsTotal, o.itemsTotal);
    expect(d.orderDate.isAfter(o.orderDate), isTrue);
    expect((await orders.detail(d.id))!.lines.single.unitCostPrice, 30000);
  });

  test('soft delete, restore, recently deleted window and purge', () async {
    final o = (await orders.create(input())).valueOrNull!;
    await orders.softDelete(o.id);
    expect(await orders.fetchPage(), isEmpty);
    expect(await orders.watchRecentlyDeleted().first, hasLength(1));
    expect((await orders.restore(o.id)).isOk, isTrue);
    expect(await orders.fetchPage(), hasLength(1));

    await orders.softDelete(o.id);
    clock.advance(const Duration(days: 31));
    expect(await orders.watchRecentlyDeleted().first, isEmpty);
    expect(await orders.purgeExpired(), 1);
    expect(await orders.getById(o.id), isNull);
  });

  test('keyset pagination is stable and complete', () async {
    for (var i = 0; i < 25; i++) {
      clock.advance(const Duration(minutes: 1));
      await orders.create(input());
    }
    final seen = <String>[];
    OrderCursor? cursor;
    while (true) {
      final page = await orders.fetchPage(after: cursor, limit: 10);
      if (page.isEmpty) break;
      seen.addAll(page.map((p) => p.order.id));
      final last = page.last.order;
      cursor = OrderCursor(last.orderDate, last.id);
    }
    expect(seen.length, 25);
    expect(seen.toSet().length, 25);
    // Newest first.
    final first = (await orders.fetchPage(limit: 1)).single.order;
    expect(seen.first, first.id);
  });

  test('filters: status, channel, date range, customer', () async {
    await orders.create(input());
    final inputB = OrderInput(
      customerId: customerId,
      address: 'x',
      channel: Channel.whatsapp,
      lines: const [LineInput(name: 'y', qty: 1, unitSell: Money.taka(10))],
    );
    await orders.create(inputB);
    expect(
        await orders.fetchPage(filter: const OrderFilter(channel: Channel.whatsapp)),
        hasLength(1));
    expect(
        await orders.fetchPage(
            filter: const OrderFilter(statuses: {OrderStatus.delivered})),
        isEmpty);
    expect(await orders.fetchPage(filter: OrderFilter(customerId: customerId)), hasLength(2));
    final tomorrow = clock.now().add(const Duration(days: 1));
    expect(await orders.fetchPage(filter: OrderFilter(from: tomorrow)), isEmpty);
  });
}
