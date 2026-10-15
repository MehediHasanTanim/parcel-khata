import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_khata/core/db/app_database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.memory());
  tearDown(() => db.close());

  test('shops row round-trips', () async {
    final now = DateTime.utc(2026, 10, 15);
    await db.into(db.shops).insert(ShopsCompanion.insert(
          id: 'shop-1',
          shopId: 'shop-1',
          createdAt: now,
          updatedAt: now,
          name: const Value('Test Shop'),
        ));
    final row = await db.select(db.shops).getSingle();
    expect(row.name, 'Test Shop');
    expect(row.currency, 'BDT');
    expect(row.rowVersion, 1);
    expect(row.deletedAt, isNull);
  });

  test('foreign keys pragma is on', () async {
    final r = await db.customSelect('PRAGMA foreign_keys').getSingle();
    expect(r.data.values.first, 1);
  });
}
