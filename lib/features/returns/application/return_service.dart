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
import 'package:parcel_khata/features/cod/application/payout_service.dart';
import 'package:parcel_khata/features/orders/application/order_status_service.dart';
import 'package:parcel_khata/features/orders/domain/order_enums.dart';
import 'package:parcel_khata/features/profit/domain/profit_calculator.dart';
import 'package:parcel_khata/features/returns/application/stock_service.dart';
import 'package:parcel_khata/features/returns/domain/return_loss_calculator.dart';
import 'package:parcel_khata/features/settings/application/settings_repository.dart';

/// Reasons from the feature spec F7.
const kReturnReasons = [
  'customer_refused',
  'not_reachable',
  'wrong_address',
  'wrong_or_damaged_item',
  'size_or_color_issue',
  'changed_mind',
  'fake_order',
  'other',
];

class ReturnQty {
  const ReturnQty(this.orderLineId, this.qty);
  final String orderLineId;
  final int qty;
}

class ReturnReceipt {
  const ReturnReceipt({required this.record, required this.loss, required this.stockChanges});
  final ReturnRecord record;
  final ReturnLoss loss;
  final List<StockChange> stockChanges;
}

class ReturnFailure extends ValidationFailure {
  const ReturnFailure(this.code) : super('return');
  final String code;
}

class ReturnView {
  const ReturnView(this.record, this.lines);
  final ReturnRecord record;
  final List<ReturnLine> lines;
}

class ReturnService {
  ReturnService(
    this._db,
    this._ids,
    this._clock,
    this._audit,
    this._shopId,
    this._ledger,
    this._status,
    this._stock,
    this._settings,
  );

  final AppDatabase _db;
  final UuidV7 _ids;
  final Clock _clock;
  final AuditWriter _audit;
  final String _shopId;
  final LedgerWriter _ledger;
  final OrderStatusService _status;
  final StockService _stock;
  final SettingsRepository _settings;

  Future<ReturnView?> forOrder(String orderId) async {
    final r = await (_db.select(_db.returnRecords)
          ..where((x) => x.orderId.equals(orderId) & x.deletedAt.isNull()))
        .getSingleOrNull();
    if (r == null) return null;
    final lines = await (_db.select(_db.returnLines)
          ..where((l) => l.returnId.equals(r.id) & l.deletedAt.isNull()))
        .get();
    return ReturnView(r, lines);
  }

  /// Starts a return. Full: after a failed delivery. Partial: customer kept
  /// some items of a delivered order.
  Future<Result<ReturnRecord>> initiate(
    String orderId, {
    required bool full,
    required String reason,
    List<ReturnQty> lines = const [],
    DateTime? initiatedAt,
    String? notes,
    String? exchangeOrderId,
  }) async {
    final o = await (_db.select(_db.orders)..where((x) => x.id.equals(orderId)))
        .getSingleOrNull();
    if (o == null || o.deletedAt != null) {
      return const Result.err(NotFoundFailure('Order not found'));
    }
    if (await forOrder(orderId) != null) {
      return const Result.err(ConflictFailure('return_exists'));
    }
    final status = OrderStatus.fromDb(o.status);
    final okStatus = full
        ? status == OrderStatus.deliveryFailed || status == OrderStatus.returnInTransit
        : status == OrderStatus.delivered;
    if (!okStatus) return const Result.err(ReturnFailure('invalid_status'));
    final now = _clock.now();
    final at = initiatedAt ?? now;
    if (at.isAfter(now)) return const Result.err(ReturnFailure('future_date'));

    final orderLines = await (_db.select(_db.orderLines)
          ..where((l) => l.orderId.equals(orderId) & l.deletedAt.isNull()))
        .get();
    final picked = full
        ? [for (final l in orderLines) ReturnQty(l.id, l.qty)]
        : lines.where((q) => q.qty > 0).toList();
    if (picked.isEmpty) return const Result.err(ReturnFailure('no_lines'));
    for (final q in picked) {
      final l = orderLines.where((x) => x.id == q.orderLineId).firstOrNull;
      if (l == null || q.qty > l.qty) return const Result.err(ReturnFailure('bad_qty'));
    }
    if (!full && exchangeOrderId == null) {
      // Returning everything is a full return, which has its own flow.
      final allReturned = orderLines.every((l) =>
          picked.where((q) => q.orderLineId == l.id).fold(0, (s, q) => s + q.qty) >= l.qty);
      if (allReturned) return const Result.err(ReturnFailure('use_full'));
    }
    final id = _ids.generate();
    await _db.transaction(() async {
      await _db.into(_db.returnRecords).insert(ReturnRecordsCompanion.insert(
            id: id,
            shopId: _shopId,
            createdAt: now,
            updatedAt: now,
            orderId: orderId,
            type: full ? 'full' : 'partial',
            reason: reason,
            initiatedAt: at,
            notes: Value(notes?.trim().isEmpty ?? true ? null : notes!.trim()),
            exchangeOrderId: Value(exchangeOrderId),
          ));
      for (final q in picked) {
        await _db.into(_db.returnLines).insert(ReturnLinesCompanion.insert(
              id: _ids.generate(),
              shopId: _shopId,
              createdAt: now,
              updatedAt: now,
              returnId: id,
              orderLineId: q.orderLineId,
              qty: q.qty,
            ));
      }
      await _ledger.refresh(orderId);
      await _audit.write(
          entity: 'return',
          entityId: id,
          action: 'initiate',
          payload: {'order': orderId, 'full': full, 'reason': reason});
    });
    return Result.ok(
      await (_db.select(_db.returnRecords)..where((r) => r.id.equals(id))).getSingle(),
    );
  }

  /// Marks goods as received back with a condition per returned line.
  /// A full return moves the order to Returned; a partial return reduces the
  /// collected COD by the returned goods' value.
  Future<Result<ReturnReceipt>> receive(
    String orderId, {
    Map<String, ReturnCondition> conditions = const {},
    DateTime? receivedAt,
    String? notes,
  }) async {
    final o = await (_db.select(_db.orders)..where((x) => x.id.equals(orderId)))
        .getSingleOrNull();
    if (o == null || o.deletedAt != null) {
      return const Result.err(NotFoundFailure('Order not found'));
    }
    var view = await forOrder(orderId);
    final status = OrderStatus.fromDb(o.status);
    final now = _clock.now();
    final at = receivedAt ?? now;
    if (at.isAfter(now)) return const Result.err(ReturnFailure('future_date'));

    if (view == null) {
      // The failed-delivery flow starts returns without a record: create it.
      if (status != OrderStatus.deliveryFailed && status != OrderStatus.returnInTransit) {
        return const Result.err(ReturnFailure('no_return'));
      }
      final ev = await (_db.select(_db.orderStatusEvents)
            ..where((e) =>
                e.orderId.equals(orderId) &
                e.toStatus.isIn([
                  OrderStatus.deliveryFailed.dbValue,
                  OrderStatus.returnInTransit.dbValue,
                ]))
            ..orderBy([(e) => OrderingTerm.asc(e.at)])
            ..limit(1))
          .getSingleOrNull();
      final created = await initiate(
        orderId,
        full: true,
        reason: ev?.reason ?? 'other',
        initiatedAt: ev?.at ?? now,
      );
      if (!created.isOk) return Result.err(created.failureOrNull!);
      view = await forOrder(orderId);
    }
    final viewNN = view!;
    final record = viewNN.record;
    if (record.receivedBackAt != null) {
      return const Result.err(ConflictFailure('already_received'));
    }
    if (at.isBefore(record.initiatedAt)) {
      return const Result.err(ReturnFailure('before_initiated'));
    }
    final full = record.type == 'full';
    if (full) {
      // Pre-check the status move so nothing is persisted on a bad transition.
      final err = (await _status.machine()).validate(
        from: status,
        to: OrderStatus.returned,
        at: at,
        now: now,
        hasCourier: o.courierId != null,
        hasCn: (o.consignmentNo ?? '').isNotEmpty,
        returnInitiatedAt: record.initiatedAt,
      );
      if (err != null) return Result.err(TransitionFailure(err));
    }

    final settings = await _settings.read();
    final orderLines = await (_db.select(_db.orderLines)
          ..where((l) => l.orderId.equals(orderId) & l.deletedAt.isNull()))
        .get();
    final charges = await (_db.select(_db.orderCharges)
          ..where((c) => c.orderId.equals(orderId) & c.deletedAt.isNull()))
        .get();
    Money fee(String type) => charges
        .where((c) => c.type == type)
        .fold(Money.zero, (s, c) => s + Money(c.actualAmount ?? c.expectedAmount));

    final returned = <ReturnedLine>[];
    final stock = <StockChange>[];
    final lineCond = <String, ReturnCondition>{};
    for (final rl in viewNN.lines) {
      final cond = conditions[rl.orderLineId] ?? ReturnCondition.resellable;
      lineCond[rl.id] = cond;
      final ol = orderLines.where((l) => l.id == rl.orderLineId).firstOrNull;
      returned.add(ReturnedLine(
        qty: rl.qty,
        unitCost: ol?.unitCostPrice == null ? null : Money(ol!.unitCostPrice!),
        condition: cond,
      ));
    }
    final loss = ReturnLossCalculator.compute(
      fullReturn: full,
      lines: returned,
      deliveryFee: fee('delivery_fee'),
      returnFee: fee('return_fee'),
    );
    final distinct = lineCond.values.toSet();
    final summary = distinct.length == 1 ? distinct.first.dbValue : 'mixed';

    await _db.transaction(() async {
      for (final rl in viewNN.lines) {
        await (_db.update(_db.returnLines)..where((x) => x.id.equals(rl.id))).write(
          ReturnLinesCompanion(
            condition: Value(lineCond[rl.id]!.dbValue),
            updatedAt: Value(now),
          ),
        );
        // Resellable goods go back on the shelf (when stock tracking is on).
        if (settings.stockTrackingEnabled && lineCond[rl.id] == ReturnCondition.resellable) {
          final ol = orderLines.where((l) => l.id == rl.orderLineId).firstOrNull;
          final c = await _stock.adjust(
              productId: ol?.productId, variantId: ol?.variantId, delta: rl.qty);
          if (c != null) stock.add(c);
        }
      }
      await (_db.update(_db.returnRecords)..where((x) => x.id.equals(record.id))).write(
        ReturnRecordsCompanion(
          receivedBackAt: Value(at),
          condition: Value(summary),
          lossAmount: Value(loss.total.poisha),
          notes: Value((notes?.trim().isEmpty ?? true) ? record.notes : notes!.trim()),
          updatedAt: Value(now),
          rowVersion: Value(record.rowVersion + 1),
        ),
      );
      // An exchange return happens after the courier already remitted: the
      // original collection stands and the credit rides on the replacement.
      if (!full && o.codCollected != null && record.exchangeOrderId == null) {
        // Partial return: customer paid less, so the courier collected less.
        final profitLines = [
          for (final ol in orderLines)
            ProfitLine(
              name: ol.nameSnapshot,
              qty: ol.qty,
              unitSell: Money(ol.unitSellPrice),
              lineDiscount: Money(ol.lineDiscount),
              returnedQty: viewNN.lines
                  .where((r) => r.orderLineId == ol.id)
                  .fold(0, (s, r) => s + r.qty),
            ),
        ];
        final value = ProfitCalculator.returnedValue(profitLines, Money(o.discountTotal));
        final newCollected = Money(o.codCollected! - value.poisha);
        await (_db.update(_db.orders)..where((x) => x.id.equals(orderId))).write(
          OrdersCompanion(
            codCollected: Value(newCollected.isNegative ? 0 : newCollected.poisha),
            updatedAt: Value(now),
            rowVersion: Value(o.rowVersion + 1),
          ),
        );
        await _db.into(_db.orderEditLog).insert(OrderEditLogCompanion.insert(
              id: _ids.generate(),
              shopId: _shopId,
              createdAt: now,
              updatedAt: now,
              orderId: orderId,
              field: 'cod_collected (partial return)',
              oldValue: Value('${o.codCollected}'),
              newValue: Value('${newCollected.poisha}'),
              at: now,
            ));
      }
      await _ledger.refresh(orderId);
      await _audit.write(
          entity: 'return',
          entityId: record.id,
          action: 'received',
          payload: {'condition': summary, 'loss': loss.total.poisha});
    });

    if (full) {
      final r = await _status.changeStatus(orderId, to: OrderStatus.returned, at: at);
      if (!r.isOk) return Result.err(r.failureOrNull!);
    }
    final updated = await (_db.select(_db.returnRecords)..where((r) => r.id.equals(record.id)))
        .getSingle();
    return Result.ok(ReturnReceipt(record: updated, loss: loss, stockChanges: stock));
  }
}

final stockServiceProvider = Provider<StockService>((ref) =>
    StockService(ref.watch(databaseProvider), ref.watch(clockProvider)));

final returnServiceProvider = Provider<ReturnService>((ref) => ReturnService(
      ref.watch(databaseProvider),
      ref.watch(uuidProvider),
      ref.watch(clockProvider),
      ref.watch(auditWriterProvider),
      ref.watch(shopIdProvider),
      ref.watch(ledgerWriterProvider),
      ref.watch(orderStatusServiceProvider),
      ref.watch(stockServiceProvider),
      ref.watch(settingsRepositoryProvider),
    ));
