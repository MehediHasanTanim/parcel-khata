import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parcel_khata/core/db/app_database.dart';
import 'package:parcel_khata/core/db/audit_writer.dart';
import 'package:parcel_khata/core/db/providers.dart';
import 'package:parcel_khata/core/ids/uuid_v7.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/core/providers.dart';
import 'package:parcel_khata/core/result/result.dart';
import 'package:parcel_khata/core/time/clock.dart';
import 'package:parcel_khata/core/time/providers.dart';
import 'package:parcel_khata/features/expenses/domain/business_pnl.dart';

class ExpenseInput {
  const ExpenseInput({
    required this.date,
    required this.category,
    required this.amount,
    this.note,
    this.campaignId,
    this.recurringMonthly = false,
  });

  final DateTime date;
  final ExpenseCategory category;
  final Money amount;
  final String? note;
  final String? campaignId;
  final bool recurringMonthly;
}

class ExpenseRepository {
  ExpenseRepository(this._db, this._ids, this._clock, this._audit, this._shopId);

  final AppDatabase _db;
  final UuidV7 _ids;
  final Clock _clock;
  final AuditWriter _audit;
  final String _shopId;

  Stream<List<Expense>> watch({DateTime? from, DateTime? to}) {
    final q = _db.select(_db.expenses)
      ..where((e) {
        Expression<bool> w = e.shopId.equals(_shopId) & e.deletedAt.isNull();
        if (from != null) w = w & e.date.isBiggerOrEqualValue(from);
        if (to != null) w = w & e.date.isSmallerThanValue(to);
        return w;
      })
      ..orderBy([(e) => OrderingTerm.desc(e.date), (e) => OrderingTerm.desc(e.id)]);
    return q.watch();
  }

  Future<Expense?> getById(String id) =>
      (_db.select(_db.expenses)..where((e) => e.id.equals(id))).getSingleOrNull();

  Future<Result<Expense>> create(ExpenseInput i) async {
    final bad = _validate(i);
    if (bad != null) return Result.err(bad);
    final now = _clock.now();
    final id = _ids.generate();
    await _db.transaction(() async {
      await _db.into(_db.expenses).insert(_companion(id, i, now));
      await _audit.write(
          entity: 'expense', entityId: id, action: 'create', payload: {'amount': i.amount.poisha});
    });
    return Result.ok((await getById(id))!);
  }

  Future<Result<Expense>> update(String id, ExpenseInput i) async {
    final bad = _validate(i);
    if (bad != null) return Result.err(bad);
    final cur = await getById(id);
    if (cur == null) return const Result.err(NotFoundFailure('Expense not found'));
    final now = _clock.now();
    await _db.transaction(() async {
      await (_db.update(_db.expenses)..where((e) => e.id.equals(id))).write(
        ExpensesCompanion(
          date: Value(i.date),
          category: Value(i.category.dbValue),
          amount: Value(i.amount.poisha),
          note: Value(_blank(i.note)),
          campaignId: Value(i.campaignId),
          recurringMonthly: Value(i.recurringMonthly),
          updatedAt: Value(now),
          rowVersion: Value(cur.rowVersion + 1),
        ),
      );
      await _audit.write(entity: 'expense', entityId: id, action: 'update');
    });
    return Result.ok((await getById(id))!);
  }

  Future<void> delete(String id) async {
    final now = _clock.now();
    await _db.transaction(() async {
      await (_db.update(_db.expenses)..where((e) => e.id.equals(id)))
          .write(ExpensesCompanion(deletedAt: Value(now), updatedAt: Value(now)));
      await _audit.write(entity: 'expense', entityId: id, action: 'delete');
    });
  }

  /// Creates this month's copy of every recurring template that has none yet.
  /// Idempotent: safe to call each time the screen opens. Returns the count.
  Future<int> materializeRecurring() async {
    final now = _clock.now();
    final monthStart = DateTime(now.year, now.month);
    final templates = await (_db.select(_db.expenses)
          ..where((e) =>
              e.shopId.equals(_shopId) &
              e.deletedAt.isNull() &
              e.recurringMonthly.equals(true) &
              e.recurringSourceId.isNull()))
        .get();
    var created = 0;
    await _db.transaction(() async {
      for (final t in templates) {
        // A template is its own first occurrence; skip its month.
        if (!t.date.isBefore(monthStart)) continue;
        final existing = await (_db.select(_db.expenses)
              ..where((e) =>
                  e.recurringSourceId.equals(t.id) &
                  e.deletedAt.isNull() &
                  e.date.isBiggerOrEqualValue(monthStart)))
            .get();
        if (existing.isNotEmpty) continue;
        final day = t.date.day.clamp(1, DateTime(now.year, now.month + 1, 0).day);
        await _db.into(_db.expenses).insert(ExpensesCompanion.insert(
              id: _ids.generate(),
              shopId: _shopId,
              createdAt: now,
              updatedAt: now,
              date: DateTime(now.year, now.month, day),
              category: t.category,
              amount: t.amount,
              note: Value(t.note),
              campaignId: Value(t.campaignId),
              recurringSourceId: Value(t.id),
            ));
        created++;
      }
    });
    return created;
  }

  ExpensesCompanion _companion(String id, ExpenseInput i, DateTime now) =>
      ExpensesCompanion.insert(
        id: id,
        shopId: _shopId,
        createdAt: now,
        updatedAt: now,
        date: i.date,
        category: i.category.dbValue,
        amount: i.amount.poisha,
        note: Value(_blank(i.note)),
        campaignId: Value(i.campaignId),
        recurringMonthly: Value(i.recurringMonthly),
      );

  static ValidationFailure? _validate(ExpenseInput i) {
    if (i.amount.poisha <= 0) return const ValidationFailure('amount_required');
    return null;
  }

  static String? _blank(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();
}

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) => ExpenseRepository(
      ref.watch(databaseProvider),
      ref.watch(uuidProvider),
      ref.watch(clockProvider),
      ref.watch(auditWriterProvider),
      ref.watch(shopIdProvider),
    ));
