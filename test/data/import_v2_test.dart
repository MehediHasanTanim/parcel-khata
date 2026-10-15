import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_khata/core/db/app_database.dart';
import 'package:parcel_khata/core/db/audit_writer.dart';
import 'package:parcel_khata/core/ids/uuid_v7.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/core/time/clock.dart';
import 'package:parcel_khata/features/backup/domain/csv.dart';
import 'package:parcel_khata/features/backup/domain/csv_import.dart';
import 'package:parcel_khata/features/backup/domain/xlsx_reader.dart';
import 'package:parcel_khata/features/cod/application/ledger_writer.dart';
import 'package:parcel_khata/features/couriers/application/courier_repository.dart';
import 'package:parcel_khata/features/customers/application/customer_repository.dart';
import 'package:parcel_khata/features/export/application/csv_import_service.dart';
import 'package:parcel_khata/features/orders/application/order_repository.dart';
import 'package:parcel_khata/features/orders/application/order_status_service.dart';
import 'package:parcel_khata/features/products/application/product_repository.dart';
import 'package:parcel_khata/features/returns/application/stock_service.dart';
import 'package:parcel_khata/features/settings/application/settings_repository.dart';

Uint8List _xlsx(List<List<Object?>> rows, {bool inline = false}) {
  final strings = <String>[];
  String cell(int r, int c, Object? v) {
    final ref = '${String.fromCharCode(65 + c)}${r + 1}';
    if (v == null) return '';
    if (v is num) return '<c r="$ref"><v>$v</v></c>';
    if (inline) return '<c r="$ref" t="inlineStr"><is><t>$v</t></is></c>';
    var i = strings.indexOf('$v');
    if (i < 0) {
      strings.add('$v');
      i = strings.length - 1;
    }
    return '<c r="$ref" t="s"><v>$i</v></c>';
  }

  final sheet = StringBuffer(
      '<?xml version="1.0" encoding="UTF-8"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>');
  for (var r = 0; r < rows.length; r++) {
    sheet.write('<row r="${r + 1}">');
    for (var c = 0; c < rows[r].length; c++) {
      sheet.write(cell(r, c, rows[r][c]));
    }
    sheet.write('</row>');
  }
  sheet.write('</sheetData></worksheet>');
  final ss = StringBuffer(
      '<?xml version="1.0" encoding="UTF-8"?><sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">');
  for (final s in strings) {
    ss.write('<si><t>$s</t></si>');
  }
  ss.write('</sst>');
  final a = Archive()
    ..addFile(ArchiveFile.string('xl/worksheets/sheet1.xml', sheet.toString()))
    ..addFile(ArchiveFile.string('xl/sharedStrings.xml', ss.toString()));
  return Uint8List.fromList(ZipEncoder().encode(a));
}

void main() {
  group('xlsx reader', () {
    test('reads shared strings, numbers and blanks into the CSV row model', () {
      final rows = XlsxReader.read(_xlsx([
        ['name', 'sell_price', 'stock'],
        ['শার্ট', 550.5, 12],
        ['Cap', 300.0, null],
      ]));
      expect(rows, [
        ['name', 'sell_price', 'stock'],
        ['শার্ট', '550.5', '12'],
        ['Cap', '300', ''],
      ]);
    });

    test('inline strings work and fully-blank rows are dropped', () {
      final rows = XlsxReader.read(_xlsx([
        ['a', 'b'],
        [null, null],
        ['x', 'y'],
      ], inline: true));
      expect(rows, [
        ['a', 'b'],
        ['x', 'y'],
      ]);
    });

    test('xlsx and csv of the same sheet produce identical plans', () {
      final csv = Csv.parse('name,sell_price,cost_price,stock\r\nShirt,500,300,10\r\nCap,250,,\r\n');
      final xl = XlsxReader.read(_xlsx([
        ['name', 'sell_price', 'cost_price', 'stock'],
        ['Shirt', 500, 300, 10],
        ['Cap', 250, null, null],
      ]));
      expect(xl, csv);
    });

    test('Excel serial dates parse', () {
      // 2026-01-15 is serial 46037.
      expect(CsvImportPlanner.parseDate('46037'), DateTime(2026, 1, 15));
    });
  });

  group('planners', () {
    test('products: validation, duplicates, defaults', () {
      final plan = CsvImportPlanner.products([
        ['Shirt', 'S1', '500', '300', '10', 'yes'],
        ['Shirt dup', 'S1', '500', '', '', ''],
        ['', 'S2', '10', '', '', ''],
        ['Bad price', 'S3', 'abc', '', '', ''],
        ['Bad stock', 'S4', '10', '', '-3', ''],
        ['Hat', '', '100', '', '', 'no'],
      ], {'name': 0, 'sku': 1, 'sell_price': 2, 'cost_price': 3, 'stock': 4, 'active': 5});
      expect(plan.rows.map((r) => r.name), ['Shirt', 'Hat']);
      expect(plan.duplicatesInFile, [2]);
      expect(plan.issues.map((i) => i.message),
          ['name_required', 'invalid_price', 'invalid_stock']);
      expect(plan.rows.first.stock, 10);
      expect(plan.rows.last.active, isFalse);
      expect(plan.rows.last.costPrice, isNull);
    });

    test('opening balances: courier + positive amount', () {
      final plan = CsvImportPlanner.openingBalances([
        ['Pathao', '1500', 'CN1', '2026-09-01', ''],
        ['', '100', '', '', ''],
        ['Steadfast', '0', '', '', ''],
        ['RedX', '200', '', 'garbage', ''],
      ], {'courier': 0, 'amount': 1, 'consignment_no': 2, 'delivered_date': 3, 'reference': 4});
      expect(plan.rows, hasLength(1));
      expect(plan.total, const Money.taka(1500));
      expect(plan.issues.map((i) => i.message),
          ['courier_required', 'invalid_amount', 'invalid_date']);
    });

    test('signature is stable across case/spacing and differs by headers', () {
      final a = ImportSignature.of(['Name', 'Sell Price']);
      expect(ImportSignature.of(['name ', 'sell_price']), a);
      expect(ImportSignature.of(['name', 'cost']), isNot(a));
    });
  });

  group('service', () {
    late AppDatabase db;
    late FakeClock clock;
    late CsvImportService svc;
    late CourierRepository couriers;
    late OrderRepository orders;
    late CustomerRepository customers;

    setUp(() async {
      db = AppDatabase.memory();
      clock = FakeClock(DateTime(2026, 10, 15, 12));
      final ids = UuidV7(clock: clock);
      final audit = AuditWriter(db, ids, clock, 's');
      customers = CustomerRepository(db, ids, clock, audit, 's');
      couriers = CourierRepository(db, ids, clock, audit, 's');
      final settings = SettingsRepository(db, clock, 's');
      await settings.ensureShop();
      final ledger = LedgerWriter(db);
      orders = OrderRepository(db, ids, clock, audit, 's', couriers, settings, ledger);
      final status = OrderStatusService(
          db, ids, clock, audit, 's', settings, ledger, StockService(db, clock));
      svc = CsvImportService(db, customers, orders, status, couriers,
          ProductRepository(db, ids, clock, audit, 's'), ids, clock, 's');
      await couriers.create(const CourierInput(name: 'Pathao'));
    });
    tearDown(() => db.close());

    Future<int> live(TableInfo<Table, Object?> t) async =>
        (await db.customSelect('SELECT COUNT(*) c FROM ${t.actualTableName} WHERE deleted_at IS NULL')
                .getSingle())
            .read<int>('c');

    test('products import creates rows, skips existing, and undo restores the count',
        () async {
      await ProductRepository(db, UuidV7(clock: clock), clock,
              AuditWriter(db, UuidV7(clock: clock), clock, 's'), 's')
          .create(const ProductInput(name: 'Existing', sellPrice: Money.taka(10), sku: 'E1'));
      final before = await live(db.products);
      final plan = CsvImportPlanner.products([
        ['Shirt', 'S1', '500', '300', '10', ''],
        ['Existing again', 'E1', '99', '', '', ''],
        ['Cap', 'S2', '250', '', '5', ''],
      ], {'name': 0, 'sku': 1, 'sell_price': 2, 'cost_price': 3, 'stock': 4, 'active': 5});
      final r = await svc.importProducts(plan, skipBadRows: false, fileName: 'p.csv');
      expect(r.imported, 2);
      expect(r.skippedExisting, 1);
      expect(await live(db.products), before + 2);
      expect(r.batchId, isNotNull);

      final u = await svc.undo(r.batchId!);
      expect(u.removed, 2);
      expect(await live(db.products), before);
      // Second undo is a no-op.
      expect((await svc.undo(r.batchId!)).removed, 0);
      final batch = await (db.select(db.importBatches)..where((b) => b.id.equals(r.batchId!))).getSingle();
      expect(batch.status, 'undone');
    });

    test('customers import round trip then undo restores prior counts', () async {
      await customers.create(const CustomerInput(name: 'Old', phone: '01712345678'));
      final before = await live(db.customers);
      final plan = CsvImportPlanner.customers([
        ['A', '01811111111'],
        ['B', '01911111111'],
      ], {'name': 0, 'phone': 1});
      final r = await svc.importCustomers(plan, skipBadRows: false);
      expect(await live(db.customers), before + 2);
      await svc.undo(r.batchId!);
      expect(await live(db.customers), before);
      // The phone slot is free again.
      expect((await customers.create(const CustomerInput(name: 'A2', phone: '01811111111'))).isOk,
          isTrue);
    });

    test('orders import undo removes orders and the customers it created', () async {
      final plan = CsvImportPlanner.orders([
        ['R1', '01833333333', 'Zed', '2026-09-01', 'Road', 'Shirt', '1', '500', '300'],
      ], {
        'order_no': 0,
        'customer_phone': 1,
        'customer_name': 2,
        'order_date': 3,
        'address': 4,
        'item_name': 5,
        'qty': 6,
        'unit_price': 7,
        'unit_cost': 8,
      });
      final beforeO = await live(db.orders);
      final beforeC = await live(db.customers);
      final r = await svc.importOrders(plan, skipBadRows: false);
      expect(r.imported, 1);
      expect(await live(db.orders), beforeO + 1);
      expect(await live(db.customers), beforeC + 1);
      final u = await svc.undo(r.batchId!);
      expect(u.removed, 2);
      expect(await live(db.orders), beforeO);
      expect(await live(db.customers), beforeC);
    });

    test('opening balance: owed COD shows as delivered unpaid parcels, profit neutral',
        () async {
      final plan = CsvImportPlanner.openingBalances([
        ['Pathao', '1500', 'CN-A', '2026-09-01', 'Sept'],
        ['pathao', '700', '', '', ''],
        ['Unknown', '100', '', '', ''],
      ], {'courier': 0, 'amount': 1, 'consignment_no': 2, 'delivered_date': 3, 'reference': 4});
      final r = await svc.importOpeningBalances(plan, skipBadRows: false);
      expect(r.imported, 2);
      expect(r.issues.map((i) => i.message), contains('unknown_courier'));

      final rows = await (db.select(db.orders)..where((o) => o.importBatchId.equals(r.batchId!)))
          .get();
      expect(rows, hasLength(2));
      for (final o in rows) {
        expect(o.status, 'delivered');
        expect(o.codCollected, o.codExpected);
        expect(o.outstanding, o.codExpected);
        expect(o.profit, 0);
        expect(o.tagsJson, contains('opening-balance'));
      }
      expect(rows.fold<int>(0, (s, o) => s + (o.outstanding ?? 0)),
          const Money.taka(2200).poisha);

      // The placeholder holder is hidden from the default customer list.
      expect(await customers.search(''), isEmpty);

      final u = await svc.undo(r.batchId!);
      expect(u.removed, greaterThanOrEqualTo(2));
      expect(await live(db.orders), 0);
    });

    test('undo keeps orders that already have a payout applied', () async {
      final plan = CsvImportPlanner.openingBalances([
        ['Pathao', '500', 'CN-P', '2026-09-01', ''],
      ], {'courier': 0, 'amount': 1, 'consignment_no': 2, 'delivered_date': 3, 'reference': 4});
      final r = await svc.importOpeningBalances(plan, skipBadRows: false);
      final o = await (db.select(db.orders)..where((x) => x.importBatchId.equals(r.batchId!))).getSingle();
      final payoutId = 'p1';
      await db.into(db.payouts).insert(PayoutsCompanion.insert(
            id: payoutId,
            shopId: 's',
            createdAt: clock.now(),
            updatedAt: clock.now(),
            courierId: o.courierId!,
            paidAt: clock.now(),
            method: const Value('bkash'),
            totalReceived: 50000,
          ));
      await db.into(db.payoutAllocations).insert(PayoutAllocationsCompanion.insert(
            id: 'a1',
            shopId: 's',
            createdAt: clock.now(),
            updatedAt: clock.now(),
            payoutId: payoutId,
            orderId: o.id,
            amountApplied: 50000,
          ));
      final u = await svc.undo(r.batchId!);
      expect(u.kept, greaterThanOrEqualTo(1));
      expect(await live(db.orders), 1);
    });

    test('saved mappings are stored per signature + kind and updated in place', () async {
      final sig = ImportSignature.of(['Product', 'Price']);
      expect(await svc.loadMapping(sig, 'products'), isNull);
      await svc.saveMapping(sig, 'products', {'name': 0, 'sell_price': 1});
      expect(await svc.loadMapping(sig, 'products'), {'name': 0, 'sell_price': 1});
      await svc.saveMapping(sig, 'products', {'name': 1, 'sell_price': 0});
      expect(await svc.loadMapping(sig, 'products'), {'name': 1, 'sell_price': 0});
      expect(await svc.loadMapping(sig, 'customers'), isNull);
      expect((await db.select(db.columnMappings).get()), hasLength(2 - 1));
    });

    test('an import that creates nothing leaves no history row', () async {
      final plan = CsvImportPlanner.products([
        ['Only', 'X', '10', '', '', ''],
      ], {'name': 0, 'sku': 1, 'sell_price': 2, 'cost_price': 3, 'stock': 4, 'active': 5});
      await svc.importProducts(plan, skipBadRows: false);
      final again = await svc.importProducts(plan, skipBadRows: false);
      expect(again.imported, 0);
      expect(again.batchId, isNull);
      expect(await db.select(db.importBatches).get(), hasLength(1));
    });
  });
}
