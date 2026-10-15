import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parcel_khata/core/db/app_database.dart';
import 'package:parcel_khata/core/db/providers.dart';
import 'package:parcel_khata/core/ids/uuid_v7.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/core/providers.dart';
import 'package:parcel_khata/core/time/clock.dart';
import 'package:parcel_khata/core/time/providers.dart';
import 'package:parcel_khata/features/cod/application/ledger_writer.dart';
import 'package:parcel_khata/features/cod/application/payout_service.dart';
import 'package:parcel_khata/features/orders/domain/order_enums.dart';
import 'package:parcel_khata/features/profit/domain/profit_calculator.dart';

class CustomerStats {
  const CustomerStats({
    required this.orders,
    required this.delivered,
    required this.returned,
    required this.revenue,
    required this.profit,
    required this.lastOrderAt,
  });

  final int orders;
  final int delivered;
  final int returned;

  /// Money the customer paid for goods + delivery on delivered orders.
  final Money revenue;

  /// Sum of non-incomplete order profits (provisional + final).
  final Money profit;
  final DateTime? lastOrderAt;

  double get deliveredPct => orders == 0 ? 0 : delivered * 100 / orders;
  double get returnedPct => orders == 0 ? 0 : returned * 100 / orders;
}

/// An order line with an unknown cost, for the fix-it flow.
class MissingCostLine {
  const MissingCostLine(this.order, this.line);
  final Order order;
  final OrderLine line;
}

class ProfitQueries {
  ProfitQueries(this._db, this._ids, this._clock, this._shopId, this._ledger);

  final AppDatabase _db;
  final UuidV7 _ids;
  final Clock _clock;
  final String _shopId;
  final LedgerWriter _ledger;

  Future<CustomerStats> customerStats(String customerId) async {
    final rows = await (_db.select(_db.orders)
          ..where((o) =>
              o.customerId.equals(customerId) &
              o.deletedAt.isNull() &
              o.status.equals(OrderStatus.draft.dbValue).not()))
        .get();
    var delivered = 0;
    var returned = 0;
    var revenue = Money.zero;
    var profit = Money.zero;
    DateTime? last;
    for (final o in rows) {
      if (last == null || o.orderDate.isAfter(last)) last = o.orderDate;
      final s = OrderStatus.fromDb(o.status);
      if (s == OrderStatus.delivered) {
        delivered++;
        revenue += Money(o.itemsTotal - o.discountTotal + o.deliveryChargeCustomer);
      }
      if (s == OrderStatus.returned ||
          s == OrderStatus.returnInTransit ||
          s == OrderStatus.deliveryFailed) {
        returned++;
      }
      if (o.profit != null && o.profitState != ProfitState.incomplete.dbValue) {
        profit += Money(o.profit!);
      }
    }
    return CustomerStats(
      orders: rows.length,
      delivered: delivered,
      returned: returned,
      revenue: revenue,
      profit: profit,
      lastOrderAt: last,
    );
  }

  /// Lines with a missing cost on orders that still need it, newest first.
  Future<List<MissingCostLine>> missingCosts() async {
    final q = _db.select(_db.orderLines).join([
      innerJoin(_db.orders, _db.orders.id.equalsExp(_db.orderLines.orderId)),
    ])
      ..where(_db.orderLines.unitCostPrice.isNull() &
          _db.orderLines.deletedAt.isNull() &
          _db.orders.deletedAt.isNull() &
          _db.orders.shopId.equals(_shopId) &
          _db.orders.status.isNotIn([
            OrderStatus.draft.dbValue,
            OrderStatus.cancelled.dbValue,
          ]))
      ..orderBy([OrderingTerm.desc(_db.orders.orderDate)]);
    return [
      for (final r in await q.get())
        MissingCostLine(r.readTable(_db.orders), r.readTable(_db.orderLines)),
    ];
  }

  /// Sets the cost on a line (and optionally the catalog default) and
  /// recomputes the order's profit in the same transaction.
  Future<void> setLineCost(
    String orderLineId,
    Money cost, {
    bool updateCatalog = false,
  }) async {
    final line = await (_db.select(_db.orderLines)..where((l) => l.id.equals(orderLineId)))
        .getSingleOrNull();
    if (line == null) return;
    final now = _clock.now();
    await _db.transaction(() async {
      await (_db.update(_db.orderLines)..where((l) => l.id.equals(orderLineId))).write(
        OrderLinesCompanion(unitCostPrice: Value(cost.poisha), updatedAt: Value(now)),
      );
      await _db.into(_db.orderEditLog).insert(OrderEditLogCompanion.insert(
            id: _ids.generate(),
            shopId: _shopId,
            createdAt: now,
            updatedAt: now,
            orderId: line.orderId,
            field: 'unit_cost (${line.nameSnapshot})',
            oldValue: const Value(null),
            newValue: Value('${cost.poisha}'),
            at: now,
          ));
      if (updateCatalog && line.productId != null) {
        await (_db.update(_db.products)..where((p) => p.id.equals(line.productId!))).write(
          ProductsCompanion(defaultCostPrice: Value(cost.poisha), updatedAt: Value(now)),
        );
      }
      await _ledger.refresh(line.orderId);
    });
  }
}

final profitQueriesProvider = Provider<ProfitQueries>((ref) => ProfitQueries(
      ref.watch(databaseProvider),
      ref.watch(uuidProvider),
      ref.watch(clockProvider),
      ref.watch(shopIdProvider),
      ref.watch(ledgerWriterProvider),
    ));
