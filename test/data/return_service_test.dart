import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_khata/core/db/app_database.dart';
import 'package:parcel_khata/core/db/audit_writer.dart';
import 'package:parcel_khata/core/ids/uuid_v7.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/core/time/clock.dart';
import 'package:parcel_khata/features/cod/application/ledger_writer.dart';
import 'package:parcel_khata/features/couriers/application/courier_repository.dart';
import 'package:parcel_khata/features/couriers/domain/charge_calculator.dart';
import 'package:parcel_khata/features/customers/application/customer_repository.dart';
import 'package:parcel_khata/features/orders/application/order_repository.dart';
import 'package:parcel_khata/features/orders/application/order_status_service.dart';
import 'package:parcel_khata/features/orders/domain/cod_amount_calculator.dart';
import 'package:parcel_khata/features/orders/domain/order_enums.dart';
import 'package:parcel_khata/features/orders/domain/order_input.dart';
import 'package:parcel_khata/features/products/application/product_repository.dart';
import 'package:parcel_khata/features/profit/application/profit_queries.dart';
import 'package:parcel_khata/features/profit/domain/profit_calculator.dart';
import 'package:parcel_khata/features/returns/application/return_service.dart';
import 'package:parcel_khata/features/returns/application/stock_service.dart';
import 'package:parcel_khata/features/settings/application/settings_repository.dart';
import 'package:parcel_khata/features/settings/domain/shop_settings.dart';

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late OrderRepository orders;
  late OrderStatusService status;
  late ReturnService returns;
  late ProductRepository products;
  late SettingsRepository settings;
  late ProfitQueries profitQueries;
  late String customerId;
  late String courierId;
  var seq = 0;

  Future<Order> handedOrder({List<LineInput>? lines, PaymentType type = PaymentType.cod}) async {
    seq++;
    final o = (await orders.create(OrderInput(
      customerId: customerId,
      address: 'Road',
      paymentType: type,
      deliveryCharge: const Money.taka(60),
      courierId: courierId,
      consignmentNo: 'CN$seq',
      zone: 'inside_dhaka',
      lines: lines ??
          const [
            LineInput(name: 'a', qty: 1, unitSell: Money.taka(500), unitCost: Money.taka(300)),
            LineInput(name: 'b', qty: 2, unitSell: Money.taka(250), unitCost: Money.taka(100)),
          ],
    )))
        .valueOrNull!;
    await status.changeStatus(o.id,
        to: OrderStatus.handedToCourier, at: clock.now().subtract(const Duration(days: 3)));
    return (await orders.getById(o.id))!;
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
    final ledger = LedgerWriter(db);
    final stock = StockService(db, clock);
    products = ProductRepository(db, ids, clock, audit, 's');
    orders = OrderRepository(db, ids, clock, audit, 's', couriers, settings, ledger);
    status = OrderStatusService(db, ids, clock, audit, 's', settings, ledger, stock);
    returns = ReturnService(db, ids, clock, audit, 's', ledger, status, stock, settings);
    profitQueries = ProfitQueries(db, ids, clock, 's', ledger);
    customerId = (await customers.create(const CustomerInput(name: 'A', phone: '01712345678')))
        .valueOrNull!
        .id;
    courierId = (await couriers.create(const CourierInput(
      name: 'Pathao',
      codFeePercentBp: 100,
      returnFeeMode: ReturnFeeMode.flat,
      returnFeeValue: 3000,
      rateRules: [RateRuleInput(zone: 'inside_dhaka', fee: Money.taka(60))],
    )))
        .valueOrNull!
        .id;
  });
  tearDown(() => db.close());

  test('order profit is cached on create and shows provisional', () async {
    final o = await handedOrder();
    // revenue 500 + 500 + 60 delivery, COGS 300 + 200, fees 60 + 10.6
    expect(o.profitState, 'provisional');
    expect(o.profit, 106000 - 50000 - 6000 - 1060);
  });

  test('missing cost -> incomplete; fixing the cost recomputes', () async {
    final o = await handedOrder(lines: const [
      LineInput(name: 'x', qty: 1, unitSell: Money.taka(1000)),
    ]);
    expect(o.profitState, 'incomplete');
    final missing = await profitQueries.missingCosts();
    expect(missing.single.order.id, o.id);
    await profitQueries.setLineCost(missing.single.line.id, const Money.taka(600));
    final fixed = (await orders.getById(o.id))!;
    expect(fixed.profitState, 'provisional');
    expect(await profitQueries.missingCosts(), isEmpty);
  });

  test('full return resellable: status returned, negative profit = fees', () async {
    final o = await handedOrder();
    await status.changeStatus(o.id, to: OrderStatus.deliveryFailed, reason: 'customer_refused');
    // auto return flow moved it to return_in_transit
    final r = await returns.receive(o.id, receivedAt: clock.now());
    expect(r.isOk, isTrue);
    final done = (await orders.getById(o.id))!;
    expect(done.status, 'returned');
    expect(done.codStatus, 'not_collected');
    expect(done.profitState, 'final');
    // delivery 60 + return fee 30, no revenue, COD fee not charged
    expect(done.profit, -9000);
    expect(r.valueOrNull!.record.lossAmount, 9000);
  });

  test('full return damaged adds goods cost to the loss', () async {
    final o = await handedOrder();
    await status.changeStatus(o.id, to: OrderStatus.deliveryFailed, reason: 'not_reachable');
    final lines = (await orders.detail(o.id))!.lines;
    final r = await returns.receive(o.id, conditions: {
      for (final l in lines) l.id: ReturnCondition.damaged,
    });
    expect(r.valueOrNull!.record.condition, 'damaged');
    // goods cost 300 + 2*100 = 500, plus 60 + 30 fees
    expect((await orders.getById(o.id))!.profit, -59000);
  });

  test('receive before initiated or in the future is rejected', () async {
    final o = await handedOrder();
    await status.changeStatus(o.id, to: OrderStatus.deliveryFailed, reason: 'not_reachable');
    final early = await returns.receive(o.id,
        receivedAt: clock.now().subtract(const Duration(days: 30)));
    expect(early.isOk, isFalse);
    final future = await returns.receive(o.id, receivedAt: clock.now().add(const Duration(days: 1)));
    expect(future.isOk, isFalse);
    expect((await orders.getById(o.id))!.status, 'return_in_transit');
  });

  test('partial return reduces collected COD, revenue and COGS', () async {
    final o = await handedOrder();
    await status.changeStatus(o.id, to: OrderStatus.delivered, at: clock.now());
    final lines = (await orders.detail(o.id))!.lines;
    final lineB = lines.firstWhere((l) => l.nameSnapshot == 'b');
    final init = await returns.initiate(o.id,
        full: false, reason: 'size_or_color_issue', lines: [ReturnQty(lineB.id, 1)]);
    expect(init.isOk, isTrue);
    final r = await returns.receive(o.id);
    expect(r.isOk, isTrue);
    final after = (await orders.getById(o.id))!;
    expect(after.status, 'delivered');
    // collected 1060 - returned 250
    expect(after.codCollected, 81000);
    // revenue 750 + 60; COGS 300+100; fees 60 + 10.6; a return happened so
    // the courier's flat 30 return fee now applies.
    expect(after.profit, 81000 - 40000 - 6000 - 1060 - 3000);
  });

  test('cannot partially return everything or twice', () async {
    final o = await handedOrder();
    await status.changeStatus(o.id, to: OrderStatus.delivered, at: clock.now());
    final lines = (await orders.detail(o.id))!.lines;
    final all = await returns.initiate(o.id,
        full: false,
        reason: 'other',
        lines: [for (final l in lines) ReturnQty(l.id, l.qty)]);
    expect(all.isOk, isFalse);
    final first = await returns.initiate(o.id,
        full: false, reason: 'other', lines: [ReturnQty(lines.first.id, 1)]);
    expect(first.isOk, isTrue);
    final again = await returns.initiate(o.id,
        full: false, reason: 'other', lines: [ReturnQty(lines.first.id, 1)]);
    expect(again.isOk, isFalse);
  });

  test('stock: out on handover, back when resellable return is received', () async {
    await settings.save(const ShopSettings(stockTrackingEnabled: true));
    final p = (await products.create(const ProductInput(
      name: 'Shirt',
      sellPrice: Money.taka(500),
      costPrice: Money.taka(300),
      stockQty: 10,
    )))
        .valueOrNull!;
    seq++;
    final o = (await orders.create(OrderInput(
      customerId: customerId,
      address: 'Road',
      courierId: courierId,
      consignmentNo: 'S$seq',
      zone: 'inside_dhaka',
      lines: [
        LineInput(
          name: 'Shirt',
          qty: 3,
          unitSell: const Money.taka(500),
          unitCost: const Money.taka(300),
          productId: p.id,
        ),
      ],
    )))
        .valueOrNull!;
    await status.changeStatus(o.id, to: OrderStatus.handedToCourier);
    expect((await products.getById(p.id))!.stockQty, 7);
    await status.changeStatus(o.id, to: OrderStatus.deliveryFailed, reason: 'other');
    await returns.receive(o.id);
    expect((await products.getById(p.id))!.stockQty, 10);
  });

  test('stock: damaged goods do not come back; negative stock is allowed', () async {
    await settings.save(const ShopSettings(stockTrackingEnabled: true));
    final p = (await products.create(const ProductInput(
      name: 'Bag',
      sellPrice: Money.taka(500),
      costPrice: Money.taka(300),
      stockQty: 1,
    )))
        .valueOrNull!;
    seq++;
    final o = (await orders.create(OrderInput(
      customerId: customerId,
      address: 'Road',
      courierId: courierId,
      consignmentNo: 'N$seq',
      zone: 'inside_dhaka',
      lines: [
        LineInput(
          name: 'Bag',
          qty: 3,
          unitSell: const Money.taka(500),
          unitCost: const Money.taka(300),
          productId: p.id,
        ),
      ],
    )))
        .valueOrNull!;
    await status.changeStatus(o.id, to: OrderStatus.handedToCourier);
    expect((await products.getById(p.id))!.stockQty, -2);
    await status.changeStatus(o.id, to: OrderStatus.deliveryFailed, reason: 'other');
    final line = (await orders.detail(o.id))!.lines.single;
    await returns.receive(o.id, conditions: {line.id: ReturnCondition.damaged});
    expect((await products.getById(p.id))!.stockQty, -2);
  });

  test('customer stats aggregate delivered/returned and profit', () async {
    final a = await handedOrder();
    await status.changeStatus(a.id, to: OrderStatus.delivered, at: clock.now());
    final b = await handedOrder();
    await status.changeStatus(b.id, to: OrderStatus.deliveryFailed, reason: 'other');
    final s = await profitQueries.customerStats(customerId);
    expect(s.orders, 2);
    expect(s.delivered, 1);
    expect(s.returned, 1);
    expect(s.deliveredPct, 50);
    expect(s.revenue.poisha, 106000);
  });

  test('sum of order profits equals aggregate of cached profit (no drift)', () async {
    for (var i = 0; i < 5; i++) {
      final o = await handedOrder();
      if (i.isEven) await status.changeStatus(o.id, to: OrderStatus.delivered, at: clock.now());
    }
    final rows = await orders.fetchPage(limit: 100);
    final sum = rows.fold(0, (s, r) => s + (r.order.profit ?? 0));
    final viaSql = await (db.selectOnly(db.orders)..addColumns([db.orders.profit.sum()])).getSingle();
    expect(viaSql.read(db.orders.profit.sum()), sum);
  });
}
