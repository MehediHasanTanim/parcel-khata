import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_khata/core/db/app_database.dart';
import 'package:parcel_khata/core/db/audit_writer.dart';
import 'package:parcel_khata/core/ids/uuid_v7.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/core/time/clock.dart';
import 'package:parcel_khata/features/cod/application/cod_queries.dart';
import 'package:parcel_khata/features/cod/application/ledger_writer.dart';
import 'package:parcel_khata/features/cod/application/payout_service.dart';
import 'package:parcel_khata/features/cod/domain/payout_reconciler.dart';
import 'package:parcel_khata/features/couriers/application/courier_repository.dart';
import 'package:parcel_khata/features/customers/application/customer_repository.dart';
import 'package:parcel_khata/features/orders/application/order_repository.dart';
import 'package:parcel_khata/features/orders/application/order_status_service.dart';
import 'package:parcel_khata/features/orders/domain/cod_amount_calculator.dart';
import 'package:parcel_khata/features/orders/domain/order_enums.dart';
import 'package:parcel_khata/features/orders/domain/order_input.dart';
import 'package:parcel_khata/features/settings/application/settings_repository.dart';

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late OrderRepository orders;
  late OrderStatusService status;
  late PayoutService payouts;
  late CodQueries queries;
  late String customerId;
  late String courierId;
  var seq = 0;

  /// COD order of ৳1,000 + ৳60 delivery = ৳1,060, delivered with the courier
  /// deducting delivery 60 + COD fee 1% (10.60) -> net 989.40.
  Future<Order> deliveredOrder({int daysAgo = 1}) async {
    seq++;
    final o = (await orders.create(OrderInput(
      customerId: customerId,
      address: 'Road',
      deliveryCharge: const Money.taka(60),
      courierId: courierId,
      consignmentNo: 'CN$seq',
      zone: 'inside_dhaka',
      lines: const [LineInput(name: 'x', qty: 1, unitSell: Money.taka(1000), unitCost: Money.taka(600))],
    )))
        .valueOrNull!;
    await status.changeStatus(o.id,
        to: OrderStatus.handedToCourier,
        at: clock.now().subtract(Duration(days: daysAgo + 1)));
    await status.changeStatus(o.id,
        to: OrderStatus.delivered, at: clock.now().subtract(Duration(days: daysAgo)));
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
    final settings = SettingsRepository(db, clock, 's');
    await settings.ensureShop();
    final ledger = LedgerWriter(db);
    orders = OrderRepository(db, ids, clock, audit, 's', couriers, settings);
    status = OrderStatusService(db, ids, clock, audit, 's', settings, ledger);
    payouts = PayoutService(db, ids, clock, audit, 's', ledger);
    queries = CodQueries(db, clock, 's');
    customerId = (await customers.create(const CustomerInput(name: 'A', phone: '01712345678')))
        .valueOrNull!
        .id;
    courierId = (await couriers.create(const CourierInput(
      name: 'Pathao',
      codFeePercentBp: 100,
      payoutCycleDays: 5,
      rateRules: [RateRuleInput(zone: 'inside_dhaka', fee: Money.taka(60))],
    )))
        .valueOrNull!
        .id;
  });
  tearDown(() => db.close());

  test('delivery caches net receivable and outstanding', () async {
    final o = await deliveredOrder();
    expect(o.codStatus, 'collected_by_courier');
    expect(o.codCollected, 106000);
    expect(o.netReceivable, 106000 - 6000 - 1060);
    expect(o.outstanding, o.netReceivable);
  });

  test('exact payout settles every selected order in one save', () async {
    final a = await deliveredOrder(daysAgo: 3);
    final b = await deliveredOrder(daysAgo: 2);
    final total = Money(a.outstanding! + b.outstanding!);
    final r = await payouts.recordPayout(RecordPayoutInput(
      courierId: courierId,
      totalReceived: total,
      selectedOrderIds: [a.id, b.id],
      allocations: [
        AllocationLine(a.id, Money(a.outstanding!)),
        AllocationLine(b.id, Money(b.outstanding!)),
      ],
    ));
    expect(r.isOk, isTrue);
    for (final id in [a.id, b.id]) {
      final o = (await orders.getById(id))!;
      expect(o.codStatus, 'settled');
      expect(o.outstanding, 0);
    }
  });

  test('shortfall must be handled; dispute flags and reverse restores', () async {
    final a = await deliveredOrder();
    final received = Money(a.outstanding! - 4000);
    final noPolicy = await payouts.recordPayout(RecordPayoutInput(
      courierId: courierId,
      totalReceived: received,
      selectedOrderIds: [a.id],
      allocations: [AllocationLine(a.id, received)],
    ));
    expect((noPolicy.failureOrNull! as PayoutFailure).error,
        ReconcileError.shortfallNeedsPolicy);

    final r = await payouts.recordPayout(RecordPayoutInput(
      courierId: courierId,
      totalReceived: received,
      selectedOrderIds: [a.id],
      allocations: [AllocationLine(a.id, received)],
      policy: ShortfallPolicy.dispute,
    ));
    var o = (await orders.getById(a.id))!;
    expect(o.codStatus, 'disputed');
    expect(o.outstanding, 4000);

    await payouts.reversePayout(r.valueOrNull!.id, 'wrong statement');
    o = (await orders.getById(a.id))!;
    expect(o.codStatus, 'collected_by_courier');
    expect(o.isDisputed, isFalse);
    expect(o.outstanding, a.outstanding);
  });

  test('write-off clears the balance and reversal removes it', () async {
    final a = await deliveredOrder();
    final received = Money(a.outstanding! - 4000);
    final r = await payouts.recordPayout(RecordPayoutInput(
      courierId: courierId,
      totalReceived: received,
      selectedOrderIds: [a.id],
      allocations: [AllocationLine(a.id, received)],
      policy: ShortfallPolicy.writeOff,
    ));
    var o = (await orders.getById(a.id))!;
    expect(o.codStatus, 'settled');
    expect(o.outstanding, 0);
    await payouts.reversePayout(r.valueOrNull!.id, 'mistake');
    o = (await orders.getById(a.id))!;
    expect(o.outstanding, a.outstanding);
    expect((await payouts.reversePayout(r.valueOrNull!.id, 'again')).isOk, isFalse);
  });

  test('payout may not mix couriers', () async {
    final a = await deliveredOrder();
    final r = await payouts.recordPayout(RecordPayoutInput(
      courierId: 'someone-else',
      totalReceived: Money(a.outstanding!),
      selectedOrderIds: [a.id],
      allocations: [AllocationLine(a.id, Money(a.outstanding!))],
    ));
    expect(r.isOk, isFalse);
  });

  test('actual fee overrides expected and changes outstanding', () async {
    final a = await deliveredOrder();
    await payouts.setActualCharge(a.id, 'delivery_fee', const Money.taka(80));
    final o = (await orders.getById(a.id))!;
    expect(o.netReceivable, 106000 - 8000 - 1060);
  });

  test('short collection edits the ledger and needs a reason', () async {
    final a = await deliveredOrder();
    expect((await payouts.recordCollectedAmount(a.id, const Money.taka(900), ' ')).isOk, isFalse);
    final r = await payouts.recordCollectedAmount(a.id, const Money.taka(900), 'customer paid less');
    expect(r.valueOrNull!.codCollected, 90000);
    expect(r.valueOrNull!.netReceivable, 90000 - 6000 - 1060);
  });

  test('courier pending total equals sum of order outstanding (F6 AC1)', () async {
    final a = await deliveredOrder(daysAgo: 7);
    final b = await deliveredOrder(daysAgo: 1);
    await payouts.recordPayout(RecordPayoutInput(
      courierId: courierId,
      totalReceived: const Money.taka(500),
      selectedOrderIds: [a.id, b.id],
      allocations: [AllocationLine(a.id, const Money.taka(500))],
      policy: ShortfallPolicy.allocate,
    ));
    final rows = await queries.pendingByCourier();
    final sum = (await orders.getById(a.id))!.outstanding! + (await orders.getById(b.id))!.outstanding!;
    expect(rows.single.total.poisha, sum);
    // a was delivered 7 days ago with a 5-day cycle -> overdue (AC5); b is not.
    expect(rows.single.overdueCount, 1);
  });

  test('ageing buckets', () async {
    await deliveredOrder(daysAgo: 2);
    await deliveredOrder(daysAgo: 5);
    await deliveredOrder(daysAgo: 10);
    await deliveredOrder(daysAgo: 20);
    final rows = await queries.ageing();
    expect(rows.map((r) => r.count), [1, 1, 1, 1]);
  });

  test('100-order payout saves in under 1s', () async {
    final ids = <String>[];
    var total = 0;
    for (var i = 0; i < 100; i++) {
      final o = await deliveredOrder();
      ids.add(o.id);
      total += o.outstanding!;
    }
    final lines = [
      for (final id in ids)
        AllocationLine(id, Money((await orders.getById(id))!.outstanding!)),
    ];
    final sw = Stopwatch()..start();
    final r = await payouts.recordPayout(RecordPayoutInput(
      courierId: courierId,
      totalReceived: Money(total),
      selectedOrderIds: ids,
      allocations: lines,
    ));
    sw.stop();
    expect(r.isOk, isTrue);
    expect(sw.elapsedMilliseconds, lessThan(1000));
  });
}
