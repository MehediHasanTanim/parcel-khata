import 'package:drift/drift.dart' show Variable;
import 'dart:async';

import 'package:parcel_khata/core/db/app_database.dart';
import 'package:parcel_khata/core/db/audit_writer.dart';
import 'package:parcel_khata/core/ids/uuid_v7.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/core/time/clock.dart';
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
import 'package:parcel_khata/features/returns/application/stock_service.dart';
import 'package:parcel_khata/features/settings/application/settings_repository.dart';
import 'package:parcel_khata/features/sync/application/sync_engine.dart';
import 'package:parcel_khata/features/sync/domain/sync_protocol.dart';

/// Transport wrapper that can inject faults.
class ChaosTransport implements SyncTransport {
  ChaosTransport(this.inner);

  final SyncTransport inner;

  /// Apply the push on the server but throw before the client sees the ack.
  bool loseNextAck = false;

  /// Throw before the push reaches the server.
  bool failNextPush = false;

  /// Throw on the next pull.
  bool failNextPull = false;

  /// Send every push twice.
  bool duplicatePush = false;

  /// Shuffle row order within each pulled page.
  bool shufflePull = false;

  /// Max rows per page (forces pagination).
  int? pageSize;

  var _shuffle = 0;

  @override
  Future<PushResult> push(String deviceId, List<Change> batch) async {
    if (failNextPush) {
      failNextPush = false;
      throw StateError('network down (push)');
    }
    var res = await inner.push(deviceId, batch);
    if (duplicatePush) res = await inner.push(deviceId, batch);
    if (loseNextAck) {
      loseNextAck = false;
      throw StateError('connection reset (ack lost)');
    }
    return res;
  }

  @override
  Future<PullResult> pull(int since, {int limit = 200}) async {
    if (failNextPull) {
      failNextPull = false;
      throw StateError('network down (pull)');
    }
    final r = await inner.pull(since, limit: pageSize ?? limit);
    if (!shufflePull || r.rows.length < 2) return r;
    final rows = [...r.rows];
    final k = (_shuffle++ % (rows.length - 1)) + 1;
    return PullResult([...rows.sublist(k), ...rows.sublist(0, k)], r.cursor, r.hasMore);
  }

  @override
  Future<Map<String, int>> summary() => inner.summary();
}

/// One virtual device: a real Drift database + repositories + sync engine.
class Dev {
  Dev._(this.name, this.db, this.clock, this.ids, this.engine, this.transport);

  final String name;
  final AppDatabase db;
  final FakeClock clock;
  final UuidV7 ids;
  final SyncEngine engine;
  final ChaosTransport transport;

  late final CustomerRepository customers;
  late final CourierRepository couriers;
  late final OrderRepository orders;
  late final OrderStatusService status;
  late final PayoutService payouts;
  late final LedgerWriter ledger;
  late final SettingsRepository settings;

  static Future<Dev> create(
    String name,
    SyncServer server, {
    required DateTime start,
    Principal principal = const Principal(userId: 'u', shopId: 's', role: 'owner'),
  }) async {
    final db = AppDatabase.memory();
    final clock = FakeClock(start);
    final ids = UuidV7(clock: clock);
    final engine = SyncEngine(db: db, clock: clock, ids: ids, shopId: 's');
    final d = Dev._(name, db, clock, ids, engine,
        ChaosTransport(InMemoryTransport(server, principal)));
    final audit = AuditWriter(db, ids, clock, 's');
    d.customers = CustomerRepository(db, ids, clock, audit, 's');
    d.couriers = CourierRepository(db, ids, clock, audit, 's');
    d.settings = SettingsRepository(db, clock, 's');
    await d.settings.ensureShop();
    d.ledger = LedgerWriter(db);
    d.orders = OrderRepository(db, ids, clock, audit, 's', d.couriers, d.settings, d.ledger);
    d.status = OrderStatusService(
        db, ids, clock, audit, 's', d.settings, d.ledger, StockService(db, clock));
    d.payouts = PayoutService(db, ids, clock, audit, 's', d.ledger);
    return d;
  }

  void tick([int seconds = 1]) => clock.advance(Duration(seconds: seconds));

  Future<SyncOutcome> sync() => engine.syncOnce(transport);

  Future<String> customer(String name, String phone) async =>
      (await customers.create(CustomerInput(name: name, phone: phone))).valueOrNull!.id;

  Future<String> courier(String name) async =>
      (await couriers.create(CourierInput(name: name))).valueOrNull!.id;

  /// COD 1000 order (940 + 60 delivery) with a CN; optionally delivered.
  Future<String> order(String customerId, String courierId, String cn,
      {bool delivered = false}) async {
    final o = (await orders.create(OrderInput(
      customerId: customerId,
      address: 'Road 1',
      courierId: courierId,
      consignmentNo: cn,
      deliveryCharge: const Money.taka(60),
      lines: [
        LineInput(name: 'Item $cn', qty: 1, unitSell: const Money.taka(940), unitCost: const Money.taka(300)),
      ],
    )))
        .valueOrNull!;
    if (delivered) {
      await status.changeStatus(o.id, to: OrderStatus.handedToCourier, at: clock.now());
      tick();
      await status.changeStatus(o.id, to: OrderStatus.delivered, at: clock.now());
    }
    return o.id;
  }

  Future<String> payFull(String courierId, String orderId) async {
    final o = await orders.getById(orderId);
    final r = await payouts.recordPayout(RecordPayoutInput(
      courierId: courierId,
      totalReceived: Money(o!.outstanding ?? 0),
      selectedOrderIds: [orderId],
      allocations: [AllocationLine(orderId, Money(o.outstanding ?? 0))],
      policy: ShortfallPolicy.allocate,
      allowOverpayment: true,
    ));
    return r.valueOrNull!.id;
  }

  Future<Map<String, Object?>?> row(String table, String id) async {
    final r = await db.customSelect('SELECT * FROM "$table" WHERE id = ?',
        variables: [Variable.withString(id)]).getSingleOrNull();
    return r?.data;
  }

  Future<int> count(String table, {String where = 'deleted_at IS NULL'}) async =>
      (await db.customSelect('SELECT COUNT(*) n FROM "$table" WHERE $where').getSingle())
          .read<int>('n');

  /// Synced columns of every row of every synced table, canonical order.
  Future<Map<String, Map<String, Map<String, Object?>>>> snapshot() async {
    final out = <String, Map<String, Map<String, Object?>>>{};
    for (final t in kSyncedTablesForTest) {
      final spec = kSyncSpecs[t]!;
      final rows = await db.customSelect('SELECT * FROM "$t"').get();
      out[t] = {
        for (final r in rows)
          r.read<String>('id'): {
            for (final e in r.data.entries)
              if (spec.carries(e.key)) e.key: e.value,
          },
      };
    }
    return out;
  }
}

// ignore: non_constant_identifier_names
const kSyncedTablesForTest = [
  'customers',
  'customer_addresses',
  'products',
  'product_variants',
  'couriers',
  'courier_rate_rules',
  'orders',
  'order_lines',
  'order_charges',
  'order_tag_links',
  'order_attachments',
  'order_status_events',
  'order_edit_log',
  'payouts',
  'payout_allocations',
  'return_records',
  'return_lines',
  'campaigns',
  'expenses',
];
