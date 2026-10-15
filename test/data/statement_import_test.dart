import 'package:drift/drift.dart' show BooleanExpressionOperators;
import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_khata/core/db/app_database.dart';
import 'package:parcel_khata/core/db/audit_writer.dart';
import 'package:parcel_khata/core/ids/uuid_v7.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/core/result/result.dart';
import 'package:parcel_khata/core/time/clock.dart';
import 'package:parcel_khata/features/cod/application/ledger_writer.dart';
import 'package:parcel_khata/features/cod/application/payout_service.dart';
import 'package:parcel_khata/features/cod/application/statement_import_service.dart';
import 'package:parcel_khata/features/cod/domain/payout_reconciler.dart';
import 'package:parcel_khata/features/cod/domain/statement_import.dart';
import 'package:parcel_khata/features/cod/domain/statement_parser.dart';
import 'package:parcel_khata/features/couriers/application/courier_repository.dart';
import 'package:parcel_khata/features/customers/application/customer_repository.dart';
import 'package:parcel_khata/features/orders/application/order_repository.dart';
import 'package:parcel_khata/features/orders/application/order_status_service.dart';
import 'package:parcel_khata/features/orders/domain/cod_amount_calculator.dart';
import 'package:parcel_khata/features/orders/domain/order_enums.dart';
import 'package:parcel_khata/features/orders/domain/order_input.dart';
import 'package:parcel_khata/features/returns/application/stock_service.dart';
import 'package:parcel_khata/features/settings/application/settings_repository.dart';

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late OrderRepository orders;
  late OrderStatusService status;
  late StatementImportService svc;
  late PayoutService payouts;
  late String courierId;
  late String customerId;
  var n = 0;

  /// COD 1000 order (items 940 + delivery 60), delivered with the CN.
  Future<Order> delivered(String cn, {int sell = 940}) async {
    n++;
    final o = (await orders.create(OrderInput(
      customerId: customerId,
      address: 'Road',
      courierId: courierId,
      consignmentNo: cn,
      deliveryCharge: const Money.taka(60),
      lines: [LineInput(name: 'Item $n', qty: 1, unitSell: Money.taka(sell), unitCost: const Money.taka(300))],
    )))
        .valueOrNull!;
    await status.changeStatus(o.id,
        to: OrderStatus.handedToCourier, at: clock.now().subtract(const Duration(days: 3)));
    await status.changeStatus(o.id, to: OrderStatus.delivered, at: clock.now());
    return (await orders.getById(o.id))!;
  }

  setUp(() async {
    n = 0;
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
    payouts = PayoutService(db, ids, clock, audit, 's', ledger);
    svc = StatementImportService(db, ids, clock, 's', ledger, payouts);
    customerId = (await customers.create(const CustomerInput(name: 'A', phone: '01712345678')))
        .valueOrNull!
        .id;
    courierId = (await couriers.create(const CourierInput(name: 'Pathao'))).valueOrNull!.id;
  });
  tearDown(() => db.close());

  const profile = StatementProfile(name: 'Generic', columns: {
    'cn': 'cn',
    'collected': 'collected',
    'delivery_fee': 'delivery',
    'cod_fee': 'cod fee',
    'net_payable': 'payable',
  });

  Future<List<MatchedRow>> review(List<List<String>> table) async {
    final parsed = StatementParser.parse(table, profile);
    return StatementMatcher.match(parsed.rows, await svc.loadOrders(courierId));
  }

  test('reconciles a statement: actual fees, one payout, orders settled, file remembered',
      () async {
    final a = await delivered('DT1');
    final b = await delivered('0042');
    final m = await review([
      ['CN', 'Collected', 'Delivery', 'COD Fee', 'Payable'],
      ['dt1', '1000', '60', '10', '930'],
      ['42', '1000', '70', '10', '920'],
    ]);
    expect(m.map((x) => x.outcome), [StatementOutcome.matched, StatementOutcome.matched]);

    final r = await svc.apply(
      courierId: courierId,
      decisions: [for (final x in m) StatementDecision(x)],
      contentHash: 'h1',
      rowCount: 2,
      fileName: 'sept.csv',
      reference: 'PAY-9',
    );
    expect(r.isOk, isTrue, reason: '${r.failureOrNull}');
    final out = r.valueOrNull!;
    expect(out.payout!.totalReceived, const Money.taka(1850).poisha);
    expect(out.payout!.reference, 'PAY-9');

    final ra = await orders.getById(a.id);
    final rb = await orders.getById(b.id);
    expect(ra!.outstanding, 0);
    expect(rb!.outstanding, 0);
    expect(ra.codStatus, 'settled');

    final charges = await (db.select(db.orderCharges)..where((c) => c.orderId.equals(b.id))).get();
    expect(charges.firstWhere((c) => c.type == 'delivery_fee').actualAmount,
        const Money.taka(70).poisha);
    expect(charges.firstWhere((c) => c.type == 'cod_fee').actualAmount,
        const Money.taka(10).poisha);

    // Re-importing the same file is refused as already applied.
    final again = await svc.apply(
      courierId: courierId,
      decisions: [for (final x in m) StatementDecision(x)],
      contentHash: 'h1',
      rowCount: 2,
    );
    expect(again.isOk, isFalse);
    expect(again.failureOrNull, isA<ConflictFailure>());
    expect((await db.select(db.payouts).get()), hasLength(1));
    expect((await svc.findApplied(courierId, 'h1'))!.fileName, 'sept.csv');
  });

  test('nothing is written when the settlement is rejected (shortfall w/o policy)', () async {
    final a = await delivered('DT1');
    final m = await review([
      ['CN', 'Collected', 'Delivery', 'Payable'],
      ['DT1', '1000', '60', '700'],
    ]);
    Future<int?> fee() async => (await (db.select(db.orderCharges)
              ..where((c) => c.orderId.equals(a.id) & c.type.equals('delivery_fee')))
            .getSingleOrNull())
        ?.actualAmount;
    final feeBefore = await fee();
    final r = await svc.apply(
      courierId: courierId,
      decisions: [StatementDecision(m.single)],
      contentHash: 'h2',
      rowCount: 1,
    );
    expect(r.isOk, isFalse);
    expect((r.failureOrNull as StatementApplyFailure).reconcileError,
        ReconcileError.shortfallNeedsPolicy);
    expect(await db.select(db.payouts).get(), isEmpty);
    expect(await db.select(db.statementImports).get(), isEmpty);
    expect(await fee(), feeBefore);
    expect(feeBefore, isNull);
  });

  test('shortfall with dispute policy flags the order', () async {
    final a = await delivered('DT1');
    final m = await review([
      ['CN', 'Collected', 'Payable'],
      ['DT1', '1000', '700'],
    ]);
    final r = await svc.apply(
      courierId: courierId,
      decisions: [StatementDecision(m.single)],
      contentHash: 'h3',
      rowCount: 1,
      policy: ShortfallPolicy.dispute,
    );
    expect(r.isOk, isTrue, reason: '${r.failureOrNull}');
    final o = await orders.getById(a.id);
    expect(o!.isDisputed, isTrue);
    expect(o.outstanding, greaterThan(0));
  });

  test('amount mismatch: adjusting collected needs a reason, then settles', () async {
    final a = await delivered('DT1');
    final m = await review([
      ['CN', 'Collected', 'Delivery', 'Payable'],
      ['DT1', '800', '60', '740'],
    ]);
    expect(m.single.outcome, StatementOutcome.amountMismatch);

    final noReason = await svc.apply(
      courierId: courierId,
      decisions: [StatementDecision(m.single, adjustCollected: true)],
      contentHash: 'h4',
      rowCount: 1,
    );
    expect((noReason.failureOrNull as StatementApplyFailure).error,
        StatementPlanError.reasonRequired);

    final ok = await svc.apply(
      courierId: courierId,
      decisions: [
        StatementDecision(m.single, adjustCollected: true, reason: 'customer short-paid')
      ],
      contentHash: 'h4',
      rowCount: 1,
    );
    expect(ok.isOk, isTrue, reason: '${ok.failureOrNull}');
    final o = await orders.getById(a.id);
    expect(o!.codCollected, const Money.taka(800).poisha);
    expect(o.outstanding, 0);
    final log = await (db.select(db.orderEditLog)..where((e) => e.orderId.equals(a.id))).get();
    expect(log.any((e) => e.field.startsWith('cod_collected')), isTrue);
  });

  test('unknown, duplicate and already-settled rows are classified from real data',
      () async {
    final a = await delivered('DT1');
    await delivered('DT2');
    // Settle DT1 first so it classifies as alreadySettled.
    final first = await review([
      ['CN', 'Collected', 'Payable'],
      ['DT1', '1000', '1000'],
    ]);
    expect(
        (await svc.apply(
          courierId: courierId,
          decisions: [StatementDecision(first.single)],
          contentHash: 'h5',
          rowCount: 1,
        ))
            .isOk,
        isTrue);
    expect((await orders.getById(a.id))!.outstanding, 0);

    final m = await review([
      ['CN', 'Collected', 'Payable'],
      ['DT1', '1000', '940'],
      ['DT2', '1000', '940'],
      ['dt2', '1000', '940'],
      ['NOPE', '5', '5'],
    ]);
    expect(m.map((x) => x.outcome), [
      StatementOutcome.alreadySettled,
      StatementOutcome.matched,
      StatementOutcome.duplicateInFile,
      StatementOutcome.unknownCn,
    ]);
  });

  test('another courier\'s parcels are never matched', () async {
    await delivered('DT1');
    final m = StatementMatcher.match(
      StatementParser.parse([
        ['CN'],
        ['DT1']
      ], profile)
          .rows,
      await svc.loadOrders('some-other-courier'),
    );
    expect(m.single.outcome, StatementOutcome.unknownCn);
  });

  test('profiles persist per courier and can be edited and deleted', () async {
    final id = await svc.saveProfile(profile.copyWith(name: 'Mine', toleranceTaka: 2),
        courierId: courierId);
    var saved = await svc.savedProfiles(courierId);
    expect(saved.single.profile.name, 'Mine');
    expect(saved.single.profile.toleranceTaka, 2);
    expect(saved.single.profile.columns['cn'], 'cn');
    await svc.saveProfile(profile.copyWith(name: 'Renamed'), id: id);
    saved = await svc.savedProfiles(courierId);
    expect(saved.single.profile.name, 'Renamed');
    expect(await svc.savedProfiles('other'), isEmpty);
    await svc.deleteProfile(id);
    expect(await svc.savedProfiles(courierId), isEmpty);
  });

  test('content hash is stable and sensitive', () {
    expect(StatementImportService.contentHash([1, 2, 3]),
        StatementImportService.contentHash([1, 2, 3]));
    expect(StatementImportService.contentHash([1, 2, 3]),
        isNot(StatementImportService.contentHash([1, 2, 4])));
  });
}
