import 'package:drift/drift.dart';
import 'package:parcel_khata/core/db/app_database.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/features/cod/domain/cod_status_resolver.dart';
import 'package:parcel_khata/features/cod/domain/ledger.dart';
import 'package:parcel_khata/features/orders/domain/order_enums.dart';
import 'package:parcel_khata/features/profit/application/profit_input_builder.dart';
import 'package:parcel_khata/features/profit/domain/profit_calculator.dart';

/// Computes and caches an order's ledger + COD status. Always call inside the
/// transaction that changed money or status so cached values never drift.
class LedgerWriter {
  LedgerWriter(this._db);

  final AppDatabase _db;

  /// Ledger state from the current rows, or null when nothing was collected.
  Future<OrderLedgerState?> compute(String orderId) async {
    final o = await (_db.select(_db.orders)..where((x) => x.id.equals(orderId)))
        .getSingleOrNull();
    if (o == null || o.codCollected == null) return null;
    return _state(o);
  }

  Future<OrderLedgerState> _state(Order o) async {
    final charges = await (_db.select(_db.orderCharges)
          ..where((c) => c.orderId.equals(o.id) & c.deletedAt.isNull()))
        .get();
    final settled = await settledFor(o.id);
    final status = OrderStatus.fromDb(o.status);
    final record = await (_db.select(_db.returnRecords)
          ..where((r) => r.orderId.equals(o.id) & r.deletedAt.isNull()))
        .getSingleOrNull();
    final hasReturn = record != null ||
        status == OrderStatus.deliveryFailed ||
        status == OrderStatus.returnInTransit ||
        status == OrderStatus.returned;
    return LedgerCalculator.state(
      collected: Money(o.codCollected ?? 0),
      charges: relevantCharges([
        for (final c in charges)
          ChargeAmount(
            type: c.type,
            expected: Money(c.expectedAmount),
            actual: c.actualAmount == null ? null : Money(c.actualAmount!),
          ),
      ], hasReturn: hasReturn),
      settled: settled,
      isDisputed: o.isDisputed,
    );
  }

  /// Cash applied through payouts that are still active.
  Future<Money> settledFor(String orderId) async {
    final sum = _db.payoutAllocations.amountApplied.sum();
    final row = await (_db.selectOnly(_db.payoutAllocations).join([
      innerJoin(_db.payouts, _db.payouts.id.equalsExp(_db.payoutAllocations.payoutId)),
    ])
          ..addColumns([sum])
          ..where(_db.payoutAllocations.orderId.equals(orderId) &
              _db.payoutAllocations.deletedAt.isNull() &
              _db.payouts.status.equals('active')))
        .getSingle();
    return Money(row.read(sum) ?? 0);
  }

  /// Recomputes cod_status, net_receivable and outstanding for one order.
  Future<void> refresh(String orderId) async {
    final o = await (_db.select(_db.orders)..where((x) => x.id.equals(orderId)))
        .getSingleOrNull();
    if (o == null) return;
    final ledger = o.codCollected == null ? null : await _state(o);
    final status = CodStatusResolver.resolve(CodStatusInput(
      paymentType: PaymentType.fromDb(o.paymentType),
      codExpected: Money(o.codExpected),
      status: OrderStatus.fromDb(o.status),
      ledger: ledger,
    ));
    await (_db.update(_db.orders)..where((x) => x.id.equals(orderId))).write(
      OrdersCompanion(
        codStatus: Value(status.dbValue),
        netReceivable: Value(ledger?.netReceivable.poisha),
        outstanding: Value(ledger?.outstanding.poisha),
      ),
    );
    await _refreshProfit(orderId);
  }

  /// Recomputes the cached profit and its Provisional/Final/Incomplete label.
  /// The status written above is already visible to this read.
  Future<void> _refreshProfit(String orderId) async {
    final o = await (_db.select(_db.orders)..where((x) => x.id.equals(orderId)))
        .getSingleOrNull();
    if (o == null) return;
    final lines = await (_db.select(_db.orderLines)
          ..where((l) => l.orderId.equals(orderId) & l.deletedAt.isNull()))
        .get();
    final charges = await (_db.select(_db.orderCharges)
          ..where((c) => c.orderId.equals(orderId) & c.deletedAt.isNull()))
        .get();
    final record = await (_db.select(_db.returnRecords)
          ..where((r) => r.orderId.equals(orderId) & r.deletedAt.isNull()))
        .getSingleOrNull();
    final returnLines = record == null
        ? <ReturnLine>[]
        : await (_db.select(_db.returnLines)
              ..where((r) => r.returnId.equals(record.id) & r.deletedAt.isNull()))
            .get();
    final result = ProfitCalculator.compute(ProfitInputBuilder.build(
      order: o,
      lines: lines,
      charges: charges,
      returnLines: returnLines,
      hasReturnRecord: record != null,
    ));
    await (_db.update(_db.orders)..where((x) => x.id.equals(orderId))).write(
      OrdersCompanion(
        profit: Value(result.net.poisha),
        profitState: Value(result.state.dbValue),
        grossCollected: Value(result.grossCollected.poisha),
      ),
    );
  }

  /// "Repair derived fields" for every order (debug / maintenance).
  Future<int> repairAll() async {
    final ids = await (_db.selectOnly(_db.orders)..addColumns([_db.orders.id])).get();
    await _db.transaction(() async {
      for (final r in ids) {
        await refresh(r.read(_db.orders.id)!);
      }
    });
    return ids.length;
  }
}
