import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parcel_khata/core/db/app_database.dart';
import 'package:parcel_khata/core/db/providers.dart';
import 'package:parcel_khata/core/ids/uuid_v7.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/core/providers.dart';
import 'package:parcel_khata/core/result/result.dart';
import 'package:parcel_khata/core/time/clock.dart';
import 'package:parcel_khata/core/time/providers.dart';
import 'package:parcel_khata/features/cod/application/ledger_writer.dart';
import 'package:parcel_khata/features/cod/application/payout_service.dart';
import 'package:parcel_khata/features/cod/domain/ledger.dart';
import 'package:parcel_khata/features/cod/domain/payout_reconciler.dart';
import 'package:parcel_khata/features/cod/domain/statement_import.dart';
import 'package:parcel_khata/features/cod/domain/statement_parser.dart';
import 'package:parcel_khata/features/orders/domain/order_enums.dart';

class StatementApplyFailure extends ValidationFailure {
  const StatementApplyFailure(this.error, {this.reconcileError}) : super('statement');
  final StatementPlanError error;
  final ReconcileError? reconcileError;
}

class StatementApplied {
  const StatementApplied({required this.payout, required this.plan, required this.importId});

  /// Null when the statement only carried fees / adjustments (nothing paid).
  final Payout? payout;
  final StatementPlan plan;
  final String importId;
}

class _Abort implements Exception {
  _Abort(this.failure);
  final Failure failure;
}

/// Loads ledger state, applies a reviewed statement in ONE transaction and
/// remembers the file so re-importing it is detected.
class StatementImportService {
  StatementImportService(this._db, this._ids, this._clock, this._shopId, this._ledger,
      this._payouts);

  final AppDatabase _db;
  final UuidV7 _ids;
  final Clock _clock;
  final String _shopId;
  final LedgerWriter _ledger;
  final PayoutService _payouts;

  static String contentHash(List<int> bytes) => sha256.convert(bytes).toString();

  // ------------------------------------------------------------ profiles

  Future<List<StatementProfileRow>> savedProfiles(String courierId) async {
    final rows = await (_db.select(_db.statementProfiles)
          ..where((p) =>
              p.deletedAt.isNull() &
              (p.courierId.equals(courierId) | p.courierId.isNull()))
          ..orderBy([(p) => OrderingTerm.asc(p.name)]))
        .get();
    return [for (final r in rows) StatementProfileRow(r.id, r.courierId, _decode(r))];
  }

  static StatementProfile _decode(SavedStatementProfile r) => StatementProfile(
        name: r.name,
        columns: (jsonDecode(r.columnsJson) as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, v as String)),
        toleranceTaka: r.toleranceTaka,
      );

  Future<String> saveProfile(StatementProfile p, {String? courierId, String? id}) async {
    final now = _clock.now();
    final json = jsonEncode(p.columns);
    if (id != null) {
      await (_db.update(_db.statementProfiles)..where((x) => x.id.equals(id))).write(
          StatementProfilesCompanion(
            name: Value(p.name),
            columnsJson: Value(json),
            toleranceTaka: Value(p.toleranceTaka),
            updatedAt: Value(now),
          ));
      return id;
    }
    final newId = _ids.generate();
    await _db.into(_db.statementProfiles).insert(StatementProfilesCompanion.insert(
          id: newId,
          shopId: _shopId,
          createdAt: now,
          updatedAt: now,
          name: p.name,
          columnsJson: json,
          courierId: Value(courierId),
          toleranceTaka: Value(p.toleranceTaka),
        ));
    return newId;
  }

  Future<void> deleteProfile(String id) =>
      (_db.update(_db.statementProfiles)..where((x) => x.id.equals(id)))
          .write(StatementProfilesCompanion(deletedAt: Value(_clock.now())));

  // ------------------------------------------------------------- loading

  /// Every non-deleted order of the courier that has a CN and a recorded
  /// collection (so settled ones classify as `alreadySettled`).
  Future<List<StatementOrder>> loadOrders(String courierId) async {
    final rows = await (_db.select(_db.orders)
          ..where((o) =>
              o.shopId.equals(_shopId) &
              o.deletedAt.isNull() &
              o.courierId.equals(courierId) &
              o.consignmentNo.isNotNull() &
              o.codCollected.isNotNull()))
        .get();
    final out = <StatementOrder>[];
    for (final o in rows) {
      final charges = await (_db.select(_db.orderCharges)
            ..where((c) => c.orderId.equals(o.id) & c.deletedAt.isNull()))
          .get();
      final record = await (_db.select(_db.returnRecords)
            ..where((r) => r.orderId.equals(o.id) & r.deletedAt.isNull()))
          .getSingleOrNull();
      final status = OrderStatus.fromDb(o.status);
      out.add(StatementOrder(
        id: o.id,
        orderNo: o.orderNo,
        cn: o.consignmentNo!,
        collected: Money(o.codCollected!),
        charges: [
          for (final c in charges)
            ChargeAmount(
              type: c.type,
              expected: Money(c.expectedAmount),
              actual: c.actualAmount == null ? null : Money(c.actualAmount!),
            ),
        ],
        settled: await _ledger.settledFor(o.id),
        isDisputed: o.isDisputed,
        hasReturn: record != null ||
            status == OrderStatus.deliveryFailed ||
            status == OrderStatus.returnInTransit ||
            status == OrderStatus.returned,
        deliveredAt: o.deliveredAt,
      ));
    }
    return out;
  }

  /// A previous applied import of the same file for this courier.
  Future<StatementImportLog?> findApplied(String courierId, String hash) =>
      (_db.select(_db.statementImports)
            ..where((i) =>
                i.courierId.equals(courierId) &
                i.contentHash.equals(hash) &
                i.deletedAt.isNull())
            ..limit(1))
          .getSingleOrNull();

  // --------------------------------------------------------------- apply

  /// Nothing is written until here; any failure rolls everything back.
  Future<Result<StatementApplied>> apply({
    required String courierId,
    required List<StatementDecision> decisions,
    required String contentHash,
    required int rowCount,
    String fileName = '',
    ShortfallPolicy? policy,
    bool allowOverpayment = false,
    DateTime? paidAt,
    String method = 'bank',
    String? reference,
    String? note,
  }) async {
    if (await findApplied(courierId, contentHash) != null) {
      return const Result.err(ConflictFailure('already_applied'));
    }
    final built = StatementPlanBuilder.build(decisions,
        policy: policy, allowOverpayment: allowOverpayment);
    if (!built.isOk) return Result.err(StatementApplyFailure(built.error!));
    final plan = built.plan!;
    if (plan.totalReceived.poisha > 0 && !plan.settlement.isOk) {
      return Result.err(StatementApplyFailure(StatementPlanError.reconcile,
          reconcileError: plan.settlement.error));
    }
    // Every touched order must belong to this courier.
    for (final d in decisions.where((d) => d.include)) {
      final o = d.matched.order;
      if (o == null) {
        return const Result.err(StatementApplyFailure(StatementPlanError.ineligibleRow));
      }
    }

    final now = _clock.now();
    final importId = _ids.generate();
    Payout? payout;
    try {
      await _db.transaction(() async {
        for (final f in plan.feeUpdates) {
          final r = await _payouts.setActualCharge(f.orderId, f.type, f.amount);
          if (!r.isOk) throw _Abort(r.failureOrNull!);
        }
        for (final a in plan.adjustments) {
          final r = await _payouts.recordCollectedAmount(a.orderId, a.amount, a.reason);
          if (!r.isOk) throw _Abort(r.failureOrNull!);
        }
        if (plan.totalReceived.poisha > 0) {
          final r = await _payouts.recordPayout(RecordPayoutInput(
            courierId: courierId,
            totalReceived: plan.totalReceived,
            selectedOrderIds: plan.selectedOrderIds,
            allocations: plan.allocations,
            paidAt: paidAt,
            method: method,
            reference: reference,
            note: note ?? 'Statement import',
            policy: policy,
            allowOverpayment: allowOverpayment,
          ));
          if (!r.isOk) throw _Abort(r.failureOrNull!);
          payout = r.valueOrNull;
        }
        await _db.into(_db.statementImports).insert(StatementImportsCompanion.insert(
              id: importId,
              shopId: _shopId,
              createdAt: now,
              updatedAt: now,
              courierId: courierId,
              contentHash: contentHash,
              fileName: Value(fileName),
              payoutId: Value(payout?.id),
              rowCount: Value(rowCount),
              appliedCount: Value(plan.selectedOrderIds.length),
            ));
      });
    } on _Abort catch (e) {
      return Result.err(e.failure);
    }
    return Result.ok(StatementApplied(payout: payout, plan: plan, importId: importId));
  }
}

class StatementProfileRow {
  const StatementProfileRow(this.id, this.courierId, this.profile);
  final String id;
  final String? courierId;
  final StatementProfile profile;
}

final statementImportServiceProvider = Provider<StatementImportService>((ref) =>
    StatementImportService(
      ref.watch(databaseProvider),
      ref.watch(uuidProvider),
      ref.watch(clockProvider),
      ref.watch(shopIdProvider),
      ref.watch(ledgerWriterProvider),
      ref.watch(payoutServiceProvider),
    ));
