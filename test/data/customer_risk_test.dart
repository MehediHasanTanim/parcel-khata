import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_khata/core/db/app_database.dart';
import 'package:parcel_khata/core/db/audit_writer.dart';
import 'package:parcel_khata/core/ids/uuid_v7.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/core/time/clock.dart';
import 'package:parcel_khata/features/cod/application/ledger_writer.dart';
import 'package:parcel_khata/features/couriers/application/courier_repository.dart';
import 'package:parcel_khata/features/customers/application/customer_repository.dart';
import 'package:parcel_khata/features/customers/application/customer_risk_queries.dart';
import 'package:parcel_khata/features/customers/domain/customer_risk.dart';
import 'package:parcel_khata/features/orders/application/order_repository.dart';
import 'package:parcel_khata/features/orders/application/order_status_service.dart';
import 'package:parcel_khata/features/orders/domain/cod_amount_calculator.dart';
import 'package:parcel_khata/features/orders/domain/order_enums.dart';
import 'package:parcel_khata/features/orders/domain/order_input.dart';
import 'package:parcel_khata/features/returns/application/stock_service.dart';
import 'package:parcel_khata/features/settings/application/settings_repository.dart';
import 'package:parcel_khata/features/settings/domain/shop_settings.dart';

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late CustomerRepository customers;
  late OrderRepository orders;
  late OrderStatusService status;
  late SettingsRepository settings;
  late CustomerRiskQueries risk;
  var seq = 0;

  Future<String> newCustomer(String phone, [String name = 'C']) async =>
      (await customers.create(CustomerInput(name: name, phone: phone))).valueOrNull!.id;

  /// Creates an order for [cid] and walks it to [to] (delivered / failed).
  Future<String> order(String cid, OrderStatus to,
      {int daysAgo = 5, String? reason, PaymentType pay = PaymentType.cod}) async {
    seq++;
    final o = (await orders.create(OrderInput(
      customerId: cid,
      address: 'Road',
      orderDate: clock.now().subtract(Duration(days: daysAgo)),
      paymentType: pay,
      advance: pay == PaymentType.partialAdvance ? const Money.taka(100) : Money.zero,
      lines: [LineInput(name: 'X $seq', qty: 1, unitSell: const Money.taka(500), unitCost: const Money.taka(200))],
    )))
        .valueOrNull!;
    await db.customStatement(
      "UPDATE orders SET courier_id = (SELECT id FROM couriers LIMIT 1), consignment_no = 'CN$seq' WHERE id = '${o.id}'",
    );
    await status.changeStatus(o.id, to: OrderStatus.handedToCourier, at: clock.now());
    if (to != OrderStatus.handedToCourier) {
      await status.changeStatus(o.id, to: to, at: clock.now(), reason: reason);
    }
    return o.id;
  }

  setUp(() async {
    seq = 0;
    db = AppDatabase.memory();
    clock = FakeClock(DateTime(2026, 10, 15, 12));
    final ids = UuidV7(clock: clock);
    final audit = AuditWriter(db, ids, clock, 's');
    customers = CustomerRepository(db, ids, clock, audit, 's');
    final couriers = CourierRepository(db, ids, clock, audit, 's');
    settings = SettingsRepository(db, clock, 's');
    await settings.ensureShop();
    final ledger = LedgerWriter(db);
    orders = OrderRepository(db, ids, clock, audit, 's', couriers, settings, ledger);
    status = OrderStatusService(db, ids, clock, audit, 's', settings, ledger, StockService(db, clock));
    risk = CustomerRiskQueries(db, clock, settings);
    await couriers.create(const CourierInput(name: 'Pathao'));
  });
  tearDown(() => db.close());

  Set<RiskBadgeKind> kinds(CustomerRisk r) => r.badges.map((b) => b.kind).toSet();

  test('new customer then reliable after enough deliveries', () async {
    final c = await newCustomer('01712345678');
    expect(kinds(await risk.assess(c)), {RiskBadgeKind.newCustomer});
    for (var i = 0; i < 3; i++) {
      await order(c, OrderStatus.delivered, daysAgo: 20 + i);
    }
    final r = await risk.assess(c);
    expect(kinds(r), {RiskBadgeKind.reliable});
    expect(r.badge(RiskBadgeKind.reliable)!.orderIds, hasLength(3));
  });

  test('refused COD surfaces with the order behind it', () async {
    final c = await newCustomer('01712345678');
    final failed =
        await order(c, OrderStatus.deliveryFailed, daysAgo: 3, reason: 'customer_refused');
    final r = await risk.assess(c);
    expect(r.badge(RiskBadgeKind.refusedLastCod)!.orderIds, [failed]);
    expect(r.hasWarning, isTrue);
  });

  test('prepaid refusal is not a COD warning', () async {
    final c = await newCustomer('01712345678');
    await order(c, OrderStatus.deliveryFailed,
        daysAgo: 3, reason: 'customer_refused', pay: PaymentType.prepaid);
    expect(kinds(await risk.assess(c)), isNot(contains(RiskBadgeKind.refusedLastCod)));
  });

  test('thresholds come from settings', () async {
    final c = await newCustomer('01712345678');
    for (var i = 0; i < 3; i++) {
      await order(c, OrderStatus.delivered, daysAgo: 40 + i);
    }
    await order(c, OrderStatus.deliveryFailed, daysAgo: 150, reason: 'wrong_address');
    expect(kinds(await risk.assess(c)), isNot(contains(RiskBadgeKind.highReturnRate)));
    await settings.save((await settings.read()).copyWith(riskReturnRatePercent: 20));
    expect(kinds(await risk.assess(c)), contains(RiskBadgeKind.highReturnRate));
  });

  test('draft and cancelled orders are ignored', () async {
    final c = await newCustomer('01712345678');
    await orders.saveDraft(
        null,
        OrderInput(
            customerId: c,
            address: 'x',
            orderDate: clock.now(),
            lines: [LineInput(name: 'D', qty: 1, unitSell: const Money.taka(10))]));
    expect(kinds(await risk.assess(c)), {RiskBadgeKind.newCustomer});
  });

  test('blocklist and caution note persist and are audited', () async {
    final c = await newCustomer('01712345678');
    await customers.setBlocklisted(c, blocked: true, reason: 'fake orders');
    await customers.setRiskNote(c, '  call first ');
    final r = await risk.assess(c);
    expect(r.isBlocklisted, isTrue);
    expect(r.blocklistReason, 'fake orders');
    expect(r.riskNote, 'call first');
    await customers.setBlocklisted(c, blocked: false);
    final after = await risk.assess(c);
    expect(after.isBlocklisted, isFalse);
    expect(after.blocklistReason, isNull);
    final audit = await db.select(db.auditLog).get();
    expect(audit.map((a) => a.action), containsAll(['blocklist', 'unblocklist', 'risk_note']));
  });

  group('merge', () {
    test('unions blocklist + notes and moves order history', () async {
      final keep = await newCustomer('01712345678', 'Keep');
      final dup = await newCustomer('01898765432', 'Dup');
      await customers.setBlocklisted(dup, blocked: true, reason: 'refuses COD');
      await customers.setRiskNote(keep, 'slow payer');
      await customers.setRiskNote(dup, 'abusive on phone');
      final o = await order(dup, OrderStatus.deliveryFailed,
          daysAgo: 2, reason: 'customer_refused');

      expect((await customers.merge(survivorId: keep, duplicateId: dup)).isOk, isTrue);

      final k = (await customers.getById(keep))!;
      expect(k.isBlocklisted, isTrue);
      expect(k.blocklistReason, 'refuses COD');
      expect(k.riskNote, contains('slow payer'));
      expect(k.riskNote, contains('abusive on phone'));
      final r = await risk.assess(keep);
      expect(r.badge(RiskBadgeKind.refusedLastCod)!.orderIds, [o]);
    });

    test('survivor already blocklisted stays blocklisted', () async {
      final keep = await newCustomer('01712345678');
      final dup = await newCustomer('01898765432');
      await customers.setBlocklisted(keep, blocked: true, reason: 'x');
      await customers.merge(survivorId: keep, duplicateId: dup);
      expect((await customers.getById(keep))!.isBlocklisted, isTrue);
    });
  });

  test('settings round-trip with defaults for old payloads', () {
    final s = ShopSettings.decode('{"businessName":"A"}');
    expect(s.riskReturnRatePercent, 40);
    expect(s.riskMinOrders, 3);
    expect(s.riskRefusalRecencyDays, 90);
    final t = ShopSettings.decode(s.copyWith(riskMinOrders: 5).encode());
    expect(t.riskMinOrders, 5);
  });

  test('schema has the v9 customer risk columns', () async {
    final cols = await db.customSelect('PRAGMA table_info(customers)').get();
    final names = cols.map((r) => r.read<String>('name')).toSet();
    expect(names, containsAll(['risk_note', 'is_blocklisted', 'blocklist_reason']));
  });
}
