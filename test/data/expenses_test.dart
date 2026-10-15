import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_khata/core/db/app_database.dart';
import 'package:parcel_khata/core/db/audit_writer.dart';
import 'package:parcel_khata/core/ids/uuid_v7.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/core/time/clock.dart';
import 'package:parcel_khata/features/cod/application/ledger_writer.dart';
import 'package:parcel_khata/features/couriers/application/courier_repository.dart';
import 'package:parcel_khata/features/customers/application/customer_repository.dart';
import 'package:parcel_khata/features/expenses/application/campaign_repository.dart';
import 'package:parcel_khata/features/expenses/application/expense_repository.dart';
import 'package:parcel_khata/features/expenses/application/pnl_queries.dart';
import 'package:parcel_khata/features/expenses/domain/ad_allocator.dart';
import 'package:parcel_khata/features/expenses/domain/business_pnl.dart';
import 'package:parcel_khata/features/orders/application/order_repository.dart';
import 'package:parcel_khata/features/orders/application/order_status_service.dart';
import 'package:parcel_khata/features/orders/domain/cod_amount_calculator.dart';
import 'package:parcel_khata/features/orders/domain/order_enums.dart';
import 'package:parcel_khata/features/orders/domain/order_input.dart';
import 'package:parcel_khata/features/reports/domain/report_math.dart';
import 'package:parcel_khata/features/returns/application/stock_service.dart';
import 'package:parcel_khata/features/settings/application/settings_repository.dart';
import 'package:parcel_khata/features/settings/domain/shop_settings.dart';

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late OrderRepository orders;
  late OrderStatusService status;
  late CampaignRepository campaigns;
  late ExpenseRepository expenses;
  late PnlQueries pnl;
  late SettingsRepository settings;
  late String customerId;
  var seq = 0;

  Future<Order> order({
    List<String> tags = const ['eid'],
    int sell = 1000,
    int daysAgo = 1,
    bool delivered = true,
  }) async {
    seq++;
    final o = (await orders.create(OrderInput(
      customerId: customerId,
      address: 'Road',
      orderDate: clock.now().subtract(Duration(days: daysAgo)),
      deliveryCharge: const Money.taka(60),
      tags: tags,
      lines: [
        LineInput(
            name: 'Shirt $seq',
            qty: 1,
            unitSell: Money.taka(sell),
            unitCost: Money.taka(sell ~/ 2)),
      ],
    )))
        .valueOrNull!;
    if (delivered) {
      // Needs a courier + CN to be delivered: assign through the correction
      // path which only requires them on record.
      await db.customStatement(
        "UPDATE orders SET courier_id = (SELECT id FROM couriers LIMIT 1), consignment_no = 'CN$seq' WHERE id = '${o.id}'",
      );
      await status.changeStatus(o.id,
          to: OrderStatus.handedToCourier, at: clock.now().subtract(const Duration(days: 1)));
      await status.changeStatus(o.id, to: OrderStatus.delivered, at: clock.now());
    }
    return (await orders.getById(o.id))!;
  }

  CampaignInput eid({int spend = 1000, AllocationMode mode = AllocationMode.byCount}) =>
      CampaignInput(
        name: 'Eid sale',
        tag: ' EID ',
        start: DateTime(2026, 10),
        end: DateTime(2026, 10, 31),
        spend: Money.taka(spend),
        mode: mode,
      );

  setUp(() async {
    seq = 0;
    db = AppDatabase.memory();
    clock = FakeClock(DateTime(2026, 10, 15, 12));
    final ids = UuidV7(clock: clock);
    final audit = AuditWriter(db, ids, clock, 's');
    final customers = CustomerRepository(db, ids, clock, audit, 's');
    final couriers = CourierRepository(db, ids, clock, audit, 's');
    settings = SettingsRepository(db, clock, 's');
    await settings.ensureShop();
    final ledger = LedgerWriter(db);
    orders = OrderRepository(db, ids, clock, audit, 's', couriers, settings, ledger);
    status = OrderStatusService(db, ids, clock, audit, 's', settings, ledger, StockService(db, clock));
    campaigns = CampaignRepository(db, ids, clock, audit, 's', ledger);
    expenses = ExpenseRepository(db, ids, clock, audit, 's');
    pnl = PnlQueries(db, 's');
    customerId = (await customers.create(const CustomerInput(name: 'A', phone: '01712345678')))
        .valueOrNull!
        .id;
    await couriers.create(const CourierInput(name: 'Pathao'));
  });
  tearDown(() => db.close());

  group('tags', () {
    test('order tags are mirrored lower-cased into the link table', () async {
      final o = await order(tags: const ['EID', ' live ', 'eid'], delivered: false);
      final links = await (db.select(db.orderTagLinks)..where((l) => l.orderId.equals(o.id))).get();
      expect(links.map((l) => l.tag).toSet(), {'eid', 'live'});
      // Updating replaces them.
      await orders.update(o.id, OrderInput(
        customerId: customerId,
        address: 'Road',
        tags: const ['sale'],
        lines: const [LineInput(name: 'x', qty: 1, unitSell: Money.taka(10), unitCost: Money.taka(5))],
      ));
      final after = await (db.select(db.orderTagLinks)..where((l) => l.orderId.equals(o.id))).get();
      expect(after.map((l) => l.tag), ['sale']);
    });

    test('migration backfill copies tags_json into links', () async {
      final o = await order(tags: const ['Eid'], delivered: false);
      await db.customStatement('DELETE FROM order_tag_links');
      await db.customStatement('''
INSERT OR IGNORE INTO order_tag_links
  (id, shop_id, created_at, updated_at, row_version, order_id, tag)
SELECT lower(hex(randomblob(16))), o.shop_id, o.created_at, o.updated_at, 1, o.id,
       lower(trim(j.value))
FROM orders o, json_each(o.tags_json) j
WHERE o.deleted_at IS NULL AND trim(j.value) != ''
''');
      final links = await (db.select(db.orderTagLinks)..where((l) => l.orderId.equals(o.id))).get();
      expect(links.single.tag, 'eid');
    });
  });

  group('campaign allocation', () {
    test('spreads spend exactly and lowers each order profit by its share', () async {
      final a = await order();
      final b = await order();
      final c = await order();
      await order(tags: const ['other']); // not in the campaign
      final profitBefore = {for (final o in [a, b, c]) o.id: o.profit!};
      final camp = (await campaigns.create(eid(spend: 1000))).valueOrNull!;
      final r = await campaigns.allocate(camp.id);
      expect(r.valueOrNull!.orderCount, 3);

      var total = 0;
      for (final o in [a, b, c]) {
        final now = (await orders.getById(o.id))!;
        total += profitBefore[o.id]! - now.profit!;
      }
      expect(total, 100000); // ৳1,000 in poisha, exactly
      final charges = await (db.select(db.orderCharges)
            ..where((x) => x.type.equals('ad_allocation') & x.deletedAt.isNull()))
          .get();
      expect(charges, hasLength(3));
      expect(charges.map((x) => x.source).toSet(), {'campaign'});
    });

    test('is idempotent: applying twice changes nothing', () async {
      final a = await order();
      await order();
      final camp = (await campaigns.create(eid())).valueOrNull!;
      await campaigns.allocate(camp.id);
      final once = (await orders.getById(a.id))!.profit;
      await campaigns.allocate(camp.id);
      await campaigns.allocate(camp.id);
      expect((await orders.getById(a.id))!.profit, once);
      final live = await (db.select(db.orderCharges)
            ..where((x) => x.type.equals('ad_allocation') & x.deletedAt.isNull()))
          .get();
      expect(live, hasLength(2));
    });

    test('removing the campaign restores profit exactly', () async {
      final a = await order();
      final b = await order();
      final before = {a.id: a.profit, b.id: b.profit};
      final camp = (await campaigns.create(eid(spend: 777, mode: AllocationMode.byRevenue)))
          .valueOrNull!;
      await campaigns.allocate(camp.id);
      expect((await orders.getById(a.id))!.profit, isNot(before[a.id]));
      await campaigns.delete(camp.id);
      expect((await orders.getById(a.id))!.profit, before[a.id]);
      expect((await orders.getById(b.id))!.profit, before[b.id]);
    });

    test('removing a tag then re-applying drops that order from the share', () async {
      final a = await order();
      final b = await order();
      final camp = (await campaigns.create(eid(spend: 1000))).valueOrNull!;
      await campaigns.allocate(camp.id);
      final profitA = (await orders.getById(a.id))!.profit;
      await orders.update(b.id, OrderInput(
        customerId: customerId,
        address: 'Road',
        tags: const [],
        lines: const [LineInput(name: 'Shirt', qty: 1, unitSell: Money.taka(1000), unitCost: Money.taka(500))],
        deliveryCharge: const Money.taka(60),
      ), confirmed: true); // b is delivered; the line name changed
      await campaigns.allocate(camp.id);
      // Only `a` carries the tag now, so it takes the whole spend.
      expect(profitA! - (await orders.getById(a.id))!.profit!, 50000);
      final bCharges = await (db.select(db.orderCharges)
            ..where((x) =>
                x.orderId.equals(b.id) & x.type.equals('ad_allocation') & x.deletedAt.isNull()))
          .get();
      expect(bCharges, isEmpty);
    });

    test('date window and cancelled orders are excluded', () async {
      await order(daysAgo: 1);
      await order(daysAgo: 60); // outside Oct 1..31
      final camp = (await campaigns.create(eid())).valueOrNull!;
      final p = await campaigns.preview(camp.id);
      expect(p.orderCount, 1);
    });

    test('ad cost is not a courier deduction (net receivable unchanged)', () async {
      final a = await order();
      final net = a.netReceivable;
      final camp = (await campaigns.create(eid())).valueOrNull!;
      await campaigns.allocate(camp.id);
      expect((await orders.getById(a.id))!.netReceivable, net);
    });

    test('editing an applied campaign flags it for re-apply', () async {
      await order();
      final camp = (await campaigns.create(eid())).valueOrNull!;
      await campaigns.allocate(camp.id);
      expect(campaigns.needsReapply((await campaigns.getById(camp.id))!), isFalse);
      clock.advance(const Duration(minutes: 5));
      await campaigns.update(camp.id, eid(spend: 2000));
      expect(campaigns.needsReapply((await campaigns.getById(camp.id))!), isTrue);
    });
  });

  group('expenses', () {
    test('validation and CRUD', () async {
      final bad = await expenses.create(ExpenseInput(
          date: clock.now(), category: ExpenseCategory.rent, amount: Money.zero));
      expect(bad.isOk, isFalse);
      final e = (await expenses.create(ExpenseInput(
              date: clock.now(), category: ExpenseCategory.rent, amount: const Money.taka(5000))))
          .valueOrNull!;
      await expenses.update(
          e.id,
          ExpenseInput(
              date: clock.now(), category: ExpenseCategory.rent, amount: const Money.taka(6000)));
      expect((await expenses.getById(e.id))!.amount, 600000);
      await expenses.delete(e.id);
      expect(await expenses.watch().first, isEmpty);
    });

    test('recurring expenses create one copy per month, idempotently', () async {
      await expenses.create(ExpenseInput(
        date: DateTime(2026, 9, 31 > 30 ? 30 : 31),
        category: ExpenseCategory.rent,
        amount: const Money.taka(8000),
        recurringMonthly: true,
      ));
      expect(await expenses.materializeRecurring(), 1);
      expect(await expenses.materializeRecurring(), 0);
      final list = await expenses.watch(from: DateTime(2026, 10), to: DateTime(2026, 11)).first;
      expect(list, hasLength(1));
      expect(list.single.recurringSourceId, isNotNull);
      clock.advance(const Duration(days: 31));
      expect(await expenses.materializeRecurring(), 1);
    });
  });

  group('monthly P&L', () {
    final month = DatePeriod(DateTime(2026, 10), DateTime(2026, 11));

    test('equals the sum of cached order profits minus unallocated expenses', () async {
      final a = await order();
      final b = await order(tags: const ['x']);
      await order(delivered: false);
      await expenses.create(ExpenseInput(
          date: DateTime(2026, 10, 3), category: ExpenseCategory.rent, amount: const Money.taka(300)));
      await expenses.create(ExpenseInput(
          date: DateTime(2026, 10, 4), category: ExpenseCategory.salary, amount: const Money.taka(200)));
      final p = await pnl.compute(month);
      final rows = await db.select(db.orders).get();
      final cached = rows
          .where((o) => o.profitState != 'incomplete' && o.status != 'draft')
          .fold(0, (s, o) => s + (o.profit ?? 0));
      expect(p.orderProfit.poisha, cached);
      expect(p.unallocatedExpenses.poisha, 50000);
      expect(p.businessProfit.poisha, cached - 50000);
      expect(p.revenue - p.costsTotal, p.orderProfit);
      expect(a.id, isNotEmpty);
      expect(b.id, isNotEmpty);
    });

    test('allocated campaign ads are not subtracted twice', () async {
      await order();
      await order();
      final camp = (await campaigns.create(eid(spend: 1000))).valueOrNull!;
      await expenses.create(ExpenseInput(
        date: DateTime(2026, 10, 5),
        category: ExpenseCategory.ads,
        amount: const Money.taka(1000),
        campaignId: camp.id,
      ));
      // Not applied yet: the spend is a business expense.
      var p = await pnl.compute(month);
      final base = p.orderProfit;
      expect(p.unallocatedExpenses.poisha, 100000);
      expect(p.ads.poisha, 0);

      await campaigns.allocate(camp.id);
      p = await pnl.compute(month);
      // Now the spend is inside order profit, not a separate expense...
      expect(p.ads.poisha, 100000);
      expect(p.unallocatedExpenses.poisha, 0);
      // ...and business profit is unchanged: same money, counted once.
      expect(p.businessProfit.poisha, base.poisha - 100000);
    });

    test('period filter and incomplete orders', () async {
      await order(daysAgo: 1);
      await order(daysAgo: 60);
      final inMonth = await pnl.compute(month);
      expect(inMonth.orderCount, 1);
      // An order with a missing cost is reported but not summed.
      seq++;
      await orders.create(OrderInput(
        customerId: customerId,
        address: 'Road',
        orderDate: DateTime(2026, 10, 10),
        lines: const [LineInput(name: 'No cost', qty: 1, unitSell: Money.taka(100))],
      ));
      final p = await pnl.compute(month);
      expect(p.incompleteCount, 1);
      expect(p.orderCount, 1);
    });
  });

  group('packaging setting', () {
    test('default packaging is added only when enabled', () async {
      await settings.save(const ShopSettings(defaultPackagingCostTaka: 15));
      final withPack = await order(delivered: false);
      var charges = await (db.select(db.orderCharges)
            ..where((c) => c.orderId.equals(withPack.id) & c.type.equals('packaging')))
          .get();
      expect(charges, hasLength(1));

      await settings.save(const ShopSettings(
          defaultPackagingCostTaka: 15, applyPackagingToNewOrders: false));
      final without = await order(delivered: false);
      charges = await (db.select(db.orderCharges)
            ..where((c) => c.orderId.equals(without.id) & c.type.equals('packaging')))
          .get();
      expect(charges, isEmpty);
    });
  });
}
