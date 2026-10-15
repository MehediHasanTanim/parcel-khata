import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_khata/core/db/app_database.dart';
import 'package:parcel_khata/core/db/audit_writer.dart';
import 'package:parcel_khata/core/ids/uuid_v7.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/core/time/clock.dart';
import 'package:parcel_khata/features/backup/application/backup_service.dart';
import 'package:parcel_khata/features/backup/domain/backup_codec.dart';
import 'package:parcel_khata/features/backup/domain/csv.dart';
import 'package:parcel_khata/features/backup/domain/csv_import.dart';
import 'package:parcel_khata/features/cod/application/ledger_writer.dart';
import 'package:parcel_khata/features/couriers/application/courier_repository.dart';
import 'package:parcel_khata/features/customers/application/customer_repository.dart';
import 'package:parcel_khata/features/export/application/csv_exporter.dart';
import 'package:parcel_khata/features/export/application/csv_import_service.dart';
import 'package:parcel_khata/features/orders/application/order_repository.dart';
import 'package:parcel_khata/features/orders/application/order_status_service.dart';
import 'package:parcel_khata/features/orders/domain/cod_amount_calculator.dart';
import 'package:parcel_khata/features/orders/domain/order_input.dart';
import 'package:parcel_khata/features/reminders/application/attention_service.dart';
import 'package:parcel_khata/features/reminders/application/reminder_repository.dart';
import 'package:parcel_khata/features/reminders/domain/needs_attention.dart';
import 'package:parcel_khata/features/returns/application/stock_service.dart';
import 'package:parcel_khata/features/settings/application/settings_repository.dart';
import 'package:parcel_khata/features/settings/domain/shop_settings.dart';
import 'package:parcel_khata/features/templates/application/template_repository.dart';
import 'package:parcel_khata/features/templates/domain/message_templates.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePaths extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _FakePaths(this.dir);
  final Directory dir;

  @override
  Future<String?> getApplicationDocumentsPath() async => dir.path;

  @override
  Future<String?> getTemporaryPath() async => p.join(dir.path, 'tmp');
}

class _Env {
  _Env(this.db, this.clock, this.ids, this.audit, this.settings, this.ledger) {
    customers = CustomerRepository(db, ids, clock, audit, 's');
    couriers = CourierRepository(db, ids, clock, audit, 's');
    orders = OrderRepository(db, ids, clock, audit, 's', couriers, settings, ledger);
    status = OrderStatusService(db, ids, clock, audit, 's', settings, ledger, StockService(db, clock));
  }

  final AppDatabase db;
  final FakeClock clock;
  final UuidV7 ids;
  final AuditWriter audit;
  final SettingsRepository settings;
  final LedgerWriter ledger;
  late final CustomerRepository customers;
  late final CourierRepository couriers;
  late final OrderRepository orders;
  late final OrderStatusService status;

  static Future<_Env> create(AppDatabase db, FakeClock clock) async {
    final ids = UuidV7(clock: clock);
    final settings = SettingsRepository(db, clock, 's');
    await settings.ensureShop();
    return _Env(db, clock, ids, AuditWriter(db, ids, clock, 's'), settings, LedgerWriter(db));
  }

  Future<String> seedOrder({String phone = '01712345678', String name = 'Rahim'}) async {
    final c = await customers.findByPhone(phone) ??
        (await customers.create(CustomerInput(name: name, phone: phone))).valueOrNull!;
    final r = await orders.create(OrderInput(
      customerId: c.id,
      address: 'Road 1',
      deliveryCharge: const Money.taka(60),
      lines: const [LineInput(name: 'Shirt', qty: 2, unitSell: Money.taka(500), unitCost: Money.taka(300))],
    ));
    return r.valueOrNull!.id;
  }
}

void main() {
  late Directory dir;
  late FakeClock clock;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('pk_test');
    await Directory(p.join(dir.path, 'tmp')).create();
    PathProviderPlatform.instance = _FakePaths(dir);
    clock = FakeClock(DateTime(2026, 10, 15, 12));
  });
  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  test('CSV export -> import into a fresh DB keeps counts and totals (F14 AC1)', () async {
    final a = AppDatabase.memory();
    final ea = await _Env.create(a, clock);
    await ea.seedOrder();
    await ea.seedOrder(phone: '01898765432', name: 'Nusrat');
    await ea.seedOrder();
    final exp = CsvExporter(a, 's');
    final customersCsv = await exp.customers();
    final ordersCsv = await exp.orders();
    final linesCsv = await exp.orderLines();
    final totalA = (await a.select(a.orders).get()).fold(0, (s, o) => s + o.codExpected);

    final b = AppDatabase.memory();
    final eb = await _Env.create(b, clock);
    final svc = CsvImportService(b, eb.customers, eb.orders, eb.status, eb.couriers);

    final cRows = Csv.parse(customersCsv);
    final cPlan = CsvImportPlanner.customers(
        cRows.sublist(1), autoMapColumns(cRows.first, CsvColumns.customers));
    final cRes = await svc.importCustomers(cPlan, skipBadRows: false);
    expect(cRes.imported, 2);

    final oRows = Csv.parse(ordersCsv);
    final lRows = Csv.parse(linesCsv);
    final oPlan = CsvImportPlanner.orders(
      oRows.sublist(1),
      autoMapColumns(oRows.first, CsvColumns.orders),
      lineData: lRows.sublist(1),
      lineMap: autoMapColumns(lRows.first, CsvColumns.orderLines),
    );
    expect(oPlan.issues, isEmpty);
    final oRes = await svc.importOrders(oPlan, skipBadRows: false);
    expect(oRes.imported, 3);
    final totalB = (await b.select(b.orders).get()).fold(0, (s, o) => s + o.codExpected);
    expect(totalB, totalA);

    // Importing the same file again creates nothing new.
    final again = await svc.importOrders(oPlan, skipBadRows: false);
    expect(again.imported, 0);
    expect(again.skippedExisting, 3);
    await a.close();
    await b.close();
  });

  test('all-or-nothing import writes nothing when a row is bad', () async {
    final db = AppDatabase.memory();
    final e = await _Env.create(db, clock);
    final svc = CsvImportService(db, e.customers, e.orders, e.status, e.couriers);
    final plan = CsvImportPlanner.customers([
      ['Good', '01712345678'],
      ['Bad', 'nope'],
    ], {'name': 0, 'phone': 1});
    final r = await svc.importCustomers(plan, skipBadRows: false);
    expect(r.applied, isFalse);
    expect(await e.customers.search(''), isEmpty);
    final r2 = await svc.importCustomers(plan, skipBadRows: true);
    expect(r2.imported, 1);
    await db.close();
  });

  test('attention service builds the queue and honors snooze', () async {
    final db = AppDatabase.memory();
    final e = await _Env.create(db, clock);
    await e.seedOrder(); // confirmed, no CN -> to dispatch
    final reminders = ReminderRepository(db, e.ids, clock, 's');
    final svc = AttentionService(db, clock, 's', reminders, e.settings);
    var q = await svc.load();
    expect(q.map((i) => i.kind), contains(AttentionKind.toDispatch));
    await reminders.snooze(q.firstWhere((i) => i.kind == AttentionKind.toDispatch), 1);
    q = await svc.load();
    expect(q.where((i) => i.kind == AttentionKind.toDispatch), isEmpty);
    clock.advance(const Duration(days: 2));
    q = await svc.load();
    expect(q.where((i) => i.kind == AttentionKind.toDispatch), hasLength(1));
    await db.close();
  });

  test('backup reminder appears after the threshold and clears after a backup', () async {
    final db = AppDatabase.memory();
    final e = await _Env.create(db, clock);
    final svc = AttentionService(db, clock, 's', ReminderRepository(db, e.ids, clock, 's'), e.settings);
    expect(await svc.load(), isEmpty);
    clock.advance(const Duration(days: 8));
    expect((await svc.load()).single.kind, AttentionKind.backupDue);
    final s = await e.settings.read();
    await e.settings.save(s.copyWith(lastBackupAtMs: clock.now().millisecondsSinceEpoch));
    expect(await svc.load(), isEmpty);
    await db.close();
  });

  test('templates: default, custom, reset', () async {
    final db = AppDatabase.memory();
    final e = await _Env.create(db, clock);
    final t = TemplateRepository(db, e.ids, clock, 's');
    expect(await t.body(TemplateKind.dispatch, 'en'),
        MessageTemplates.defaultBody(TemplateKind.dispatch, 'en'));
    await t.save(TemplateKind.dispatch, 'en', 'Sent {cn}');
    expect(await t.body(TemplateKind.dispatch, 'en'), 'Sent {cn}');
    expect(await t.isCustomized(TemplateKind.dispatch, 'en'), isTrue);
    expect(await t.body(TemplateKind.dispatch, 'bn'),
        MessageTemplates.defaultBody(TemplateKind.dispatch, 'bn'));
    await t.reset(TemplateKind.dispatch, 'en');
    expect(await t.isCustomized(TemplateKind.dispatch, 'en'), isFalse);
    await db.close();
  });

  test('backup -> restore (replace) is lossless; wrong passphrase leaves data alone', () async {
    final liveFile = File(p.join(dir.path, 'parcel_khata.sqlite'));
    var db = AppDatabase(NativeDatabase(liveFile));
    final e = await _Env.create(db, clock);
    await e.seedOrder();
    await e.seedOrder(phone: '01898765432', name: 'Nusrat');
    final before = (await db.select(db.orders).get()).length;

    final svc = BackupService(db, clock, e.settings, () async => db.close());
    final file = await svc.create(passphrase: 'secret');
    expect(BackupCodec.isEncrypted(await file.readAsBytes()), isTrue);

    final preview = await svc.inspect(file, passphrase: 'secret');
    expect(preview.manifest.counts['orders'], before);
    await expectLater(
      svc.inspect(file, passphrase: 'nope'),
      throwsA(isA<BackupFormatException>()
          .having((x) => x.problem, 'problem', BackupProblem.wrongPassphrase)),
    );

    // Lose the data, then restore.
    await db.customStatement('DELETE FROM order_lines');
    await db.customStatement('DELETE FROM orders');
    expect((await db.select(db.orders).get()), isEmpty);
    final restored = BackupService(db, clock, e.settings, () async => db.close());
    await restored.restore(file, mode: RestoreMode.replace, passphrase: 'secret');

    db = AppDatabase(NativeDatabase(liveFile));
    expect((await db.select(db.orders).get()).length, before);
    expect((await db.select(db.orderLines).get()), isNotEmpty);
    await db.close();
  });

  test('restore (merge) adds missing rows and keeps local ones', () async {
    final live = AppDatabase.memory();
    final e = await _Env.create(live, clock);
    // A second device's database becomes the backup.
    final otherFile = File(p.join(dir.path, 'other.sqlite'));
    final other = AppDatabase(NativeDatabase(otherFile));
    final o = await _Env.create(other, clock);
    await o.seedOrder(phone: '01711111111', name: 'Other');
    await other.close();

    final mine = await e.seedOrder(phone: '01722222222', name: 'Mine');
    final svc = BackupService(live, clock, e.settings, () async {});
    // Build a backup from the other file via the codec directly.
    final bytes = BackupCodec.pack(
      db: await otherFile.readAsBytes(),
      attachments: {},
      schemaVersion: live.schemaVersion,
      counts: {'orders': 1},
      createdAt: clock.now(),
    );
    final bak = File(p.join(dir.path, 'x.pkb'))..writeAsBytesSync(bytes);
    await svc.restore(bak, mode: RestoreMode.merge);
    final orders = await live.select(live.orders).get();
    expect(orders.length, 2);
    expect(orders.any((x) => x.id == mine), isTrue);
    await live.close();
  });

  test('settings: backup/digest fields round trip', () {
    final s = const ShopSettings().copyWith(
      lastBackupAtMs: 123,
      digestEnabled: true,
      digestMinute: 1200,
      digestKinds: ['dispute'],
      batteryGuideShown: true,
    );
    final b = ShopSettings.decode(s.encode());
    expect(b.lastBackupAtMs, 123);
    expect(b.digestEnabled, isTrue);
    expect(b.digestMinute, 1200);
    expect(b.digestKinds, ['dispute']);
    expect(b.batteryGuideShown, isTrue);
  });
}
