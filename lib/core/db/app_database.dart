import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:parcel_khata/core/db/tables.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

part 'app_database.g.dart';

const _customIndexes = [
  // One live customer per phone per shop (S1-01).
  'CREATE UNIQUE INDEX IF NOT EXISTS uq_customers_phone ON customers(shop_id, phone_normalized) WHERE deleted_at IS NULL',
  'CREATE INDEX IF NOT EXISTS ix_addresses_customer ON customer_addresses(customer_id)',
  'CREATE INDEX IF NOT EXISTS ix_variants_product ON product_variants(product_id)',
  'CREATE INDEX IF NOT EXISTS ix_rate_rules_courier ON courier_rate_rules(courier_id)',
  'CREATE INDEX IF NOT EXISTS ix_audit_entity ON audit_log(entity, entity_id)',
];

// Added in schema v3 (orders).
const _orderIndexes = [
  'CREATE UNIQUE INDEX IF NOT EXISTS uq_orders_number ON orders(shop_id, order_number)',
  'CREATE UNIQUE INDEX IF NOT EXISTS uq_orders_cn ON orders(courier_id, consignment_no) WHERE deleted_at IS NULL AND consignment_no IS NOT NULL',
  'CREATE INDEX IF NOT EXISTS ix_orders_status_date ON orders(shop_id, status, order_date DESC)',
  'CREATE INDEX IF NOT EXISTS ix_orders_date ON orders(shop_id, order_date DESC, id DESC)',
  'CREATE INDEX IF NOT EXISTS ix_orders_cod ON orders(shop_id, cod_status, delivered_at)',
  'CREATE INDEX IF NOT EXISTS ix_orders_customer ON orders(customer_id, order_date DESC)',
  'CREATE INDEX IF NOT EXISTS ix_order_lines_order ON order_lines(order_id)',
  'CREATE INDEX IF NOT EXISTS ix_order_charges_order ON order_charges(order_id)',
  'CREATE INDEX IF NOT EXISTS ix_order_events ON order_status_events(order_id, at)',
  'CREATE INDEX IF NOT EXISTS ix_order_edits ON order_edit_log(order_id, at)',
  'CREATE INDEX IF NOT EXISTS ix_order_attachments ON order_attachments(order_id)',
];

// Added in schema v4 (COD ledger & payouts).
const _ledgerIndexes = [
  'CREATE INDEX IF NOT EXISTS ix_payouts_courier ON payouts(courier_id, paid_at DESC)',
  'CREATE INDEX IF NOT EXISTS ix_alloc_order ON payout_allocations(order_id)',
  'CREATE INDEX IF NOT EXISTS ix_alloc_payout ON payout_allocations(payout_id)',
];

@DriftDatabase(tables: [
  Shops,
  Customers,
  CustomerAddresses,
  Products,
  ProductVariants,
  Couriers,
  CourierRateRules,
  AuditLog,
  Orders,
  OrderLines,
  OrderCharges,
  OrderStatusEvents,
  OrderEditLog,
  OrderAttachments,
  Payouts,
  PayoutAllocations,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// In-memory database for tests.
  AppDatabase.memory() : super(NativeDatabase.memory(setup: _setup));

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          for (final sql in [..._customIndexes, ..._orderIndexes, ..._ledgerIndexes]) {
            await customStatement(sql);
          }
        },
        onUpgrade: (m, from, to) async {
          // One step per schema version; never edit a shipped step.
          if (from < 2) {
            await m.createTable(customers);
            await m.createTable(customerAddresses);
            await m.createTable(products);
            await m.createTable(productVariants);
            await m.createTable(couriers);
            await m.createTable(courierRateRules);
            await m.createTable(auditLog);
            for (final sql in _customIndexes) {
              await customStatement(sql);
            }
          }
          if (from < 3) {
            await m.createTable(orders);
            await m.createTable(orderLines);
            await m.createTable(orderCharges);
            await m.createTable(orderStatusEvents);
            await m.createTable(orderEditLog);
            await m.createTable(orderAttachments);
            for (final sql in _orderIndexes) {
              await customStatement(sql);
            }
          }
          if (from < 4) {
            await m.addColumn(orders, orders.isDisputed);
            await m.addColumn(orders, orders.disputeNote);
            await m.createTable(payouts);
            await m.createTable(payoutAllocations);
            for (final sql in _ledgerIndexes) {
              await customStatement(sql);
            }
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  static void _setup(dynamic rawDb) {
    // ignore: avoid_dynamic_calls
    rawDb.execute('PRAGMA journal_mode = WAL');
  }
}

Future<File> databaseFile() async {
  // Android-first (see implementation plan §2); the Android plugin registers
  // itself as the platform implementation.
  final dir = await PathProviderPlatform.instance.getApplicationDocumentsPath();
  return File(p.join(dir!, 'parcel_khata.sqlite'));
}

AppDatabase openAppDatabase() {
  return AppDatabase(
    LazyDatabase(() async {
      final file = await databaseFile();
      return NativeDatabase.createInBackground(file, setup: AppDatabase._setup);
    }),
  );
}
