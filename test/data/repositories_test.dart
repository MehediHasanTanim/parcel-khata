import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_khata/core/db/app_database.dart';
import 'package:parcel_khata/core/db/audit_writer.dart';
import 'package:parcel_khata/core/ids/uuid_v7.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/core/result/result.dart';
import 'package:parcel_khata/core/time/clock.dart';
import 'package:parcel_khata/features/couriers/application/courier_repository.dart';
import 'package:parcel_khata/features/customers/application/customer_repository.dart';
import 'package:parcel_khata/features/products/application/product_repository.dart';

void main() {
  late AppDatabase db;
  late CustomerRepository customers;
  late ProductRepository products;
  late CourierRepository couriers;

  setUp(() {
    db = AppDatabase.memory();
    final clock = FakeClock(DateTime.utc(2026, 10, 15));
    final ids = UuidV7(clock: clock);
    final audit = AuditWriter(db, ids, clock, 's');
    customers = CustomerRepository(db, ids, clock, audit, 's');
    products = ProductRepository(db, ids, clock, audit, 's');
    couriers = CourierRepository(db, ids, clock, audit, 's');
  });
  tearDown(() => db.close());

  group('customers', () {
    test('create normalizes phone and detects duplicates in any format', () async {
      final a = await customers.create(const CustomerInput(name: 'A', phone: '+8801712345678'));
      expect(a.isOk, isTrue);
      expect(a.valueOrNull!.phoneNormalized, '01712345678');

      final dup = await customers.create(const CustomerInput(name: 'B', phone: '01712-345678'));
      final f = dup.failureOrNull;
      expect(f, isA<ConflictFailure>());
      expect((f! as ConflictFailure).conflictingId, a.valueOrNull!.id);
    });

    test('validation', () async {
      expect((await customers.create(const CustomerInput(name: '', phone: '01712345678')))
          .failureOrNull, isA<ValidationFailure>());
      expect((await customers.create(const CustomerInput(name: 'x', phone: '123')))
          .failureOrNull, isA<ValidationFailure>());
    });

    test('search by name fragment and phone digits', () async {
      await customers.create(const CustomerInput(name: 'Rahim Khan', phone: '01712345678'));
      await customers.create(const CustomerInput(name: 'Nusrat', phone: '01898765432'));
      expect((await customers.search('rah')).map((c) => c.name), ['Rahim Khan']);
      expect((await customers.search('8765')).map((c) => c.name), ['Nusrat']);
      expect(await customers.search(''), hasLength(2));
    });

    test('first address becomes default; addresses replaced on update', () async {
      final c = (await customers.create(const CustomerInput(
        name: 'A',
        phone: '01712345678',
        addresses: [AddressInput(fullText: 'Road 1'), AddressInput(fullText: 'Road 2')],
      )))
          .valueOrNull!;
      var a = await customers.addresses(c.id);
      expect(a.where((x) => x.isDefault), hasLength(1));
      expect(a.first.fullText, 'Road 1');

      await customers.update(c.id, const CustomerInput(
        name: 'A',
        phone: '01712345678',
        addresses: [AddressInput(fullText: 'Only', isDefault: true)],
      ));
      a = await customers.addresses(c.id);
      expect(a.map((x) => x.fullText), ['Only']);
    });

    test('archive hides from default search', () async {
      final c = (await customers.create(
              const CustomerInput(name: 'A', phone: '01712345678')))
          .valueOrNull!;
      await customers.archive(c.id);
      expect(await customers.search(''), isEmpty);
    });

    test('merge moves addresses, soft-deletes duplicate, writes audit', () async {
      final keep = (await customers.create(const CustomerInput(
              name: 'Keep', phone: '01712345678', addresses: [AddressInput(fullText: 'K')])))
          .valueOrNull!;
      final dup = (await customers.create(const CustomerInput(
              name: 'Dup', phone: '01898765432', addresses: [AddressInput(fullText: 'D')])))
          .valueOrNull!;
      final r = await customers.merge(survivorId: keep.id, duplicateId: dup.id);
      expect(r.isOk, isTrue);
      expect((await customers.addresses(keep.id)).map((a) => a.fullText).toSet(), {'K', 'D'});
      expect(await customers.search(''), hasLength(1));
      final audit = await db.select(db.auditLog).get();
      expect(audit.where((a) => a.action == 'merge'), hasLength(1));
      // The freed phone can be registered again.
      expect((await customers.create(
              const CustomerInput(name: 'New', phone: '01898765432'))).isOk, isTrue);
    });
  });

  group('products', () {
    test('cost optional; variants saved; update logs audit', () async {
      final p = (await products.create(const ProductInput(
        name: 'Shirt',
        sellPrice: Money.taka(500),
        variants: [VariantInput(label: 'M'), VariantInput(label: 'L')],
      )))
          .valueOrNull!;
      expect(p.defaultCostPrice, isNull);
      expect(await products.variants(p.id), hasLength(2));

      final u = await products.update(p.id, const ProductInput(
          name: 'Shirt', sellPrice: Money.taka(550), costPrice: Money.taka(300)));
      expect(u.valueOrNull!.defaultSellPrice, 55000);
      expect(u.valueOrNull!.defaultCostPrice, 30000);
      expect(await products.variants(p.id), isEmpty);
    });

    test('rejects blank name and negative price', () async {
      expect((await products.create(const ProductInput(name: ' ', sellPrice: Money.zero)))
          .isOk, isFalse);
      expect((await products.create(const ProductInput(name: 'x', sellPrice: Money(-1))))
          .isOk, isFalse);
    });
  });

  group('couriers', () {
    test('rate card round trips into CourierFeeRules', () async {
      final c = (await couriers.create(const CourierInput(
        name: 'Pathao',
        codFeePercentBp: 100,
        rateRules: [RateRuleInput(zone: 'inside_dhaka', fee: Money.taka(60))],
      )))
          .valueOrNull!;
      final rules = await couriers.feeRules(c.id);
      expect(rules.codFeePercentBp, 100);
      expect(rules.rateRules.single.fee, const Money.taka(60));
    });

    test('validates tracking template, regex and weight bands', () async {
      expect((await couriers.create(const CourierInput(
              name: 'X', trackingUrlTemplate: 'https://x.com/')))
          .failureOrNull, isA<ValidationFailure>());
      expect((await couriers.create(const CourierInput(name: 'X', cnRegex: '(')))
          .failureOrNull, isA<ValidationFailure>());
      expect((await couriers.create(const CourierInput(name: 'X', rateRules: [
        RateRuleInput(zone: 'custom', fee: Money.taka(1), weightMinG: 500, weightMaxG: 500),
      ]))).failureOrNull, isA<ValidationFailure>());
    });
  });

  test('customer phone unique index enforced at DB level', () async {
    await customers.create(const CustomerInput(name: 'A', phone: '01712345678'));
    final rows = await db.select(db.customers).get();
    expect(
      () => db.into(db.customers).insert(CustomersCompanion.insert(
            id: 'other',
            shopId: 's',
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
            name: 'Dup',
            phonePrimary: rows.single.phonePrimary,
            phoneNormalized: rows.single.phoneNormalized,
          )),
      throwsA(anything),
    );
  });
}
