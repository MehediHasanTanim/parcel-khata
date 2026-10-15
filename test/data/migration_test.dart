import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_khata/core/db/app_database.dart';

/// Builds a database at the latest schema, then rewinds it to what an older
/// release left on disk (later tables/columns removed, user_version lowered)
/// with fixture rows, and reopens it so Drift runs the real upgrade steps.
void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('pk_migrate');
    file = File('${dir.path}/old.sqlite');
  });
  tearDown(() => dir.delete(recursive: true));

  AppDatabase open() => AppDatabase(NativeDatabase(file));

  Future<void> seedFixture(AppDatabase db) async {
    await db.customStatement(
        "INSERT INTO shops (id, shop_id, created_at, updated_at, name) VALUES ('s','s',0,0,'Shop')");
    await db.customStatement(
        "INSERT INTO customers (id, shop_id, created_at, updated_at, name, phone_primary, phone_normalized) "
        "VALUES ('c1','s',0,0,'Rahim','01712345678','01712345678')");
    await db.customStatement(
        "INSERT INTO orders (id, shop_id, created_at, updated_at, order_number, order_no, order_date, status, customer_id, tags_json) "
        "VALUES ('o1','s',0,0,1,'ORD-0001',0,'confirmed','c1','[\"Eid\",\"live\"]')");
    await db.customStatement(
        "INSERT INTO products (id, shop_id, created_at, updated_at, name, default_sell_price) "
        "VALUES ('p1','s',0,0,'Shirt',50000)");
  }

  Future<void> rewindTo(AppDatabase db, int version) async {
    await db.customStatement('PRAGMA foreign_keys = OFF');
    if (version < 11) {
      for (final t in ['import_batches', 'column_mappings']) {
        await db.customStatement('DROP TABLE IF EXISTS $t');
      }
      for (final c in [
        'ALTER TABLE customers DROP COLUMN import_batch_id',
        'ALTER TABLE orders DROP COLUMN import_batch_id',
        'ALTER TABLE products DROP COLUMN import_batch_id',
      ]) {
        await db.customStatement(c);
      }
    }
    if (version < 10) {
      await db.customStatement('ALTER TABLE orders DROP COLUMN exchange_of_order_id');
      await db.customStatement('ALTER TABLE return_records DROP COLUMN exchange_order_id');
    }
    if (version < 9) {
      for (final c in ['risk_note', 'is_blocklisted', 'blocklist_reason']) {
        await db.customStatement('ALTER TABLE customers DROP COLUMN $c');
      }
    }
    if (version < 8) {
      for (final t in ['expenses', 'campaigns', 'order_tag_links']) {
        await db.customStatement('DROP TABLE IF EXISTS $t');
      }
    }
    await db.customStatement('PRAGMA user_version = $version');
  }

  Future<Set<String>> columns(AppDatabase db, String table) async => {
        for (final r in await db.customSelect('PRAGMA table_info($table)').get())
          r.read<String>('name'),
      };

  Future<bool> tableExists(AppDatabase db, String t) async =>
      (await db
              .customSelect("SELECT name FROM sqlite_master WHERE type='table' AND name='$t'")
              .get())
          .isNotEmpty;

  test('7 -> latest keeps data and adds every later table/column', () async {
    var db = open();
    await db.customSelect('SELECT 1').get(); // create at latest
    await seedFixture(db);
    await rewindTo(db, 7);
    await db.close();

    db = open();
    expect((await db.customSelect('PRAGMA user_version').getSingle()).read<int>('user_version'),
        db.schemaVersion);

    // Data survived.
    expect((await db.select(db.customers).get()).single.name, 'Rahim');
    expect((await db.select(db.orders).get()).single.orderNo, 'ORD-0001');
    expect((await db.select(db.products).get()).single.name, 'Shirt');

    // v8: tag links backfilled lower-cased from tags_json.
    expect(await tableExists(db, 'campaigns'), isTrue);
    expect(await tableExists(db, 'expenses'), isTrue);
    final tags = await db.select(db.orderTagLinks).get();
    expect(tags.map((t) => t.tag).toSet(), {'eid', 'live'});

    // v9: risk columns with safe defaults.
    final c = (await db.select(db.customers).get()).single;
    expect(c.isBlocklisted, isFalse);
    expect(c.riskNote, isNull);

    // v10 / v11.
    expect(await columns(db, 'orders'), containsAll(['exchange_of_order_id', 'import_batch_id']));
    expect(await columns(db, 'return_records'), contains('exchange_order_id'));
    expect(await tableExists(db, 'import_batches'), isTrue);
    expect(await tableExists(db, 'column_mappings'), isTrue);
    await db.close();
  });

  test('8 -> 9 -> latest step by step', () async {
    var db = open();
    await db.customSelect('SELECT 1').get();
    await seedFixture(db);
    await db.customStatement(
        "INSERT INTO order_tag_links (id, shop_id, created_at, updated_at, order_id, tag) VALUES ('t1','s',0,0,'o1','keep')");
    await rewindTo(db, 8);
    await db.close();

    db = open();
    expect((await columns(db, 'customers')),
        containsAll(['risk_note', 'is_blocklisted', 'blocklist_reason', 'import_batch_id']));
    // Existing rows are untouched by later steps.
    expect((await db.select(db.orderTagLinks).get()).map((t) => t.tag), ['keep']);
    await db.close();
  });

  test('latest -> latest is a no-op and idempotent index creation holds', () async {
    var db = open();
    await db.customSelect('SELECT 1').get();
    await seedFixture(db);
    await db.close();
    db = open();
    expect((await db.select(db.customers).get()), hasLength(1));
    await db.close();
    db = open();
    expect((await db.select(db.orders).get()), hasLength(1));
    await db.close();
  });

  test('column mapping signature+kind stays unique after migration', () async {
    var db = open();
    await db.customSelect('SELECT 1').get();
    await rewindTo(db, 10);
    await db.close();
    db = open();
    await db.customStatement(
        "INSERT INTO column_mappings (id, shop_id, created_at, updated_at, signature, kind, mapping_json) VALUES ('m1','s',0,0,'abc','products','{}')");
    await expectLater(
      db.customStatement(
          "INSERT INTO column_mappings (id, shop_id, created_at, updated_at, signature, kind, mapping_json) VALUES ('m2','s',0,0,'abc','products','{}')"),
      throwsA(anything),
    );
    await db.close();
  });
}
