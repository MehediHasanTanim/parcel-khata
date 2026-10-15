import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parcel_khata/core/db/app_database.dart';
import 'package:parcel_khata/core/db/audit_writer.dart';
import 'package:parcel_khata/core/db/providers.dart';
import 'package:parcel_khata/core/ids/uuid_v7.dart';
import 'package:parcel_khata/core/providers.dart';
import 'package:parcel_khata/core/result/result.dart';
import 'package:parcel_khata/core/time/clock.dart';
import 'package:parcel_khata/core/time/providers.dart';
import 'package:parcel_khata/features/customers/domain/phone_normalizer.dart';

class AddressInput {
  const AddressInput({
    required this.fullText,
    this.id,
    this.label = '',
    this.district,
    this.area,
    this.isDefault = false,
  });

  final String? id;
  final String label;
  final String fullText;
  final String? district;
  final String? area;
  final bool isDefault;
}

class CustomerInput {
  const CustomerInput({
    required this.name,
    required this.phone,
    this.phoneAlt,
    this.whatsapp,
    this.notes,
    this.addresses = const [],
  });

  final String name;
  final String phone;
  final String? phoneAlt;
  final String? whatsapp;
  final String? notes;
  final List<AddressInput> addresses;
}

class CustomerRepository {
  CustomerRepository(this._db, this._ids, this._clock, this._audit, this._shopId);

  final AppDatabase _db;
  final UuidV7 _ids;
  final Clock _clock;
  final AuditWriter _audit;
  final String _shopId;

  /// Live (non-deleted) customer by any phone format.
  Future<Customer?> findByPhone(String phone) {
    final key = PhoneNormalizer.keyFor(phone);
    return (_db.select(_db.customers)
          ..where((c) =>
              c.shopId.equals(_shopId) &
              c.phoneNormalized.equals(key) &
              c.deletedAt.isNull()))
        .getSingleOrNull();
  }

  Future<Customer?> getById(String id) => (_db.select(_db.customers)
        ..where((c) => c.id.equals(id)))
      .getSingleOrNull();

  /// Typed result: validation, or Conflict with the existing customer's id so
  /// the UI can offer "Use existing customer?".
  Future<Result<Customer>> create(CustomerInput input) async {
    final invalid = _validate(input);
    if (invalid != null) return Result.err(invalid);
    final key = PhoneNormalizer.keyFor(input.phone);
    final existing = await findByPhone(input.phone);
    if (existing != null) {
      return Result.err(ConflictFailure('Phone already used by ${existing.name}',
          conflictingId: existing.id));
    }
    final now = _clock.now();
    final id = _ids.generate();
    await _db.transaction(() async {
      await _db.into(_db.customers).insert(CustomersCompanion.insert(
            id: id,
            shopId: _shopId,
            createdAt: now,
            updatedAt: now,
            name: input.name.trim(),
            phonePrimary: input.phone.trim(),
            phoneNormalized: key,
            phoneAlt: Value(_blankToNull(input.phoneAlt)),
            whatsapp: Value(_blankToNull(input.whatsapp)),
            notes: Value(_blankToNull(input.notes)),
          ));
      await _replaceAddresses(id, input.addresses, now);
      await _audit.write(entity: 'customer', entityId: id, action: 'create');
    });
    return Result.ok((await getById(id))!);
  }

  Future<Result<Customer>> update(String id, CustomerInput input) async {
    final invalid = _validate(input);
    if (invalid != null) return Result.err(invalid);
    final current = await getById(id);
    if (current == null) return const Result.err(NotFoundFailure('Customer not found'));
    final key = PhoneNormalizer.keyFor(input.phone);
    final other = await findByPhone(input.phone);
    if (other != null && other.id != id) {
      return Result.err(ConflictFailure('Phone already used by ${other.name}',
          conflictingId: other.id));
    }
    final now = _clock.now();
    await _db.transaction(() async {
      await (_db.update(_db.customers)..where((c) => c.id.equals(id))).write(
        CustomersCompanion(
          name: Value(input.name.trim()),
          phonePrimary: Value(input.phone.trim()),
          phoneNormalized: Value(key),
          phoneAlt: Value(_blankToNull(input.phoneAlt)),
          whatsapp: Value(_blankToNull(input.whatsapp)),
          notes: Value(_blankToNull(input.notes)),
          updatedAt: Value(now),
          rowVersion: Value(current.rowVersion + 1),
        ),
      );
      await _replaceAddresses(id, input.addresses, now);
      await _audit.write(entity: 'customer', entityId: id, action: 'update');
    });
    return Result.ok((await getById(id))!);
  }

  /// Customers are archived, never hard-deleted (feature spec F2 AC3).
  Future<void> archive(String id) async {
    await _db.transaction(() async {
      await (_db.update(_db.customers)..where((c) => c.id.equals(id))).write(
          CustomersCompanion(isArchived: const Value(true), updatedAt: Value(_clock.now())));
      await _audit.write(entity: 'customer', entityId: id, action: 'archive');
    });
  }

  Future<void> unarchive(String id) async {
    await (_db.update(_db.customers)..where((c) => c.id.equals(id))).write(
        CustomersCompanion(isArchived: const Value(false), updatedAt: Value(_clock.now())));
  }

  /// Search by name fragment or 4+ phone digits; empty query lists all.
  Stream<List<Customer>> watchSearch(String query, {bool includeArchived = false}) {
    final q = query.trim();
    final sel = _db.select(_db.customers)
      ..where((c) {
        Expression<bool> w = c.shopId.equals(_shopId) & c.deletedAt.isNull();
        if (!includeArchived) w = w & c.isArchived.equals(false);
        if (q.isNotEmpty) {
          final digits = PhoneNormalizer.normalize(q) ?? q;
          final isPhoneLike = RegExp(r'^[0-9০-৯+\-\s]{4,}$').hasMatch(q);
          w = w &
              (isPhoneLike
                  ? c.phoneNormalized.contains(digits.replaceAll(RegExp(r'[^0-9]'), '')) |
                      c.phonePrimary.contains(q)
                  : c.name.like('%$q%'));
        }
        return w;
      })
      ..orderBy([(c) => OrderingTerm.asc(c.name)]);
    return sel.watch();
  }

  Future<List<Customer>> search(String query) => watchSearch(query).first;

  Stream<List<CustomerAddress>> watchAddresses(String customerId) =>
      (_db.select(_db.customerAddresses)
            ..where((a) => a.customerId.equals(customerId) & a.deletedAt.isNull())
            ..orderBy([
              (a) => OrderingTerm.desc(a.isDefault),
              (a) => OrderingTerm.asc(a.createdAt),
            ]))
          .watch();

  Future<List<CustomerAddress>> addresses(String customerId) =>
      watchAddresses(customerId).first;

  /// Moves addresses to [survivorId], archives [duplicateId], logs the merge.
  /// Order reassignment is wired in once orders exist (Sprint 2).
  Future<Result<void>> merge({
    required String survivorId,
    required String duplicateId,
  }) async {
    if (survivorId == duplicateId) {
      return const Result.err(ValidationFailure('Cannot merge a customer with itself'));
    }
    final survivor = await getById(survivorId);
    final dup = await getById(duplicateId);
    if (survivor == null || dup == null) {
      return const Result.err(NotFoundFailure('Customer not found'));
    }
    final now = _clock.now();
    await _db.transaction(() async {
      final movedAddrs = await (_db.update(_db.customerAddresses)
            ..where((a) => a.customerId.equals(duplicateId)))
          .write(CustomerAddressesCompanion(
        customerId: Value(survivorId),
        isDefault: const Value(false),
        updatedAt: Value(now),
      ));
      // Keep the duplicate's other number on the survivor if it is free.
      if (survivor.phoneAlt == null) {
        await (_db.update(_db.customers)..where((c) => c.id.equals(survivorId)))
            .write(CustomersCompanion(
                phoneAlt: Value(dup.phonePrimary), updatedAt: Value(now)));
      }
      // Free the unique phone slot, then archive + soft-delete the duplicate.
      await (_db.update(_db.customers)..where((c) => c.id.equals(duplicateId))).write(
          CustomersCompanion(
              isArchived: const Value(true),
              deletedAt: Value(now),
              updatedAt: Value(now)));
      await _audit.write(
        entity: 'customer',
        entityId: survivorId,
        action: 'merge',
        payload: {'mergedFrom': duplicateId, 'addressesMoved': movedAddrs},
      );
    });
    return const Result.ok(null);
  }

  Future<void> _replaceAddresses(
      String customerId, List<AddressInput> addrs, DateTime now) async {
    await (_db.delete(_db.customerAddresses)
          ..where((a) => a.customerId.equals(customerId)))
        .go();
    var defaultSeen = false;
    for (var i = 0; i < addrs.length; i++) {
      final a = addrs[i];
      if (a.fullText.trim().isEmpty) continue;
      final makeDefault = (a.isDefault && !defaultSeen) || (i == 0 && !addrs.any((x) => x.isDefault));
      if (makeDefault) defaultSeen = true;
      await _db.into(_db.customerAddresses).insert(CustomerAddressesCompanion.insert(
            id: a.id ?? _ids.generate(),
            shopId: _shopId,
            createdAt: now,
            updatedAt: now,
            customerId: customerId,
            fullText: a.fullText.trim(),
            label: Value(a.label.trim()),
            district: Value(_blankToNull(a.district)),
            area: Value(_blankToNull(a.area)),
            isDefault: Value(makeDefault),
          ));
    }
  }

  static ValidationFailure? _validate(CustomerInput i) {
    if (i.name.trim().isEmpty) return const ValidationFailure('Name is required');
    if (PhoneNormalizer.normalize(i.phone) == null) {
      return const ValidationFailure('Enter a valid mobile number');
    }
    return null;
  }

  static String? _blankToNull(String? s) =>
      (s == null || s.trim().isEmpty) ? null : s.trim();
}

final customerRepositoryProvider = Provider<CustomerRepository>((ref) =>
    CustomerRepository(
      ref.watch(databaseProvider),
      ref.watch(uuidProvider),
      ref.watch(clockProvider),
      ref.watch(auditWriterProvider),
      ref.watch(shopIdProvider),
    ));

final customerSearchProvider =
    StreamProvider.family<List<Customer>, String>((ref, q) =>
        ref.watch(customerRepositoryProvider).watchSearch(q));
