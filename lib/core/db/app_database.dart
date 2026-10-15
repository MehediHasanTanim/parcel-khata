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

// Added in schema v5 (returns).
const _returnIndexes = [
  'CREATE UNIQUE INDEX IF NOT EXISTS uq_return_order ON return_records(order_id) WHERE deleted_at IS NULL',
  'CREATE INDEX IF NOT EXISTS ix_return_lines ON return_lines(return_id)',
  'CREATE INDEX IF NOT EXISTS ix_return_lines_order_line ON return_lines(order_line_id)',
];

const _indexSelect = '''
SELECT o.id, o.order_no, COALESCE(c.name, ''),
  COALESCE(c.phone_normalized, '') || ' ' || COALESCE(c.phone_primary, ''),
  COALESCE(o.consignment_no, ''),
  COALESCE((SELECT group_concat(l.name_snapshot, ' ') FROM order_lines l
            WHERE l.order_id = o.id AND l.deleted_at IS NULL), ''),
  COALESCE(o.notes, '')
FROM orders o LEFT JOIN customers c ON c.id = o.customer_id
''';

const _indexInsert =
    'INSERT INTO search_index(order_id, order_no, customer_name, phone, cn, product_names, notes)';

// Added in schema v6: trigram FTS5 index (substring + Bangla friendly) kept in
// sync by triggers so no repository has to remember to reindex.
const _searchSql = [
  '''CREATE VIRTUAL TABLE IF NOT EXISTS search_index USING fts5(
  order_id UNINDEXED, order_no, customer_name, phone, cn, product_names, notes,
  tokenize = 'trigram')''',
  '''CREATE TRIGGER IF NOT EXISTS trg_si_orders_ai AFTER INSERT ON orders BEGIN
  $_indexInsert $_indexSelect WHERE o.id = NEW.id;
END''',
  '''CREATE TRIGGER IF NOT EXISTS trg_si_orders_au
AFTER UPDATE OF order_no, customer_id, consignment_no, notes ON orders BEGIN
  DELETE FROM search_index WHERE order_id = NEW.id;
  $_indexInsert $_indexSelect WHERE o.id = NEW.id;
END''',
  '''CREATE TRIGGER IF NOT EXISTS trg_si_orders_ad AFTER DELETE ON orders BEGIN
  DELETE FROM search_index WHERE order_id = OLD.id;
END''',
  '''CREATE TRIGGER IF NOT EXISTS trg_si_lines_ai AFTER INSERT ON order_lines BEGIN
  DELETE FROM search_index WHERE order_id = NEW.order_id;
  $_indexInsert $_indexSelect WHERE o.id = NEW.order_id;
END''',
  '''CREATE TRIGGER IF NOT EXISTS trg_si_lines_au
AFTER UPDATE OF name_snapshot, deleted_at ON order_lines BEGIN
  DELETE FROM search_index WHERE order_id = NEW.order_id;
  $_indexInsert $_indexSelect WHERE o.id = NEW.order_id;
END''',
  '''CREATE TRIGGER IF NOT EXISTS trg_si_lines_ad AFTER DELETE ON order_lines BEGIN
  DELETE FROM search_index WHERE order_id = OLD.order_id;
  $_indexInsert $_indexSelect WHERE o.id = OLD.order_id;
END''',
  '''CREATE TRIGGER IF NOT EXISTS trg_si_customers_au
AFTER UPDATE OF name, phone_primary, phone_normalized ON customers BEGIN
  DELETE FROM search_index WHERE order_id IN (SELECT id FROM orders WHERE customer_id = NEW.id);
  $_indexInsert $_indexSelect WHERE o.customer_id = NEW.id;
END''',
];

const _viewIndexes = [
  'CREATE INDEX IF NOT EXISTS ix_saved_views_shop ON saved_views(shop_id, created_at)',
];

// Added in schema v7 (reminders & templates).
const _reminderIndexes = [
  'CREATE UNIQUE INDEX IF NOT EXISTS uq_reminders_key ON reminders(shop_id, key) WHERE deleted_at IS NULL',
  'CREATE UNIQUE INDEX IF NOT EXISTS uq_templates_kind_lang ON message_templates(shop_id, kind, lang) WHERE deleted_at IS NULL',
];

// Added in schema v8 (expenses, campaigns, real tag links).
const _importIndexes = [
  'CREATE UNIQUE INDEX IF NOT EXISTS uq_column_mappings ON column_mappings(signature, kind)',
];

const _expenseIndexes = [
  'CREATE INDEX IF NOT EXISTS ix_expenses_date ON expenses(shop_id, date)',
  'CREATE UNIQUE INDEX IF NOT EXISTS uq_tag_links ON order_tag_links(order_id, tag) WHERE deleted_at IS NULL',
  'CREATE INDEX IF NOT EXISTS ix_tag_links_tag ON order_tag_links(tag)',
  'CREATE INDEX IF NOT EXISTS ix_campaigns_tag ON campaigns(shop_id, tag)',
  "CREATE INDEX IF NOT EXISTS ix_charges_campaign ON order_charges(note) WHERE type = 'ad_allocation'",
];

// Existing orders keep their tags in tags_json; mirror them into the link
// table (lower-cased) so campaigns can find them.
const _tagBackfill = '''
INSERT OR IGNORE INTO order_tag_links
  (id, shop_id, created_at, updated_at, row_version, order_id, tag)
SELECT lower(hex(randomblob(16))), o.shop_id, o.created_at, o.updated_at, 1, o.id,
       lower(trim(j.value))
FROM orders o, json_each(o.tags_json) j
WHERE o.deleted_at IS NULL AND trim(j.value) != ''
''';

@DriftDatabase(tables: [
  ImportBatches,
  ColumnMappings,
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
  ReturnRecords,
  ReturnLines,
  SavedViews,
  Reminders,
  MessageTemplateRows,
  Campaigns,
  Expenses,
  OrderTagLinks,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// In-memory database for tests.
  AppDatabase.memory() : super(NativeDatabase.memory(setup: _setup));

  @override
  int get schemaVersion => 11;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          for (final sql in [..._searchSql, ..._viewIndexes, ..._reminderIndexes, ..._expenseIndexes, ..._importIndexes]) {
            await customStatement(sql);
          }
          for (final sql in [..._customIndexes, ..._orderIndexes, ..._ledgerIndexes, ..._returnIndexes]) {
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
            // createTable above already uses the current definition, so only
            // databases that had `orders` before v4 need the new columns.
            if (from >= 3) {
              await m.addColumn(orders, orders.isDisputed);
              await m.addColumn(orders, orders.disputeNote);
            }
            await m.createTable(payouts);
            await m.createTable(payoutAllocations);
            for (final sql in _ledgerIndexes) {
              await customStatement(sql);
            }
          }
          if (from < 5) {
            await m.createTable(returnRecords);
            await m.createTable(returnLines);
            for (final sql in _returnIndexes) {
              await customStatement(sql);
            }
          }
          if (from < 6) {
            if (from >= 3) await m.addColumn(orders, orders.grossCollected);
            await m.createTable(savedViews);
            for (final sql in [..._searchSql, ..._viewIndexes]) {
              await customStatement(sql);
            }
            // Backfill the index for existing orders.
            await customStatement('$_indexInsert $_indexSelect');
          }
          if (from < 7) {
            await m.createTable(reminders);
            await m.createTable(messageTemplateRows);
            for (final sql in _reminderIndexes) {
              await customStatement(sql);
            }
          }
          if (from < 8) {
            await m.createTable(campaigns);
            await m.createTable(expenses);
            await m.createTable(orderTagLinks);
            for (final sql in _expenseIndexes) {
              await customStatement(sql);
            }
            await customStatement(_tagBackfill);
          }
          if (from < 9) {
            await m.addColumn(customers, customers.riskNote);
            await m.addColumn(customers, customers.isBlocklisted);
            await m.addColumn(customers, customers.blocklistReason);
          }
          if (from < 10) {
            await m.addColumn(orders, orders.exchangeOfOrderId);
            await m.addColumn(returnRecords, returnRecords.exchangeOrderId);
          }
          if (from < 11) {
            await m.addColumn(customers, customers.importBatchId);
            await m.addColumn(orders, orders.importBatchId);
            await m.addColumn(products, products.importBatchId);
            await m.createTable(importBatches);
            await m.createTable(columnMappings);
            for (final sql in _importIndexes) {
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
