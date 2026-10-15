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
import 'package:parcel_khata/features/orders/application/order_repository.dart';
import 'package:parcel_khata/features/orders/application/order_status_service.dart';
import 'package:parcel_khata/features/orders/domain/cod_amount_calculator.dart';
import 'package:parcel_khata/features/orders/domain/order_enums.dart';
import 'package:parcel_khata/features/orders/domain/order_input.dart';
import 'package:parcel_khata/features/profit/domain/profit_calculator.dart';
import 'package:parcel_khata/features/returns/application/exchange_service.dart';
import 'package:parcel_khata/features/returns/application/return_service.dart';
import 'package:parcel_khata/features/returns/application/stock_service.dart';
import 'package:parcel_khata/features/returns/domain/exchange_calculator.dart';
import 'package:parcel_khata/features/settings/application/settings_repository.dart';

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late OrderRepository orders;
  late OrderStatusService status;
  late ReturnService returns;
  late ExchangeService exchange;
  late String customerId;
  late Order original;
  late List<OrderLine> origLines;

  /// Delivered order: Shirt M 1000 (cost 600) + Cap 300 (cost 100), delivery 60.
  Future<Order> delivered() async {
    final o = (await orders.create(OrderInput(
      customerId: customerId,
      address: 'Road 1',
      orderDate: clock.now().subtract(const Duration(days: 4)),
      deliveryCharge: const Money.taka(60),
      lines: const [
        LineInput(name: 'Shirt M', qty: 1, unitSell: Money.taka(1000), unitCost: Money.taka(600)),
        LineInput(name: 'Cap', qty: 1, unitSell: Money.taka(300), unitCost: Money.taka(100)),
      ],
    )))
        .valueOrNull!;
    await db.customStatement(
      "UPDATE orders SET courier_id = (SELECT id FROM couriers LIMIT 1), consignment_no = 'CN1' WHERE id = '${o.id}'",
    );
    await status.changeStatus(o.id,
        to: OrderStatus.handedToCourier, at: clock.now().subtract(const Duration(days: 3)));
    await status.changeStatus(o.id, to: OrderStatus.delivered, at: clock.now());
    return (await orders.getById(o.id))!;
  }

  ExchangeRequest req({
    int replacement = 1000,
    ExchangePayer payer = ExchangePayer.seller,
    int delivery = 60,
    int returnShipping = 0,
  }) =>
      ExchangeRequest(
        originalOrderId: original.id,
        returned: [ReturnQty(origLines.firstWhere((l) => l.nameSnapshot == 'Shirt M').id, 1)],
        replacementLines: [
          LineInput(
              name: 'Shirt L',
              qty: 1,
              unitSell: Money.taka(replacement),
              unitCost: const Money.taka(600)),
        ],
        payer: payer,
        replacementDelivery: Money.taka(delivery),
        returnShipping: Money.taka(returnShipping),
      );

  setUp(() async {
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
    final stock = StockService(db, clock);
    status = OrderStatusService(db, ids, clock, audit, 's', settings, ledger, stock);
    returns = ReturnService(db, ids, clock, audit, 's', ledger, status, stock, settings);
    exchange = ExchangeService(db, ids, clock, audit, 's', orders, returns);
    customerId = (await customers.create(const CustomerInput(name: 'A', phone: '01712345678')))
        .valueOrNull!
        .id;
    await couriers.create(const CourierInput(name: 'Pathao'));
    original = await delivered();
    origLines = await (db.select(db.orderLines)..where((l) => l.orderId.equals(original.id))).get();
  });
  tearDown(() => db.close());

  Future<Order> reload(String id) async => (await orders.getById(id))!;

  test('same price, seller pays: prepaid-style replacement, linked both ways', () async {
    final r = (await exchange.create(req())).valueOrNull!;
    expect(r.preview.outcome.isEven, isTrue);
    expect(r.replacement.exchangeOfOrderId, original.id);
    expect(r.replacement.paymentType, 'prepaid');
    expect(r.replacement.codExpected, 0);
    expect(r.replacement.status, 'confirmed');
    expect(r.record.exchangeOrderId, r.replacement.id);
    expect(r.record.type, 'partial');

    final origEdits = await (db.select(db.orderEditLog)
          ..where((e) => e.orderId.equals(original.id) & e.field.equals('exchange')))
        .get();
    expect(origEdits.single.newValue, r.replacement.orderNo);
    final replEdits = await (db.select(db.orderEditLog)
          ..where((e) => e.orderId.equals(r.replacement.id) & e.field.equals('exchange')))
        .get();
    expect(replEdits.single.newValue, original.orderNo);

    final g = (await exchange.groupFor(r.replacement.id))!;
    expect(g.original.id, original.id);
    expect((await exchange.groupFor(original.id))!.replacement.id, r.replacement.id);
  });

  test('higher price: replacement COD is the difference', () async {
    final r = (await exchange.create(req(replacement: 1500))).valueOrNull!;
    expect(r.replacement.codExpected, const Money.taka(500).poisha);
    expect(r.replacement.paymentType, 'cod');
    expect(r.replacement.codOverridden, isTrue);
  });

  test('lower price: no COD, refund due is reported', () async {
    final r = (await exchange.create(req(replacement: 700))).valueOrNull!;
    expect(r.replacement.codExpected, 0);
    expect(r.preview.outcome.refundDue, const Money.taka(300));
  });

  test('customer pays courier: delivery charge billed and added to COD', () async {
    final r = (await exchange.create(
            req(payer: ExchangePayer.customer, returnShipping: 60)))
        .valueOrNull!;
    expect(r.replacement.deliveryChargeCustomer, const Money.taka(120).poisha);
    expect(r.replacement.codExpected, const Money.taka(120).poisha);
    expect(r.preview.outcome.businessShippingLoss, Money.zero);
  });

  test('original collection is untouched by the exchange return', () async {
    final before = (await reload(original.id)).codCollected;
    final r = (await exchange.create(req(replacement: 1500))).valueOrNull!;
    await returns.receive(original.id);
    final after = await reload(original.id);
    expect(after.codCollected, before);
    expect(r.record.exchangeOrderId, isNotNull);
  });

  test('damaged return: goods loss on the original, group net is the sum', () async {
    final shirt = origLines.firstWhere((l) => l.nameSnapshot == 'Shirt M');
    final r = (await exchange.create(req())).valueOrNull!;
    final receipt = await returns.receive(original.id,
        conditions: {shirt.id: ReturnCondition.damaged});
    expect(receipt.isOk, isTrue);
    final o = await reload(original.id);
    final g = (await exchange.groupFor(r.replacement.id))!;
    expect(g.net.poisha, (o.profit ?? 0) + ((await reload(r.replacement.id)).profit ?? 0));
    expect(g.original.profit, isNotNull);
    // Cap kept: 300 - 100; shirt written off: -600.
    expect(o.profit! <= const Money.taka(-400).poisha + const Money.taka(60).poisha,
        isTrue);
  });

  test('replacement cancelled: group is just the original', () async {
    final r = (await exchange.create(req(replacement: 1500))).valueOrNull!;
    await returns.receive(original.id);
    final c = await status.changeStatus(r.replacement.id,
        to: OrderStatus.cancelled, at: clock.now(), reason: 'customer_cancelled');
    expect(c.isOk, isTrue);
    final g = (await exchange.groupFor(original.id))!;
    expect(g.replacement.status, 'cancelled');
    expect(g.net.poisha, (await reload(original.id)).profit! + (g.replacement.profit ?? 0));
  });

  test('only a delivered order can be exchanged', () async {
    final fresh = (await orders.create(OrderInput(
      customerId: customerId,
      address: 'x',
      lines: const [LineInput(name: 'A', qty: 1, unitSell: Money.taka(100))],
    )))
        .valueOrNull!;
    final line =
        await (db.select(db.orderLines)..where((l) => l.orderId.equals(fresh.id))).getSingle();
    final res = await exchange.create(ExchangeRequest(
      originalOrderId: fresh.id,
      returned: [ReturnQty(line.id, 1)],
      replacementLines: const [LineInput(name: 'B', qty: 1, unitSell: Money.taka(100))],
    ));
    expect(res.isOk, isFalse);
  });

  test('second exchange on the same order is refused and creates nothing', () async {
    await exchange.create(req());
    final count = (await db.select(db.orders).get()).length;
    final again = await exchange.create(req());
    expect(again.isOk, isFalse);
    expect((await db.select(db.orders).get()).length, count);
  });

  test('exchanging every line works and keeps the original linked', () async {
    final r = (await exchange.create(ExchangeRequest(
      originalOrderId: original.id,
      returned: [for (final l in origLines) ReturnQty(l.id, l.qty)],
      replacementLines: const [
        LineInput(name: 'Set', qty: 1, unitSell: Money.taka(1300), unitCost: Money.taka(700)),
      ],
    )))
        .valueOrNull!;
    expect(r.replacement.codExpected, 0);
    expect(r.record.exchangeOrderId, r.replacement.id);
  });
}
