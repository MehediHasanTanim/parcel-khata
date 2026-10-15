import 'dart:math';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_khata/core/db/app_database.dart';
import 'package:parcel_khata/core/db/audit_writer.dart';
import 'package:parcel_khata/core/ids/uuid_v7.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/core/time/clock.dart';
import 'package:parcel_khata/features/cod/application/cod_queries.dart';
import 'package:parcel_khata/features/cod/application/ledger_writer.dart';
import 'package:parcel_khata/features/couriers/application/courier_repository.dart';
import 'package:parcel_khata/features/customers/application/customer_repository.dart';
import 'package:parcel_khata/features/orders/application/order_repository.dart';
import 'package:parcel_khata/features/orders/application/order_status_service.dart';
import 'package:parcel_khata/features/orders/domain/cod_amount_calculator.dart';
import 'package:parcel_khata/features/orders/domain/order_enums.dart';
import 'package:parcel_khata/features/orders/domain/order_filter.dart';
import 'package:parcel_khata/features/orders/domain/order_input.dart';
import 'package:parcel_khata/features/profit/domain/profit_calculator.dart';
import 'package:parcel_khata/features/reports/application/dashboard_service.dart';
import 'package:parcel_khata/features/reports/application/report_queries.dart';
import 'package:parcel_khata/features/reports/domain/report_math.dart';
import 'package:parcel_khata/features/returns/application/stock_service.dart';
import 'package:parcel_khata/features/settings/application/settings_repository.dart';

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late OrderRepository orders;
  late OrderStatusService status;
  late ReportQueries reports;
  late CodQueries cod;
  late String customerId;
  late String courierId;
  var seq = 0;

  Future<Order> make({
    int sell = 1000,
    int daysAgo = 0,
    Channel channel = Channel.facebook,
    OrderStatus finalStatus = OrderStatus.confirmed,
    String name = 'Shirt',
    String? notes,
  }) async {
    seq++;
    final o = (await orders.create(OrderInput(
      customerId: customerId,
      address: 'House $seq, Dhanmondi, Dhaka',
      channel: channel,
      orderDate: clock.now().subtract(Duration(days: daysAgo)),
      courierId: courierId,
      consignmentNo: 'CN$seq',
      zone: 'inside_dhaka',
      notes: notes,
      deliveryCharge: const Money.taka(60),
      lines: [
        LineInput(name: name, qty: 1, unitSell: Money.taka(sell), unitCost: Money.taka(sell ~/ 2)),
      ],
    )))
        .valueOrNull!;
    final at = clock.now().subtract(Duration(days: max(0, daysAgo - 1)));
    switch (finalStatus) {
      case OrderStatus.delivered:
        await status.changeStatus(o.id, to: OrderStatus.handedToCourier, at: at);
        await status.changeStatus(o.id, to: OrderStatus.delivered, at: at);
      case OrderStatus.deliveryFailed:
        await status.changeStatus(o.id, to: OrderStatus.handedToCourier, at: at);
        await status.changeStatus(o.id,
            to: OrderStatus.deliveryFailed, at: at, reason: 'customer_refused');
      case OrderStatus.handedToCourier:
        await status.changeStatus(o.id, to: OrderStatus.handedToCourier, at: at);
      default:
        break;
    }
    return (await orders.getById(o.id))!;
  }

  setUp(() async {
    seq = 0;
    db = AppDatabase.memory();
    clock = FakeClock(DateTime(2026, 10, 15, 12));
    final ids = UuidV7(clock: clock);
    final audit = AuditWriter(db, ids, clock, 's');
    final customers = CustomerRepository(db, ids, clock, audit, 's');
    final couriers = CourierRepository(db, ids, clock, audit, 's');
    final settings = SettingsRepository(db, clock, 's');
    await settings.ensureShop();
    final ledger = LedgerWriter(db);
    orders = OrderRepository(db, ids, clock, audit, 's', couriers, settings, ledger);
    status = OrderStatusService(db, ids, clock, audit, 's', settings, ledger, StockService(db, clock));
    reports = ReportQueries(db, orders);
    cod = CodQueries(db, clock, 's');
    customerId = (await customers.create(const CustomerInput(name: 'Rahim Uddin', phone: '01712345678')))
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

  group('search', () {
    test('FTS: name fragment, phone suffix, CN, product, notes', () async {
      final a = await make(name: 'Blue Panjabi', notes: 'eid gift');
      await make(name: 'Red Saree');
      expect(await orders.searchIds('rahim'), hasLength(2));
      expect(await orders.searchIds('Panjabi'), {a.id});
      expect(await orders.searchIds('345678'), hasLength(2)); // phone suffix
      expect(await orders.searchIds('eid gift'), {a.id});
      expect(await orders.searchIds('${a.consignmentNo}'), contains(a.id));
    });

    test('short query falls back to LIKE; no match is empty', () async {
      await make(name: 'Blue Panjabi');
      expect(await orders.searchIds('Bl'), hasLength(1));
      expect(await orders.searchIds('zzzzzz'), isEmpty);
    });

    test('index follows edits and customer renames', () async {
      final a = await make(name: 'Old Name');
      await (db.update(db.orderLines)..where((l) => l.orderId.equals(a.id)))
          .write(const OrderLinesCompanion(nameSnapshot: Value('Brand New Item')));
      expect(await orders.searchIds('Brand New'), {a.id});
      expect(await orders.searchIds('Old Name'), isEmpty);
      await (db.update(db.customers))
          .write(const CustomersCompanion(name: Value('Karim Hossain')));
      expect(await orders.searchIds('Karim'), {a.id});
    });

    test('exact CN jumps to a single order', () async {
      final a = await make();
      await make();
      expect(await orders.exactOrderId(a.consignmentNo!), a.id);
      expect(await orders.exactOrderId('nope'), isNull);
      expect(await orders.exactOrderId(a.orderNo.toLowerCase()), a.id);
    });

    test('query is a filter too', () async {
      final a = await make(name: 'Unique Thing');
      await make();
      final page = await orders.fetchPage(filter: const OrderFilter(query: 'Unique'));
      expect(page.map((p) => p.order.id), [a.id]);
    });
  });

  group('SQL filter equals reference matcher', () {
    test('random filters over generated orders', () async {
      final rnd = Random(7);
      final statuses = [
        OrderStatus.confirmed,
        OrderStatus.handedToCourier,
        OrderStatus.delivered,
        OrderStatus.deliveryFailed,
      ];
      for (var i = 0; i < 40; i++) {
        await make(
          sell: 500 + rnd.nextInt(2000),
          daysAgo: rnd.nextInt(20),
          channel: Channel.values[rnd.nextInt(Channel.values.length)],
          finalStatus: statuses[rnd.nextInt(statuses.length)],
        );
      }
      final all = await db.select(db.orders).get();
      final now = clock.now();
      final filters = <OrderFilter>[
        OrderFilter(statuses: {OrderStatus.delivered}),
        OrderFilter(statuses: {OrderStatus.delivered, OrderStatus.deliveryFailed}),
        const OrderFilter(channel: Channel.whatsapp),
        OrderFilter(from: now.subtract(const Duration(days: 5)), to: now),
        OrderFilter(
            codStatuses: {CodStatus.collectedByCourier},
            deliveredOlderThanDays: 3),
        const OrderFilter(amountMinPoisha: 150000, amountMaxPoisha: 250000),
        const OrderFilter(profitSign: ProfitSign.profit),
        OrderFilter(profitStates: {ProfitState.provisional}),
        OrderFilter(
            statuses: {OrderStatus.delivered},
            channel: Channel.facebook,
            dispatchFrom: now.subtract(const Duration(days: 8))),
        const OrderFilter(area: 'dhanmondi'),
        const OrderFilter(hasReturn: true),
      ];
      for (final f in filters) {
        final expected = all
            .where((o) => OrderFilterMatcher.matches(
                  f,
                  OrderFacts(
                    status: OrderStatus.fromDb(o.status),
                    codStatus: CodStatus.fromDb(o.codStatus),
                    paymentType: PaymentType.fromDb(o.paymentType),
                    channel: Channel.fromDb(o.channel),
                    orderDate: o.orderDate,
                    totalPoisha: o.itemsTotal - o.discountTotal + o.deliveryChargeCustomer,
                    courierId: o.courierId,
                    customerId: o.customerId,
                    handedOverAt: o.handedOverAt,
                    deliveredAt: o.deliveredAt,
                    profit: o.profit,
                    profitState: ProfitState.values
                        .where((s) => s.dbValue == o.profitState)
                        .firstOrNull,
                    address: o.addressSnapshot,
                  ),
                  now: now,
                ))
            .map((o) => o.id)
            .toSet();
        final got = (await orders.fetchPage(filter: f, limit: 1000)).map((p) => p.order.id).toSet();
        expect(got, expected, reason: f.encode());
      }
    });
  });

  group('sorting and paging', () {
    test('amount sort and offset paging', () async {
      await make(sell: 500);
      await make(sell: 900);
      await make(sell: 700);
      final p1 = await orders.fetchPage(sort: OrderSort.amountHigh, limit: 2);
      final p2 = await orders.fetchPage(sort: OrderSort.amountHigh, limit: 2, offset: 2);
      final amounts = [...p1, ...p2].map((p) => p.order.itemsTotal).toList();
      expect(amounts, [90000, 70000, 50000]);
    });
  });

  group('dashboard consistency (F9 AC1, F8 AC4)', () {
    test('tile value equals the drill-down totals for the same filter', () async {
      await make(finalStatus: OrderStatus.delivered, daysAgo: 2);
      await make(finalStatus: OrderStatus.delivered, daysAgo: 4);
      await make(finalStatus: OrderStatus.handedToCourier, daysAgo: 1);
      await make(finalStatus: OrderStatus.deliveryFailed, daysAgo: 3);
      await make();
      final period = DatePeriod.resolve(PeriodPreset.thisMonth, clock.now());
      final dash = await DashboardService(orders, status, cod).load(period);
      for (final t in dash.tiles.values) {
        if (t.id == TileId.stuck) continue;
        final totals = await orders.totals(t.filter);
        expect(measureValue(t.measure, totals), t.value, reason: '${t.id}');
        final listed = await orders.fetchPage(filter: t.filter, limit: 1000);
        expect(listed.length, totals.count, reason: '${t.id} list vs count');
      }
    });

    test('pending tile equals sum of order outstanding in the list', () async {
      await make(finalStatus: OrderStatus.delivered);
      await make(finalStatus: OrderStatus.delivered);
      const f = OrderFilter(
          codStatuses: {CodStatus.collectedByCourier, CodStatus.partiallySettled});
      final totals = await orders.totals(f);
      final listed = await orders.fetchPage(filter: f, limit: 100);
      final sum = listed.fold(0, (s, r) => s + (r.order.outstanding ?? 0));
      expect(totals.outstanding, sum);
    });

    test('grouped report rows sum to plain totals for every dimension', () async {
      await make(finalStatus: OrderStatus.delivered, channel: Channel.whatsapp, daysAgo: 1);
      await make(finalStatus: OrderStatus.delivered, daysAgo: 2);
      await make(finalStatus: OrderStatus.deliveryFailed, daysAgo: 3);
      await make(sell: 700);
      const f = OrderFilter();
      final totals = await orders.totals(f);
      for (final by in [ReportGroup.day, ReportGroup.channel, ReportGroup.courier, ReportGroup.customer, ReportGroup.area]) {
        final rows = await reports.grouped(f, by);
        expect(rows.fold(0, (s, r) => s + r.orders), totals.count, reason: '$by orders');
        expect(rows.fold(0, (s, r) => s + r.profit), totals.profit, reason: '$by profit');
        expect(rows.fold(0, (s, r) => s + r.revenue), totals.revenue, reason: '$by revenue');
      }
    });

    test('best/worst orders are ordered by profit', () async {
      await make(sell: 5000, finalStatus: OrderStatus.delivered);
      await make(sell: 200, finalStatus: OrderStatus.delivered);
      final best = await orders.fetchPage(
          filter: OrderFilter(profitStates: {ProfitState.provisional, ProfitState.finalised}),
          sort: OrderSort.profitHigh,
          limit: 2);
      expect(best.first.order.profit! >= best.last.order.profit!, isTrue);
    });
  });

  group('reports', () {
    test('courier performance counts parcels and rates', () async {
      await make(finalStatus: OrderStatus.delivered, daysAgo: 2);
      await make(finalStatus: OrderStatus.delivered, daysAgo: 2);
      await make(finalStatus: OrderStatus.deliveryFailed, daysAgo: 2);
      final p = DatePeriod(DateTime(2026, 10), DateTime(2026, 11));
      final rows = await reports.courierPerformance(p);
      final r = rows.firstWhere((x) => x.courierId == courierId);
      expect(r.parcels, 3);
      expect(r.delivered, 2);
      expect(r.failedOrReturned, 1);
      expect(r.deliveredPct, closeTo(2 / 3, 1e-9));
      expect(r.totalFees, greaterThan(0));
    });

    test('daily summary has a row per day and matches totals', () async {
      await make(daysAgo: 0);
      await make(daysAgo: 1);
      await make(daysAgo: 1);
      final p = DatePeriod(DateTime(2026, 10, 13), DateTime(2026, 10, 16));
      final rows = await reports.daily(p);
      expect(rows, hasLength(3));
      expect(rows.fold(0, (s, r) => s + r.created), 3);
    });

    test('product report units and goods profit', () async {
      await make(name: 'Shirt', sell: 1000);
      await make(name: 'Shirt', sell: 1000);
      await make(name: 'Hat', sell: 400);
      final rows = await reports.grouped(const OrderFilter(), ReportGroup.product);
      final shirt = rows.firstWhere((r) => r.label == 'Shirt');
      expect(shirt.units, 2);
      expect(shirt.revenue, 200000);
      expect(shirt.profit, 100000);
    });
  });

  test('migration: v6 search index backfills', () async {
    final a = await make(name: 'Backfill Me');
    await db.customStatement('DELETE FROM search_index');
    expect(await orders.searchIds('Backfill'), isEmpty);
    // Same statement the v5 -> v6 upgrade runs.
    await db.customStatement(
      'INSERT INTO search_index(order_id, order_no, customer_name, phone, cn, product_names, notes) '
      "SELECT o.id, o.order_no, COALESCE(c.name,''), COALESCE(c.phone_normalized,''), "
      "COALESCE(o.consignment_no,''), COALESCE((SELECT group_concat(l.name_snapshot,' ') "
      "FROM order_lines l WHERE l.order_id=o.id AND l.deleted_at IS NULL),''), COALESCE(o.notes,'') "
      'FROM orders o LEFT JOIN customers c ON c.id=o.customer_id',
    );
    expect(await orders.searchIds('Backfill'), {a.id});
  });

  test('perf: dashboard totals over 20k orders stay under 1.5s', () async {
    final base = clock.now();
    await db.batch((b) {
      for (var i = 0; i < 20000; i++) {
        final delivered = i % 3 == 0;
        b.insert(
          db.orders,
          OrdersCompanion.insert(
            id: 'perf-$i',
            shopId: 's',
            createdAt: base,
            updatedAt: base,
            orderNumber: 100000 + i,
            orderNo: 'P-$i',
            orderDate: base.subtract(Duration(minutes: i)),
            status: delivered ? 'delivered' : 'confirmed',
            customerId: Value(customerId),
            courierId: Value(courierId),
            itemsTotal: const Value(100000),
            codExpected: const Value(100000),
            codStatus: Value(delivered ? 'collected_by_courier' : 'pending_collection'),
            outstanding: Value(delivered ? 90000 : null),
            profit: const Value(30000),
            profitState: const Value('provisional'),
            grossCollected: const Value(106000),
          ),
        );
      }
    });
    final sw = Stopwatch()..start();
    final period = DatePeriod.resolve(PeriodPreset.thisMonth, base);
    await DashboardService(orders, status, cod).load(period);
    sw.stop();
    expect(sw.elapsedMilliseconds, lessThan(1500));
    final s2 = Stopwatch()..start();
    await orders.searchIds('P-19999');
    expect(s2.elapsedMilliseconds, lessThan(300));
  });
}
