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
import 'package:parcel_khata/features/cod/application/ledger_writer.dart';
import 'package:parcel_khata/features/cod/domain/ledger.dart';
import 'package:parcel_khata/features/cod/domain/payout_reconciler.dart';
import 'package:parcel_khata/features/orders/domain/order_enums.dart';

const kCodOpenStatuses = [
  'collected_by_courier',
  'partially_settled',
  'disputed',
];

class RecordPayoutInput {
  const RecordPayoutInput({
    required this.courierId,
    required this.totalReceived,
    required this.selectedOrderIds,
    required this.allocations,
    this.paidAt,
    this.method = 'bank',
    this.reference,
    this.note,
    this.policy,
    this.allowOverpayment = false,
  });

  final String courierId;
  final Money totalReceived;

  /// Orders the payout is meant to cover (shortfall is judged on these).
  final List<String> selectedOrderIds;
  final List<AllocationLine> allocations;
  final DateTime? paidAt;
  final String method;
  final String? reference;
  final String? note;
  final ShortfallPolicy? policy;
  final bool allowOverpayment;
}

class PayoutFailure extends ValidationFailure {
  const PayoutFailure(this.error) : super('payout');
  final ReconcileError error;
}

class PayableOrder {
  const PayableOrder(this.order, this.reconcile);
  final Order order;
  final ReconcileOrder reconcile;
}

class PayoutDetail {
  const PayoutDetail(this.payout, this.rows);
  final Payout payout;
  final List<(PayoutAllocation, Order)> rows;
}

class PayoutService {
  PayoutService(this._db, this._ids, this._clock, this._audit, this._shopId, this._ledger);

  final AppDatabase _db;
  final UuidV7 _ids;
  final Clock _clock;
  final AuditWriter _audit;
  final String _shopId;
  final LedgerWriter _ledger;

  Stream<void> get changes => _db
      .tableUpdates(TableUpdateQuery.onAllTables([
        _db.orders,
        _db.orderCharges,
        _db.payouts,
        _db.payoutAllocations,
      ]))
      .map((_) {});

  // ------------------------------------------------------------- queries

  /// Orders a courier still owes money for, oldest delivery first.
  Future<List<PayableOrder>> payableOrders(String courierId) async {
    final rows = await (_db.select(_db.orders)
          ..where((o) =>
              o.shopId.equals(_shopId) &
              o.deletedAt.isNull() &
              o.courierId.equals(courierId) &
              o.codStatus.isIn(kCodOpenStatuses) &
              o.outstanding.isBiggerThanValue(0))
          ..orderBy([
            (o) => OrderingTerm.asc(o.deliveredAt),
            (o) => OrderingTerm.asc(o.id),
          ]))
        .get();
    return [
      for (final o in rows)
        PayableOrder(
          o,
          ReconcileOrder(
            id: o.id,
            orderNo: o.orderNo,
            deliveredAt: o.deliveredAt,
            outstanding: Money(o.outstanding ?? 0),
            isDisputed: o.isDisputed,
          ),
        ),
    ];
  }

  Stream<List<Payout>> watchPayouts({String? courierId}) {
    final q = _db.select(_db.payouts)
      ..where((p) {
        Expression<bool> w = p.shopId.equals(_shopId) & p.deletedAt.isNull();
        if (courierId != null) w = w & p.courierId.equals(courierId);
        return w;
      })
      ..orderBy([(p) => OrderingTerm.desc(p.paidAt), (p) => OrderingTerm.desc(p.id)]);
    return q.watch();
  }

  Future<PayoutDetail?> detail(String payoutId) async {
    final p = await (_db.select(_db.payouts)..where((x) => x.id.equals(payoutId)))
        .getSingleOrNull();
    if (p == null) return null;
    final q = _db.select(_db.payoutAllocations).join([
      innerJoin(_db.orders, _db.orders.id.equalsExp(_db.payoutAllocations.orderId)),
    ])
      ..where(_db.payoutAllocations.payoutId.equals(payoutId))
      ..orderBy([OrderingTerm.asc(_db.orders.orderNumber)]);
    final rows = await q.get();
    return PayoutDetail(p, [
      for (final r in rows) (r.readTable(_db.payoutAllocations), r.readTable(_db.orders)),
    ]);
  }

  // ------------------------------------------------------- record payout

  Future<Result<Payout>> recordPayout(RecordPayoutInput i) async {
    final ids = {...i.selectedOrderIds, ...i.allocations.map((a) => a.orderId)}.toList();
    final orders = await (_db.select(_db.orders)
          ..where((o) => o.id.isIn(ids) & o.deletedAt.isNull()))
        .get();
    if (orders.length != ids.length) {
      return const Result.err(NotFoundFailure('Order not found'));
    }
    for (final o in orders) {
      if (o.courierId != i.courierId) {
        return const Result.err(ValidationFailure('wrong_courier'));
      }
    }
    // Use freshly computed ledgers, not just cached columns.
    final reconcile = <ReconcileOrder>[];
    final states = <String, OrderLedgerState>{};
    for (final o in orders) {
      final s = await _ledger.compute(o.id);
      if (s == null) return const Result.err(ValidationFailure('not_collected'));
      states[o.id] = s;
      reconcile.add(ReconcileOrder(
        id: o.id,
        orderNo: o.orderNo,
        deliveredAt: o.deliveredAt,
        outstanding: s.outstanding,
        isDisputed: s.isDisputed,
      ));
    }
    final planResult = PayoutReconciler.plan(
      orders: [for (final r in reconcile) if (i.selectedOrderIds.contains(r.id)) r],
      allocations: i.allocations,
      totalReceived: i.totalReceived,
      policy: i.policy,
      allowOverpayment: i.allowOverpayment,
    );
    if (!planResult.isOk) return Result.err(PayoutFailure(planResult.error!));
    final plan = planResult.plan!;

    final now = _clock.now();
    final payoutId = _ids.generate();
    final hasShortfall = plan.writeOffs.isNotEmpty ||
        plan.newlyDisputedIds.isNotEmpty ||
        i.policy == ShortfallPolicy.allocate;
    await _db.transaction(() async {
      await _db.into(_db.payouts).insert(PayoutsCompanion.insert(
            id: payoutId,
            shopId: _shopId,
            createdAt: now,
            updatedAt: now,
            courierId: i.courierId,
            paidAt: i.paidAt ?? now,
            totalReceived: i.totalReceived.poisha,
            method: Value(i.method),
            reference: Value(_blank(i.reference)),
            note: Value(_blank(i.note)),
            policy: Value(hasShortfall ? _policyName(i.policy) : null),
          ));
      final woByOrder = {for (final w in plan.writeOffs) w.orderId: w.amount};
      final touched = <String>{
        ...plan.allocations.map((a) => a.orderId),
        ...woByOrder.keys,
        ...plan.newlyDisputedIds,
      };
      for (final a in plan.allocations) {
        await _db.into(_db.payoutAllocations).insert(PayoutAllocationsCompanion.insert(
              id: _ids.generate(),
              shopId: _shopId,
              createdAt: now,
              updatedAt: now,
              payoutId: payoutId,
              orderId: a.orderId,
              amountApplied: a.amount.poisha,
              deductionsApplied: Value(states[a.orderId]!.deductions.poisha),
              writeOffAmount: Value(woByOrder[a.orderId]?.poisha ?? 0),
              disputedSet: Value(plan.newlyDisputedIds.contains(a.orderId)),
              isOverpayment: Value(plan.overpaymentIds.contains(a.orderId)),
            ));
      }
      // Write-offs / disputes on orders that got no cash still need a row.
      for (final id in touched.difference(plan.allocations.map((a) => a.orderId).toSet())) {
        await _db.into(_db.payoutAllocations).insert(PayoutAllocationsCompanion.insert(
              id: _ids.generate(),
              shopId: _shopId,
              createdAt: now,
              updatedAt: now,
              payoutId: payoutId,
              orderId: id,
              amountApplied: 0,
              deductionsApplied: Value(states[id]!.deductions.poisha),
              writeOffAmount: Value(woByOrder[id]?.poisha ?? 0),
              disputedSet: Value(plan.newlyDisputedIds.contains(id)),
            ));
      }
      for (final w in plan.writeOffs) {
        await _db.into(_db.orderCharges).insert(OrderChargesCompanion.insert(
              id: _ids.generate(),
              shopId: _shopId,
              createdAt: now,
              updatedAt: now,
              orderId: w.orderId,
              type: kWriteOffType,
              expectedAmount: Value(w.amount.poisha),
              source: const Value('payout_writeoff'),
              note: Value(payoutId),
            ));
      }
      for (final id in plan.newlyDisputedIds) {
        await (_db.update(_db.orders)..where((o) => o.id.equals(id))).write(
          OrdersCompanion(isDisputed: const Value(true), updatedAt: Value(now)),
        );
      }
      for (final id in touched) {
        await _ledger.refresh(id);
      }
      await _audit.write(
        entity: 'payout',
        entityId: payoutId,
        action: 'record',
        payload: {
          'courier': i.courierId,
          'total': i.totalReceived.poisha,
          'orders': touched.length,
          'policy': _policyName(i.policy),
        },
      );
    });
    return Result.ok(
      await (_db.select(_db.payouts)..where((p) => p.id.equals(payoutId))).getSingle(),
    );
  }

  /// Restores every affected order's outstanding balance exactly.
  Future<Result<Payout>> reversePayout(String payoutId, String reason) async {
    if (reason.trim().isEmpty) {
      return const Result.err(ValidationFailure('A reason is required'));
    }
    final p = await (_db.select(_db.payouts)..where((x) => x.id.equals(payoutId)))
        .getSingleOrNull();
    if (p == null) return const Result.err(NotFoundFailure('Payout not found'));
    if (p.status == 'reversed') {
      return const Result.err(ConflictFailure('Payout already reversed'));
    }
    final now = _clock.now();
    await _db.transaction(() async {
      final allocs = await (_db.select(_db.payoutAllocations)
            ..where((a) => a.payoutId.equals(payoutId)))
          .get();
      await (_db.update(_db.payouts)..where((x) => x.id.equals(payoutId))).write(
        PayoutsCompanion(
          status: const Value('reversed'),
          reversedReason: Value(reason.trim()),
          reversedAt: Value(now),
          updatedAt: Value(now),
          rowVersion: Value(p.rowVersion + 1),
        ),
      );
      // Financial rows are reversed, never hard-deleted.
      await (_db.update(_db.orderCharges)
            ..where((c) => c.note.equals(payoutId) & c.source.equals('payout_writeoff')))
          .write(OrderChargesCompanion(deletedAt: Value(now), updatedAt: Value(now)));
      for (final a in allocs) {
        if (a.disputedSet) {
          await (_db.update(_db.orders)..where((o) => o.id.equals(a.orderId))).write(
            OrdersCompanion(isDisputed: const Value(false), updatedAt: Value(now)),
          );
        }
        await _ledger.refresh(a.orderId);
      }
      await _audit.write(
        entity: 'payout',
        entityId: payoutId,
        action: 'reverse',
        payload: {'reason': reason.trim()},
      );
    });
    return Result.ok(
      await (_db.select(_db.payouts)..where((x) => x.id.equals(payoutId))).getSingle(),
    );
  }

  // ------------------------------------------------------- per-order ops

  /// Short-collection / partial acceptance: what the courier really collected.
  Future<Result<Order>> recordCollectedAmount(
    String orderId,
    Money collected,
    String reason,
  ) async {
    if (collected.isNegative) {
      return const Result.err(ValidationFailure('negative_amount'));
    }
    if (reason.trim().isEmpty) {
      return const Result.err(ValidationFailure('reason_required'));
    }
    final o = await (_db.select(_db.orders)..where((x) => x.id.equals(orderId)))
        .getSingleOrNull();
    if (o == null || o.deletedAt != null) {
      return const Result.err(NotFoundFailure('Order not found'));
    }
    if (OrderStatus.fromDb(o.status) != OrderStatus.delivered) {
      return const Result.err(ValidationFailure('not_delivered'));
    }
    final now = _clock.now();
    await _db.transaction(() async {
      await (_db.update(_db.orders)..where((x) => x.id.equals(orderId))).write(
        OrdersCompanion(
          codCollected: Value(collected.poisha),
          updatedAt: Value(now),
          rowVersion: Value(o.rowVersion + 1),
        ),
      );
      await _logEdit(orderId, 'cod_collected', '${o.codCollected}', '${collected.poisha}',
          reason.trim(), now);
      await _ledger.refresh(orderId);
      await _audit.write(
          entity: 'order', entityId: orderId, action: 'collected_amount',
          payload: {'reason': reason.trim()});
    });
    return Result.ok(
      await (_db.select(_db.orders)..where((x) => x.id.equals(orderId))).getSingle(),
    );
  }

  /// Sets (or clears with null) the actual courier fee for a charge type.
  Future<Result<void>> setActualCharge(
    String orderId,
    String type,
    Money? actual,
  ) async {
    if (!kCourierDeductionTypes.contains(type)) {
      return const Result.err(ValidationFailure('invalid_charge_type'));
    }
    if (actual != null && actual.isNegative) {
      return const Result.err(ValidationFailure('negative_amount'));
    }
    final now = _clock.now();
    await _db.transaction(() async {
      final existing = await (_db.select(_db.orderCharges)
            ..where((c) =>
                c.orderId.equals(orderId) & c.type.equals(type) & c.deletedAt.isNull()))
          .getSingleOrNull();
      if (existing == null) {
        if (actual == null) return;
        await _db.into(_db.orderCharges).insert(OrderChargesCompanion.insert(
              id: _ids.generate(),
              shopId: _shopId,
              createdAt: now,
              updatedAt: now,
              orderId: orderId,
              type: type,
              actualAmount: Value(actual.poisha),
              source: const Value('statement'),
            ));
      } else {
        await (_db.update(_db.orderCharges)..where((c) => c.id.equals(existing.id))).write(
          OrderChargesCompanion(
            actualAmount: Value(actual?.poisha),
            source: const Value('statement'),
            updatedAt: Value(now),
          ),
        );
      }
      await _logEdit(orderId, 'actual_$type', '${existing?.actualAmount}',
          '${actual?.poisha}', null, now);
      await _ledger.refresh(orderId);
      await _audit.write(entity: 'order', entityId: orderId, action: 'actual_charge',
          payload: {'type': type});
    });
    return const Result.ok(null);
  }

  Future<Result<void>> markDisputed(String orderId, String note) =>
      _setDispute(orderId, note, true);

  Future<Result<void>> resolveDispute(String orderId, String note) =>
      _setDispute(orderId, note, false);

  Future<Result<void>> _setDispute(String orderId, String note, bool disputed) async {
    final o = await (_db.select(_db.orders)..where((x) => x.id.equals(orderId)))
        .getSingleOrNull();
    if (o == null || o.deletedAt != null) {
      return const Result.err(NotFoundFailure('Order not found'));
    }
    if (disputed && o.codCollected == null) {
      return const Result.err(ValidationFailure('not_collected'));
    }
    final now = _clock.now();
    await _db.transaction(() async {
      await (_db.update(_db.orders)..where((x) => x.id.equals(orderId))).write(
        OrdersCompanion(
          isDisputed: Value(disputed),
          disputeNote: Value(note.trim().isEmpty ? null : note.trim()),
          updatedAt: Value(now),
        ),
      );
      await _logEdit(orderId, 'disputed', '${o.isDisputed}', '$disputed', note.trim(), now);
      await _ledger.refresh(orderId);
      await _audit.write(
          entity: 'order',
          entityId: orderId,
          action: disputed ? 'dispute' : 'resolve_dispute');
    });
    return const Result.ok(null);
  }

  Future<void> _logEdit(String orderId, String field, String? oldV, String? newV,
      String? note, DateTime now) {
    return _db.into(_db.orderEditLog).insert(OrderEditLogCompanion.insert(
          id: _ids.generate(),
          shopId: _shopId,
          createdAt: now,
          updatedAt: now,
          orderId: orderId,
          field: note == null ? field : '$field ($note)',
          oldValue: Value(oldV),
          newValue: Value(newV),
          at: now,
        ));
  }

  static String? _policyName(ShortfallPolicy? p) => switch (p) {
        ShortfallPolicy.allocate => 'allocate',
        ShortfallPolicy.dispute => 'dispute',
        ShortfallPolicy.writeOff => 'write_off',
        null => null,
      };

  static String? _blank(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();
}

final ledgerWriterProvider =
    Provider<LedgerWriter>((ref) => LedgerWriter(ref.watch(databaseProvider)));

final payoutServiceProvider = Provider<PayoutService>((ref) => PayoutService(
      ref.watch(databaseProvider),
      ref.watch(uuidProvider),
      ref.watch(clockProvider),
      ref.watch(auditWriterProvider),
      ref.watch(shopIdProvider),
      ref.watch(ledgerWriterProvider),
    ));
