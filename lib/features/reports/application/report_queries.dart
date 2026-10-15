import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parcel_khata/core/db/app_database.dart';
import 'package:parcel_khata/core/db/providers.dart';
import 'package:parcel_khata/features/orders/application/order_repository.dart';
import 'package:parcel_khata/features/orders/domain/order_enums.dart';
import 'package:parcel_khata/features/orders/domain/order_filter.dart';
import 'package:parcel_khata/features/reports/domain/report_math.dart';

enum ReportGroup { day, courier, channel, customer, product, area }

/// One row of a grouped report. All money is in poisha.
class GroupRow {
  const GroupRow({
    required this.key,
    required this.label,
    this.orders = 0,
    this.delivered = 0,
    this.failedOrReturned = 0,
    this.dispatched = 0,
    this.revenue = 0,
    this.profit = 0,
    this.profitFinal = 0,
    this.profitProvisional = 0,
    this.incomplete = 0,
    this.grossCounted = 0,
    this.profitCounted = 0,
    this.units = 0,
    this.returnedUnits = 0,
  });

  final String key;
  final String label;
  final int orders;
  final int delivered;
  final int failedOrReturned;
  final int dispatched;
  final int revenue;
  final int profit;
  final int profitFinal;
  final int profitProvisional;
  final int incomplete;
  final int grossCounted;
  final int profitCounted;
  final int units;
  final int returnedUnits;

  int? get marginBp => ReportMath.marginBp(profit: profitCounted, revenue: grossCounted);
  double? get deliverySuccess =>
      ReportMath.deliverySuccessRate(delivered: delivered, failed: failedOrReturned);
  double? get returnRate =>
      ReportMath.returnRate(returned: failedOrReturned, dispatched: dispatched);
}

class CourierPerformance {
  const CourierPerformance({
    required this.courierId,
    required this.name,
    required this.parcels,
    required this.delivered,
    required this.failedOrReturned,
    required this.avgDeliveryDays,
    required this.avgPayoutLagDays,
    required this.totalFees,
    required this.shortfalls,
  });

  final String courierId;
  final String name;
  final int parcels;
  final int delivered;
  final int failedOrReturned;
  final double? avgDeliveryDays;
  final double? avgPayoutLagDays;
  final int totalFees;

  /// Written-off + currently disputed amounts.
  final int shortfalls;

  double? get deliveredPct => parcels == 0 ? null : delivered / parcels;
  double? get returnPct => parcels == 0 ? null : failedOrReturned / parcels;
}

class DailyRow {
  const DailyRow(this.day, this.created, this.dispatched, this.delivered, this.failed,
      this.codCollected);
  final DateTime day;
  final int created;
  final int dispatched;
  final int delivered;
  final int failed;
  final int codCollected;
}

class ReasonRow {
  const ReasonRow(this.reason, this.count, this.loss);
  final String reason;
  final int count;
  final int loss;
}

class ReportQueries {
  ReportQueries(this._db, this._orders);

  final AppDatabase _db;
  final OrderRepository _orders;

  static const _localDay = "date(orders.order_date, 'unixepoch', 'localtime')";

  // ------------------------------------------------------- grouped profit

  /// Orders, revenue and profit grouped by [by] for the rows [filter] selects.
  /// Every row's figures sum to the plain totals for the same filter.
  Future<List<GroupRow>> grouped(OrderFilter filter, ReportGroup by) async {
    if (by == ReportGroup.product) return _byProduct(filter);
    final o = _db.orders;
    final where = await _orders.whereFor(filter);
    final Expression<String> key = switch (by) {
      ReportGroup.day => CustomExpression<String>(_localDay),
      ReportGroup.courier => coalesce<String>([o.courierId, const Constant('')]),
      ReportGroup.channel => o.channel,
      ReportGroup.customer => coalesce<String>([o.customerId, const Constant('')]),
      ReportGroup.area => CustomExpression<String>(
          "COALESCE((SELECT a.district FROM customer_addresses a WHERE a.customer_id = orders.customer_id "
          "AND a.deleted_at IS NULL ORDER BY a.is_default DESC LIMIT 1), '')",
        ),
      ReportGroup.product => throw StateError('handled above'),
    };
    final delivered = o.status.equals(OrderStatus.delivered.dbValue);
    final failed = o.status.isIn([
      OrderStatus.deliveryFailed.dbValue,
      OrderStatus.returnInTransit.dbValue,
      OrderStatus.returned.dbValue,
    ]);
    final dispatched = o.status.isIn([
      OrderStatus.handedToCourier.dbValue,
      OrderStatus.inTransit.dbValue,
      OrderStatus.delivered.dbValue,
      OrderStatus.deliveryFailed.dbValue,
      OrderStatus.returnInTransit.dbValue,
      OrderStatus.returned.dbValue,
    ]);
    final incompl = o.profitState.equals('incomplete');
    final cnt = o.id.count();
    final cDelivered = o.id.count(filter: delivered);
    final cFailed = o.id.count(filter: failed);
    final cDispatched = o.id.count(filter: dispatched);
    final revenue = o.grossCollected.sum(filter: delivered);
    final profit = o.profit.sum();
    final pFinal = o.profit.sum(filter: o.profitState.equals('final'));
    final pProv = o.profit.sum(filter: o.profitState.equals('provisional'));
    final cIncomplete = o.id.count(filter: incompl);
    final gross = o.grossCollected.sum(filter: incompl.not());
    final pCounted = o.profit.sum(filter: incompl.not());
    final rows = await (_db.selectOnly(o)
          ..addColumns([
            key,
            cnt,
            cDelivered,
            cFailed,
            cDispatched,
            revenue,
            profit,
            pFinal,
            pProv,
            cIncomplete,
            gross,
            pCounted,
          ])
          ..where(where)
          ..groupBy([key]))
        .get();
    final names = await _names(by);
    int n(TypedResult r, Expression<num> e) => (r.read(e) ?? 0).toInt();
    final out = [
      for (final r in rows)
        () {
          final k = r.read(key) ?? '';
          return GroupRow(
            key: k,
            label: by == ReportGroup.day || by == ReportGroup.channel ? k : (names[k] ?? k),
            orders: n(r, cnt),
            delivered: n(r, cDelivered),
            failedOrReturned: n(r, cFailed),
            dispatched: n(r, cDispatched),
            revenue: n(r, revenue),
            profit: n(r, profit),
            profitFinal: n(r, pFinal),
            profitProvisional: n(r, pProv),
            incomplete: n(r, cIncomplete),
            grossCounted: n(r, gross),
            profitCounted: n(r, pCounted),
          );
        }(),
    ];
    if (by == ReportGroup.day) {
      out.sort((a, b) => a.key.compareTo(b.key));
    } else {
      out.sort((a, b) => b.profit.compareTo(a.profit));
    }
    return out;
  }

  Future<Map<String, String>> _names(ReportGroup by) async {
    switch (by) {
      case ReportGroup.courier:
        return {for (final c in await _db.select(_db.couriers).get()) c.id: c.name};
      case ReportGroup.customer:
        return {for (final c in await _db.select(_db.customers).get()) c.id: c.name};
      default:
        return const {};
    }
  }

  Future<List<GroupRow>> _byProduct(OrderFilter filter) async {
    final o = _db.orders;
    final l = _db.orderLines;
    final where = await _orders.whereFor(filter);
    final key = coalesce<String>([l.productId, l.nameSnapshot]);
    final units = l.qty.sum();
    final revenue = (l.qty * l.unitSellPrice - l.lineDiscount).sum();
    final cost = (l.qty * l.unitCostPrice).sum();
    final orders = l.orderId.count(distinct: true);
    final label = l.nameSnapshot.max();
    final rows = await (_db.selectOnly(l).join([
      innerJoin(o, o.id.equalsExp(l.orderId)),
    ])
          ..addColumns([key, units, revenue, cost, orders, label])
          ..where(where & l.deletedAt.isNull())
          ..groupBy([key]))
        .get();
    // Returned units per product (return lines -> order lines).
    final rl = _db.returnLines;
    final rKey = coalesce<String>([l.productId, l.nameSnapshot]);
    final rUnits = rl.qty.sum();
    final rrows = await (_db.selectOnly(rl).join([
      innerJoin(l, l.id.equalsExp(rl.orderLineId)),
      innerJoin(o, o.id.equalsExp(l.orderId)),
    ])
          ..addColumns([rKey, rUnits])
          ..where(where & rl.deletedAt.isNull())
          ..groupBy([rKey]))
        .get();
    final returned = <String, int>{
      for (final r in rrows) r.read(rKey) ?? '': (r.read(rUnits) ?? 0).toInt(),
    };
    final out = [
      for (final r in rows)
        () {
          final k = r.read(key) ?? '';
          final rev = (r.read(revenue) ?? 0).toInt();
          final c = (r.read(cost) ?? 0).toInt();
          return GroupRow(
            key: k,
            label: r.read(label) ?? k,
            orders: (r.read(orders) ?? 0).toInt(),
            units: (r.read(units) ?? 0).toInt(),
            returnedUnits: returned[k] ?? 0,
            revenue: rev,
            // Goods margin: sales minus product cost (before courier fees).
            profit: rev - c,
            grossCounted: rev,
            profitCounted: rev - c,
          );
        }(),
    ]..sort((a, b) => b.profit.compareTo(a.profit));
    return out;
  }

  // ------------------------------------------------------------ daily

  Future<List<DailyRow>> daily(DatePeriod p) async {
    final created = await _countByDay(
        "orders.order_date", "orders.status != 'draft'", p);
    final dispatched = await _countByDay("orders.handed_over_at", '1=1', p);
    final delivered = await _countByDay("orders.delivered_at", '1=1', p);
    final failed = await _db
        .customSelect(
          "SELECT date(e.at, 'unixepoch', 'localtime') AS d, COUNT(*) AS n "
          'FROM order_status_events e JOIN orders ON orders.id = e.order_id '
          "WHERE e.to_status = 'delivery_failed' AND orders.deleted_at IS NULL "
          'AND e.at >= ? AND e.at < ? GROUP BY d',
          variables: [Variable<DateTime>(p.from), Variable<DateTime>(p.to)],
        )
        .get();
    final failedBy = {for (final r in failed) r.read<String>('d'): r.read<int>('n')};
    final cod = await _db
        .customSelect(
          "SELECT date(orders.delivered_at, 'unixepoch', 'localtime') AS d, "
          'COALESCE(SUM(orders.cod_collected), 0) AS s FROM orders '
          'WHERE orders.deleted_at IS NULL AND orders.delivered_at >= ? AND orders.delivered_at < ? '
          'GROUP BY d',
          variables: [Variable<DateTime>(p.from), Variable<DateTime>(p.to)],
        )
        .get();
    final codBy = {for (final r in cod) r.read<String>('d'): r.read<int>('s')};
    final out = <DailyRow>[];
    for (var d = p.from; d.isBefore(p.to); d = DateTime(d.year, d.month, d.day + 1)) {
      final k = _fmtDay(d);
      out.add(DailyRow(d, created[k] ?? 0, dispatched[k] ?? 0, delivered[k] ?? 0,
          failedBy[k] ?? 0, codBy[k] ?? 0));
    }
    return out;
  }

  Future<Map<String, int>> _countByDay(String column, String extra, DatePeriod p) async {
    final rows = await _db
        .customSelect(
          "SELECT date($column, 'unixepoch', 'localtime') AS d, COUNT(*) AS n FROM orders "
          'WHERE orders.deleted_at IS NULL AND $extra AND $column >= ? AND $column < ? GROUP BY d',
          variables: [Variable<DateTime>(p.from), Variable<DateTime>(p.to)],
        )
        .get();
    return {for (final r in rows) r.read<String>('d'): r.read<int>('n')};
  }

  static String _fmtDay(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Cash received through payouts in the period.
  Future<int> payoutsReceived(DatePeriod p) async {
    final r = await _db
        .customSelect(
          "SELECT COALESCE(SUM(total_received), 0) AS s FROM payouts "
          "WHERE status = 'active' AND deleted_at IS NULL AND paid_at >= ? AND paid_at < ?",
          variables: [Variable<DateTime>(p.from), Variable<DateTime>(p.to)],
        )
        .getSingle();
    return r.read<int>('s');
  }

  // --------------------------------------------------------- couriers

  Future<List<CourierPerformance>> courierPerformance(DatePeriod p) async {
    final rows = await _db.customSelect(
      '''
SELECT c.id AS id, c.name AS name,
  COUNT(o.id) AS parcels,
  SUM(CASE WHEN o.status = 'delivered' THEN 1 ELSE 0 END) AS delivered,
  SUM(CASE WHEN o.status IN ('delivery_failed','return_in_transit','returned') THEN 1 ELSE 0 END) AS failed,
  AVG(CASE WHEN o.status = 'delivered' AND o.delivered_at IS NOT NULL AND o.handed_over_at IS NOT NULL
      THEN (o.delivered_at - o.handed_over_at) / 86400.0 END) AS avg_delivery,
  (SELECT AVG((p.paid_at - o2.delivered_at) / 86400.0)
     FROM payout_allocations pa
     JOIN payouts p ON p.id = pa.payout_id AND p.status = 'active'
     JOIN orders o2 ON o2.id = pa.order_id
    WHERE o2.courier_id = c.id AND o2.delivered_at IS NOT NULL
      AND o2.order_date >= ?1 AND o2.order_date < ?2) AS avg_lag,
  COALESCE((SELECT SUM(COALESCE(ch.actual_amount, ch.expected_amount))
     FROM order_charges ch JOIN orders o3 ON o3.id = ch.order_id
    WHERE o3.courier_id = c.id AND o3.deleted_at IS NULL AND ch.deleted_at IS NULL
      AND ch.type IN ('delivery_fee','cod_fee','return_fee','other')
      AND o3.order_date >= ?1 AND o3.order_date < ?2), 0) AS fees,
  COALESCE((SELECT SUM(COALESCE(ch.actual_amount, ch.expected_amount))
     FROM order_charges ch JOIN orders o4 ON o4.id = ch.order_id
    WHERE o4.courier_id = c.id AND o4.deleted_at IS NULL AND ch.deleted_at IS NULL
      AND ch.type = 'write_off'
      AND o4.order_date >= ?1 AND o4.order_date < ?2), 0)
  + COALESCE((SELECT SUM(o5.outstanding) FROM orders o5
    WHERE o5.courier_id = c.id AND o5.deleted_at IS NULL AND o5.cod_status = 'disputed'
      AND o5.order_date >= ?1 AND o5.order_date < ?2), 0) AS shortfalls
FROM couriers c
LEFT JOIN orders o ON o.courier_id = c.id AND o.deleted_at IS NULL
  AND o.status IN ('handed_to_courier','in_transit','delivered','delivery_failed','return_in_transit','returned')
  AND o.order_date >= ?1 AND o.order_date < ?2
WHERE c.deleted_at IS NULL
GROUP BY c.id, c.name
ORDER BY parcels DESC
''',
      variables: [Variable<DateTime>(p.from), Variable<DateTime>(p.to)],
    ).get();
    return [
      for (final r in rows)
        CourierPerformance(
          courierId: r.read<String>('id'),
          name: r.read<String>('name'),
          parcels: r.read<int>('parcels'),
          delivered: r.read<int?>('delivered') ?? 0,
          failedOrReturned: r.read<int?>('failed') ?? 0,
          avgDeliveryDays: r.read<double?>('avg_delivery'),
          avgPayoutLagDays: r.read<double?>('avg_lag'),
          totalFees: r.read<int>('fees'),
          shortfalls: r.read<int>('shortfalls'),
        ),
    ];
  }

  // ---------------------------------------------------------- returns

  Future<List<ReasonRow>> returnsByReason(DatePeriod p) async {
    final rows = await _db
        .customSelect(
          'SELECT r.reason AS reason, COUNT(*) AS n, COALESCE(SUM(r.loss_amount), 0) AS loss '
          'FROM return_records r JOIN orders o ON o.id = r.order_id '
          'WHERE r.deleted_at IS NULL AND o.deleted_at IS NULL '
          'AND r.initiated_at >= ? AND r.initiated_at < ? GROUP BY r.reason ORDER BY n DESC',
          variables: [Variable<DateTime>(p.from), Variable<DateTime>(p.to)],
        )
        .get();
    return [
      for (final r in rows)
        ReasonRow(r.read<String>('reason'), r.read<int>('n'), r.read<int>('loss')),
    ];
  }

  Future<List<ReasonRow>> returnsByCourier(DatePeriod p) async {
    final rows = await _db
        .customSelect(
          "SELECT COALESCE(c.name, '') AS reason, COUNT(*) AS n, "
          'COALESCE(SUM(r.loss_amount), 0) AS loss '
          'FROM return_records r JOIN orders o ON o.id = r.order_id '
          'LEFT JOIN couriers c ON c.id = o.courier_id '
          'WHERE r.deleted_at IS NULL AND o.deleted_at IS NULL '
          'AND r.initiated_at >= ? AND r.initiated_at < ? GROUP BY c.name ORDER BY n DESC',
          variables: [Variable<DateTime>(p.from), Variable<DateTime>(p.to)],
        )
        .get();
    return [
      for (final r in rows)
        ReasonRow(r.read<String>('reason'), r.read<int>('n'), r.read<int>('loss')),
    ];
  }

  Future<List<ReasonRow>> returnsByProduct(DatePeriod p) async {
    final rows = await _db
        .customSelect(
          'SELECT l.name_snapshot AS reason, SUM(rl.qty) AS n, '
          'COALESCE(SUM(rl.qty * COALESCE(l.unit_cost_price, 0)), 0) AS loss '
          'FROM return_lines rl JOIN return_records r ON r.id = rl.return_id '
          'JOIN order_lines l ON l.id = rl.order_line_id '
          'JOIN orders o ON o.id = r.order_id '
          'WHERE rl.deleted_at IS NULL AND r.deleted_at IS NULL AND o.deleted_at IS NULL '
          'AND r.initiated_at >= ? AND r.initiated_at < ? GROUP BY l.name_snapshot ORDER BY n DESC',
          variables: [Variable<DateTime>(p.from), Variable<DateTime>(p.to)],
        )
        .get();
    return [
      for (final r in rows)
        ReasonRow(r.read<String>('reason'), r.read<int>('n'), r.read<int>('loss')),
    ];
  }
}

final reportQueriesProvider = Provider<ReportQueries>((ref) => ReportQueries(
      ref.watch(databaseProvider),
      ref.watch(orderRepositoryProvider),
    ));
