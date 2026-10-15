import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parcel_khata/core/time/providers.dart';
import 'package:parcel_khata/features/cod/application/cod_queries.dart';
import 'package:parcel_khata/features/orders/application/order_repository.dart';
import 'package:parcel_khata/features/orders/application/order_status_service.dart';
import 'package:parcel_khata/features/orders/domain/order_enums.dart';
import 'package:parcel_khata/features/orders/domain/order_filter.dart';
import 'package:parcel_khata/features/profit/domain/profit_calculator.dart';
import 'package:parcel_khata/features/reports/domain/report_math.dart';

enum TileId {
  pending,
  inTransitCod,
  disputed,
  settled,
  ordersInPeriod,
  toDispatch,
  inTransit,
  stuck,
  returnsAwaiting,
  revenue,
  profitFinal,
  profitProvisional,
  margin,
  deliverySuccess,
  returnRate,
  avgProfit,
}

/// What a tile (and the header of its drill-down list) measures.
enum Measure {
  count,
  outstanding,
  codExpected,
  revenue,
  profitFinal,
  profitProvisional,
  margin,
  deliverySuccess,
  returnRate,
  avgProfit,
}

class TileData {
  const TileData({
    required this.id,
    required this.filter,
    required this.measure,
    required this.value,
    required this.count,
  });

  final TileId id;

  /// The exact filter whose rows the tile summarizes; drill-down uses it.
  final OrderFilter filter;
  final Measure measure;

  /// Money in poisha, a count, a rate (0..1) or basis points, by [measure].
  final num? value;
  final int count;
}

/// Reads a measure off [FilterTotals]; shared by tiles and drill-down headers.
num? measureValue(Measure m, FilterTotals t) => switch (m) {
      Measure.count => t.count,
      Measure.outstanding => t.outstanding,
      Measure.codExpected => t.codExpected,
      Measure.revenue => t.revenue,
      Measure.profitFinal => t.profitFinal,
      Measure.profitProvisional => t.profitProvisional,
      Measure.margin => ReportMath.marginBp(profit: t.profitCounted, revenue: t.grossCounted),
      Measure.deliverySuccess =>
        ReportMath.deliverySuccessRate(delivered: t.delivered, failed: t.failedOrReturned),
      Measure.returnRate =>
        ReportMath.returnRate(returned: t.failedOrReturned, dispatched: t.dispatched),
      Measure.avgProfit =>
        ReportMath.averagePerOrder(total: t.profitCounted, count: t.countedOrders),
    };

class DashboardData {
  const DashboardData({required this.period, required this.tiles, required this.settled});

  final DatePeriod period;
  final Map<TileId, TileData> tiles;

  /// Cash received from couriers in the period (not an order filter).
  final int settled;
}

class DashboardService {
  DashboardService(this._orders, this._status, this._cod);

  final OrderRepository _orders;
  final OrderStatusService _status;
  final CodQueries _cod;

  Future<DashboardData> load(DatePeriod period) async {
    final perf = OrderFilter(from: period.from, to: period.to);
    final defs = <TileId, (OrderFilter, Measure)>{
      TileId.pending: (
        const OrderFilter(
            codStatuses: {CodStatus.collectedByCourier, CodStatus.partiallySettled}),
        Measure.outstanding,
      ),
      TileId.inTransitCod: (
        const OrderFilter(
          statuses: {OrderStatus.handedToCourier, OrderStatus.inTransit},
          codStatuses: {CodStatus.pendingCollection},
        ),
        Measure.codExpected,
      ),
      TileId.disputed: (
        const OrderFilter(codStatuses: {CodStatus.disputed}),
        Measure.outstanding,
      ),
      TileId.ordersInPeriod: (perf, Measure.count),
      TileId.toDispatch: (
        const OrderFilter(statuses: {OrderStatus.confirmed, OrderStatus.packed}),
        Measure.count,
      ),
      TileId.inTransit: (
        const OrderFilter(statuses: {OrderStatus.handedToCourier, OrderStatus.inTransit}),
        Measure.count,
      ),
      TileId.returnsAwaiting: (
        const OrderFilter(
            statuses: {OrderStatus.deliveryFailed, OrderStatus.returnInTransit}),
        Measure.count,
      ),
      TileId.revenue: (perf.copyWith(statuses: {OrderStatus.delivered}), Measure.revenue),
      TileId.profitFinal: (
        perf.copyWith(profitStates: {ProfitState.finalised}),
        Measure.profitFinal,
      ),
      TileId.profitProvisional: (
        perf.copyWith(profitStates: {ProfitState.provisional}),
        Measure.profitProvisional,
      ),
      TileId.margin: (
        perf.copyWith(profitStates: {ProfitState.provisional, ProfitState.finalised}),
        Measure.margin,
      ),
      TileId.deliverySuccess: (
        perf.copyWith(statuses: {
          OrderStatus.delivered,
          OrderStatus.deliveryFailed,
          OrderStatus.returnInTransit,
          OrderStatus.returned,
        }),
        Measure.deliverySuccess,
      ),
      TileId.returnRate: (
        perf.copyWith(statuses: {
          OrderStatus.handedToCourier,
          OrderStatus.inTransit,
          OrderStatus.delivered,
          OrderStatus.deliveryFailed,
          OrderStatus.returnInTransit,
          OrderStatus.returned,
        }),
        Measure.returnRate,
      ),
      TileId.avgProfit: (
        perf.copyWith(profitStates: {ProfitState.provisional, ProfitState.finalised}),
        Measure.avgProfit,
      ),
    };
    final tiles = <TileId, TileData>{};
    for (final e in defs.entries) {
      final t = await _orders.totals(e.value.$1);
      tiles[e.key] = TileData(
        id: e.key,
        filter: e.value.$1,
        measure: e.value.$2,
        value: measureValue(e.value.$2, t),
        count: t.count,
      );
    }
    final stuck = await _status.stuckOrders();
    tiles[TileId.stuck] = TileData(
      id: TileId.stuck,
      filter: OrderFilter.empty,
      measure: Measure.count,
      value: stuck.length,
      count: stuck.length,
    );
    final settled = await _cod.settledBetween(period.from, period.to);
    return DashboardData(period: period, tiles: tiles, settled: settled);
  }
}

final dashboardServiceProvider = Provider<DashboardService>((ref) => DashboardService(
      ref.watch(orderRepositoryProvider),
      ref.watch(orderStatusServiceProvider),
      ref.watch(codQueriesProvider),
    ));

final periodPresetProvider =
    NotifierProvider<PeriodNotifier, PeriodPreset>(PeriodNotifier.new);

class PeriodNotifier extends Notifier<PeriodPreset> {
  @override
  PeriodPreset build() => PeriodPreset.thisMonth;

  // ignore: use_setters_to_change_properties
  void set(PeriodPreset p) => state = p;
}

final customPeriodProvider =
    NotifierProvider<CustomPeriodNotifier, DatePeriod?>(CustomPeriodNotifier.new);

class CustomPeriodNotifier extends Notifier<DatePeriod?> {
  @override
  DatePeriod? build() => null;

  // ignore: use_setters_to_change_properties
  void set(DatePeriod? p) => state = p;
}

final currentPeriodProvider = Provider<DatePeriod>((ref) {
  final now = ref.watch(clockProvider).now();
  return DatePeriod.resolve(
    ref.watch(periodPresetProvider),
    now,
    custom: ref.watch(customPeriodProvider),
  );
});

/// Refreshes dashboard figures whenever orders or payouts change.
final dashboardProvider = FutureProvider<DashboardData>((ref) async {
  ref.watch(codRevisionProvider);
  final period = ref.watch(currentPeriodProvider);
  return ref.watch(dashboardServiceProvider).load(period);
});
