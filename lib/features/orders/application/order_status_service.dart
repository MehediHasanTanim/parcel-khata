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
import 'package:parcel_khata/features/cod/application/ledger_writer.dart';
import 'package:parcel_khata/features/couriers/domain/stuck_parcel_policy.dart';
import 'package:parcel_khata/features/orders/domain/order_enums.dart';
import 'package:parcel_khata/features/orders/domain/order_status_machine.dart';
import 'package:parcel_khata/features/returns/application/stock_service.dart';
import 'package:parcel_khata/features/settings/application/settings_repository.dart';

/// Typed failure carrying the violated guard.
class TransitionFailure extends ValidationFailure {
  const TransitionFailure(this.error) : super('transition:error');
  final TransitionError error;
}

class SkippedOrder {
  const SkippedOrder(this.orderId, this.orderNo, this.error);
  final String orderId;
  final String orderNo;
  final TransitionError error;
}

class BulkResult {
  const BulkResult({required this.changedIds, required this.skipped, this.undoToken});

  final List<String> changedIds;
  final List<SkippedOrder> skipped;

  /// Pass to [OrderStatusService.undo]; null when nothing changed.
  final String? undoToken;
}

class StuckOrder {
  const StuckOrder(this.order, this.level, this.days);
  final Order order;
  final StuckLevel level;
  final int days;
}

class _Snapshot {
  _Snapshot(this.order, this.createdEventIds);
  final Order order;
  final List<String> createdEventIds;
}

class _UndoRecord {
  _UndoRecord(this.snapshots, this.expiresAt, this.mutationSerial);
  final List<_Snapshot> snapshots;
  final DateTime expiresAt;
  final int mutationSerial;
}

/// Status changes, corrections, bulk updates with undo, and stuck detection.
class OrderStatusService {
  OrderStatusService(
    this._db,
    this._ids,
    this._clock,
    this._audit,
    this._shopId,
    this._settings,
    this._ledger,
    this._stock,
  );

  final AppDatabase _db;
  final UuidV7 _ids;
  final Clock _clock;
  final AuditWriter _audit;
  final String _shopId;
  final SettingsRepository _settings;
  final LedgerWriter _ledger;
  final StockService _stock;

  static const undoWindow = Duration(seconds: 30);

  // Undo is valid for 30 s or until the next mutation, whichever is first.
  int _serial = 0;
  final Map<String, _UndoRecord> _undo = {};

  Future<OrderStatusMachine> machine() async {
    final s = await _settings.read();
    return OrderStatusMachine(
      packedEnabled: s.packedStepEnabled,
      inTransitEnabled: s.inTransitStepEnabled,
    );
  }

  /// Moves one order forward. [at] may be back-dated, never in the future.
  Future<Result<Order>> changeStatus(
    String orderId, {
    required OrderStatus to,
    DateTime? at,
    String? reason,
    String? note,
  }) async {
    final r = await bulkChange([orderId], to: to, at: at, reason: reason, note: note);
    if (r.skipped.isNotEmpty) return Result.err(TransitionFailure(r.skipped.first.error));
    if (r.changedIds.isEmpty) return const Result.err(NotFoundFailure('Order not found'));
    final o = await (_db.select(_db.orders)..where((x) => x.id.equals(orderId))).getSingle();
    return Result.ok(o);
  }

  /// Applies one transition to many orders in a single transaction. Invalid
  /// ones are skipped and reported; valid ones are still applied.
  Future<BulkResult> bulkChange(
    List<String> orderIds, {
    required OrderStatus to,
    DateTime? at,
    String? reason,
    String? note,
  }) async {
    final m = await machine();
    final settings = await _settings.read();
    final now = _clock.now();
    final when = at ?? now;
    final changed = <String>[];
    final skipped = <SkippedOrder>[];
    final snapshots = <_Snapshot>[];

    await _db.transaction(() async {
      final orders = await (_db.select(_db.orders)
            ..where((o) => o.id.isIn(orderIds) & o.deletedAt.isNull()))
          .get();
      for (final o in orders) {
        final from = OrderStatus.fromDb(o.status);
        final initiated = to == OrderStatus.returned ? await _returnInitiatedAt(o.id) : null;
        final err = m.validate(
          from: from,
          to: to,
          at: when,
          now: now,
          hasCourier: o.courierId != null,
          hasCn: (o.consignmentNo ?? '').isNotEmpty,
          reason: reason,
          returnInitiatedAt: initiated,
        );
        if (err != null) {
          skipped.add(SkippedOrder(o.id, o.orderNo, err));
          continue;
        }
        final eventIds = <String>[];
        await _apply(o, from, to, when, reason, note, now, eventIds,
            stockEnabled: settings.stockTrackingEnabled);
        // Auto-start the return flow after a failed delivery (setting).
        if (to == OrderStatus.deliveryFailed && settings.autoStartReturnFlow) {
          await _apply(
            o.copyWith(status: OrderStatus.deliveryFailed.dbValue),
            OrderStatus.deliveryFailed,
            OrderStatus.returnInTransit,
            when,
            null,
            null,
            now,
            eventIds,
            stockEnabled: false,
          );
        }
        snapshots.add(_Snapshot(o, eventIds));
        changed.add(o.id);
      }
      if (changed.isNotEmpty) {
        await _audit.write(
          entity: 'order',
          entityId: changed.length == 1 ? changed.first : 'bulk',
          action: 'status_change',
          payload: {'to': to.dbValue, 'count': changed.length, 'reason': reason},
        );
      }
    });

    String? token;
    if (changed.isNotEmpty) {
      _serial++;
      token = _ids.generate();
      _undo
        ..clear()
        ..[token] = _UndoRecord(snapshots, now.add(undoWindow), _serial);
    }
    return BulkResult(changedIds: changed, skipped: skipped, undoToken: token);
  }

  /// Fix a wrong status. Bypasses the transition table, needs a note, and is
  /// flagged in the timeline with the reserved `correction` reason.
  Future<Result<Order>> correctStatus(
    String orderId, {
    required OrderStatus to,
    required String note,
    DateTime? at,
  }) async {
    if (note.trim().isEmpty) {
      return const Result.err(ValidationFailure('A note is required for a correction'));
    }
    final o = await (_db.select(_db.orders)..where((x) => x.id.equals(orderId))).getSingleOrNull();
    if (o == null || o.deletedAt != null) {
      return const Result.err(NotFoundFailure('Order not found'));
    }
    final now = _clock.now();
    final when = at ?? now;
    final err = (await machine()).validateCorrection(
      to: to,
      at: when,
      now: now,
      hasCourier: o.courierId != null,
      hasCn: (o.consignmentNo ?? '').isNotEmpty,
    );
    if (err != null) return Result.err(TransitionFailure(err));
    final from = OrderStatus.fromDb(o.status);
    if (from == to) return Result.ok(o);
    await _db.transaction(() async {
      final settings = await _settings.read();
      await _apply(o, from, to, when, kCorrectionReason, note.trim(), now, <String>[],
          correction: true, stockEnabled: settings.stockTrackingEnabled);
      await _audit.write(
        entity: 'order',
        entityId: orderId,
        action: 'status_correction',
        payload: {'from': from.dbValue, 'to': to.dbValue},
      );
    });
    _serial++;
    _undo.clear();
    return Result.ok(await (_db.select(_db.orders)..where((x) => x.id.equals(orderId))).getSingle());
  }

  /// Reverts the last bulk change exactly. False when expired or superseded.
  Future<bool> undo(String token) async {
    final rec = _undo[token];
    if (rec == null) return false;
    if (_clock.now().isAfter(rec.expiresAt) || rec.mutationSerial != _serial) {
      _undo.remove(token);
      return false;
    }
    final now = _clock.now();
    await _db.transaction(() async {
      for (final s in rec.snapshots) {
        if (s.createdEventIds.isNotEmpty) {
          await (_db.delete(_db.orderStatusEvents)
                ..where((e) => e.id.isIn(s.createdEventIds)))
              .go();
        }
        final o = s.order;
        await (_db.update(_db.orders)..where((x) => x.id.equals(o.id))).write(
          OrdersCompanion(
            status: Value(o.status),
            codStatus: Value(o.codStatus),
            codCollected: Value(o.codCollected),
            handedOverAt: Value(o.handedOverAt),
            deliveredAt: Value(o.deliveredAt),
            updatedAt: Value(now),
            rowVersion: Value(o.rowVersion),
          ),
        );
        await _ledger.refresh(o.id);
      }
      await _audit.write(
        entity: 'order',
        entityId: 'bulk',
        action: 'status_undo',
        payload: {'count': rec.snapshots.length},
      );
    });
    _undo.remove(token);
    _serial++;
    return true;
  }

  /// "Still in transit": records a timeline note without changing the status,
  /// which resets the no-update clock used by the follow-up queue.
  Future<void> acknowledge(String orderId, {String note = 'still_in_transit'}) async {
    final o = await (_db.select(_db.orders)..where((x) => x.id.equals(orderId)))
        .getSingleOrNull();
    if (o == null) return;
    final now = _clock.now();
    await _db.into(_db.orderStatusEvents).insert(OrderStatusEventsCompanion.insert(
          id: _ids.generate(),
          shopId: _shopId,
          createdAt: now,
          updatedAt: now,
          orderId: orderId,
          toStatus: o.status,
          at: now,
          fromStatus: Value(o.status),
          note: Value(note),
        ));
  }

  /// Orders with a courier longer than their threshold, worst first.
  Future<List<StuckOrder>> stuckOrders() async {
    final q = _db.select(_db.orders).join([
      innerJoin(_db.couriers, _db.couriers.id.equalsExp(_db.orders.courierId)),
    ])
      ..where(_db.orders.shopId.equals(_shopId) &
          _db.orders.deletedAt.isNull() &
          _db.orders.status.isIn([
            OrderStatus.handedToCourier.dbValue,
            OrderStatus.inTransit.dbValue,
          ]));
    final now = _clock.now();
    final out = <StuckOrder>[];
    for (final r in await q.get()) {
      final o = r.readTable(_db.orders);
      final c = r.readTable(_db.couriers);
      final level = StuckParcelPolicy.level(
        status: OrderStatus.fromDb(o.status),
        handedOverAt: o.handedOverAt,
        now: now,
        stuckDays: c.stuckDays,
      );
      if (level != StuckLevel.none) {
        out.add(StuckOrder(o, level, StuckParcelPolicy.daysWithCourier(o.handedOverAt!, now)));
      }
    }
    out.sort((a, b) => b.days.compareTo(a.days));
    return out;
  }

  // --------------------------------------------------------------- helpers

  static bool _stockOut(OrderStatus s) => const {
        OrderStatus.handedToCourier,
        OrderStatus.inTransit,
        OrderStatus.delivered,
        OrderStatus.deliveryFailed,
        OrderStatus.returnInTransit,
        OrderStatus.returned,
      }.contains(s);

  Future<DateTime?> _returnInitiatedAt(String orderId) async {
    final e = await (_db.select(_db.orderStatusEvents)
          ..where((x) =>
              x.orderId.equals(orderId) &
              x.toStatus.isIn([
                OrderStatus.returnInTransit.dbValue,
                OrderStatus.deliveryFailed.dbValue,
              ]))
          ..orderBy([(x) => OrderingTerm.desc(x.at)])
          ..limit(1))
        .getSingleOrNull();
    return e?.at;
  }

  Future<void> _apply(
    Order o,
    OrderStatus from,
    OrderStatus to,
    DateTime when,
    String? reason,
    String? note,
    DateTime now,
    List<String> eventIds, {
    required bool stockEnabled,
    bool correction = false,
  }) async {
    final hasCod = o.codExpected > 0 && o.paymentType != PaymentType.prepaid.dbValue;
    CodStatus? cod;
    int? collected;
    var clearCollected = false;
    switch (to) {
      case OrderStatus.delivered:
        if (hasCod) {
          cod = CodStatus.collectedByCourier;
          collected = o.codCollected ?? o.codExpected;
        }
      case OrderStatus.deliveryFailed ||
            OrderStatus.returnInTransit ||
            OrderStatus.returned ||
            OrderStatus.cancelled:
        cod = hasCod ? CodStatus.notCollected : CodStatus.notApplicable;
        clearCollected = true;
      case OrderStatus.handedToCourier ||
            OrderStatus.inTransit ||
            OrderStatus.confirmed ||
            OrderStatus.packed ||
            OrderStatus.draft:
        // Back to a pre-delivery state (only via correction): COD is pending again.
        if (correction) {
          cod = hasCod ? CodStatus.pendingCollection : CodStatus.notApplicable;
          clearCollected = true;
        }
    }
    final eventId = _ids.generate();
    await _db.into(_db.orderStatusEvents).insert(OrderStatusEventsCompanion.insert(
          id: eventId,
          shopId: _shopId,
          createdAt: now,
          updatedAt: now,
          orderId: o.id,
          toStatus: to.dbValue,
          at: when,
          fromStatus: Value(from.dbValue),
          reason: Value(reason),
          note: Value(note),
        ));
    eventIds.add(eventId);
    await (_db.update(_db.orders)..where((x) => x.id.equals(o.id))).write(
      OrdersCompanion(
        status: Value(to.dbValue),
        handedOverAt: to == OrderStatus.handedToCourier
            ? Value(when)
            : (correction && to.index < OrderStatus.handedToCourier.index
                ? const Value(null)
                : const Value.absent()),
        deliveredAt: to == OrderStatus.delivered
            ? Value(when)
            : (o.deliveredAt != null ? const Value(null) : const Value.absent()),
        codStatus: cod == null ? const Value.absent() : Value(cod.dbValue),
        codCollected: collected != null
            ? Value(collected)
            : (clearCollected ? const Value(null) : const Value.absent()),
        updatedAt: Value(now),
        rowVersion: Value(o.rowVersion + 1),
      ),
    );
    // Stock leaves when the parcel is handed over and comes back if that is
    // corrected away (returns restore stock through the return flow).
    if (stockEnabled) {
      final wasOut = _stockOut(from);
      final isOut = _stockOut(to);
      if (!wasOut && isOut) await _stock.applyForOrder(o.id, out: true);
      if (wasOut && !isOut) await _stock.applyForOrder(o.id, out: false);
    }
    // Cached net receivable / outstanding / COD status come from one place.
    await _ledger.refresh(o.id);
  }
}

final orderStatusServiceProvider = Provider<OrderStatusService>((ref) => OrderStatusService(
      ref.watch(databaseProvider),
      ref.watch(uuidProvider),
      ref.watch(clockProvider),
      ref.watch(auditWriterProvider),
      ref.watch(shopIdProvider),
      ref.watch(settingsRepositoryProvider),
      LedgerWriter(ref.watch(databaseProvider)),
      StockService(ref.watch(databaseProvider), ref.watch(clockProvider)),
    ));
