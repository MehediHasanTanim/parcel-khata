import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:parcel_khata/core/ads/ads_policy.dart';
import 'package:parcel_khata/shared/ad_slot.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/core/time/providers.dart';
import 'package:parcel_khata/features/cod/application/cod_queries.dart';
import 'package:parcel_khata/features/expenses/application/pnl_queries.dart';
import 'package:parcel_khata/features/expenses/domain/business_pnl.dart';
import 'package:parcel_khata/features/expenses/presentation/expenses_screen.dart';
import 'package:parcel_khata/features/orders/application/order_repository.dart';
import 'package:parcel_khata/features/orders/domain/order_filter.dart';
import 'package:parcel_khata/features/orders/presentation/order_labels.dart';
import 'package:parcel_khata/features/orders/presentation/status_actions.dart';
import 'package:parcel_khata/features/profit/domain/profit_calculator.dart';
import 'package:parcel_khata/features/reports/application/report_queries.dart';
import 'package:parcel_khata/features/reports/domain/report_math.dart';
import 'package:parcel_khata/features/reports/presentation/format.dart';
import 'package:parcel_khata/l10n/l10n.dart';
import 'package:parcel_khata/shared/empty_state.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

enum ReportKind { daily, ageing, courier, profit, returns, pnl }

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget item(IconData icon, String title, ReportKind k) => ListTile(
          leading: Icon(icon),
          title: Text(title),
          trailing: const Icon(LucideIcons300.chevronRight),
          onTap: () => context.push('/reports/${k.name}'),
        );
    return Scaffold(
      appBar: AppBar(title: Text(l.reportsTitle)),
      body: Column(children: [
        Expanded(
          child: ListView(children: [
        item(LucideIcons300.calendarDays, l.reportDaily, ReportKind.daily),
        item(LucideIcons300.hourglass, l.ageingTitle, ReportKind.ageing),
        item(LucideIcons300.truck, l.reportCourier, ReportKind.courier),
        item(LucideIcons300.trendingUp, l.reportProfit, ReportKind.profit),
        item(LucideIcons300.undo2, l.reportReturns, ReportKind.returns),
        item(LucideIcons300.landmark, l.reportPnl, ReportKind.pnl),
          ]),
        ),
        // The index lists report names only; the numbers screens stay ad-free.
        const AdSlot(AdPlacement.reportsFooter),
      ]),
    );
  }
}

/// Shared shell: title, period presets, then the report body for that period.
class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({required this.kind, super.key});

  final ReportKind kind;

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  PeriodPreset _preset = PeriodPreset.thisMonth;
  DatePeriod? _custom;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final now = ref.watch(clockProvider).now();
    final period = DatePeriod.resolve(_preset, now, custom: _custom);
    final title = switch (widget.kind) {
      ReportKind.daily => l.reportDaily,
      ReportKind.ageing => l.ageingTitle,
      ReportKind.courier => l.reportCourier,
      ReportKind.profit => l.reportProfit,
      ReportKind.returns => l.reportReturns,
      ReportKind.pnl => l.reportPnl,
    };
    String label(PeriodPreset p) => switch (p) {
          PeriodPreset.today => l.periodToday,
          PeriodPreset.yesterday => l.periodYesterday,
          PeriodPreset.last7Days => l.period7d,
          PeriodPreset.thisMonth => l.periodThisMonth,
          PeriodPreset.lastMonth => l.periodLastMonth,
          PeriodPreset.custom => l.periodCustom,
        };
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(children: [
        if (widget.kind != ReportKind.ageing)
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(8),
              children: [
                for (final p in PeriodPreset.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(label(p)),
                      selected: _preset == p,
                      onSelected: (_) async {
                        if (p == PeriodPreset.custom) {
                          final r = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(now.year - 3),
                            lastDate: DateTime(now.year + 1),
                          );
                          if (r == null) return;
                          _custom = DatePeriod(
                            DateTime(r.start.year, r.start.month, r.start.day),
                            DateTime(r.end.year, r.end.month, r.end.day)
                                .add(const Duration(days: 1)),
                          );
                        }
                        setState(() => _preset = p);
                      },
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: switch (widget.kind) {
            ReportKind.daily => _DailyReport(period: period),
            ReportKind.ageing => const _AgeingReport(),
            ReportKind.courier => _CourierReport(period: period),
            ReportKind.profit => _ProfitReport(period: period),
            ReportKind.returns => _ReturnsReport(period: period),
            ReportKind.pnl => _PnlReport(period: period),
          },
        ),
      ]),
    );
  }
}

// ----------------------------------------------------------------- shared

class _Table extends StatelessWidget {
  const _Table({required this.columns, required this.rows});

  final List<String> columns;
  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 20,
        columns: [for (final c in columns) DataColumn(label: Text(c))],
        rows: [
          for (final r in rows) DataRow(cells: [for (final c in r) DataCell(Text(c))]),
        ],
      ),
    );
  }
}

/// Bar chart of at most 8 labelled values. A toggle swaps the chart for a
/// plain label/value table (always available, e.g. for screen readers).
class _Bars extends StatefulWidget {
  const _Bars({required this.labels, required this.values});

  final List<String> labels;
  final List<double> values;

  @override
  State<_Bars> createState() => _BarsState();
}

class _BarsState extends State<_Bars> {
  bool _table = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final n = widget.values.length > 8 ? 8 : widget.values.length;
    if (n == 0) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: () => setState(() => _table = !_table),
          icon: Icon(_table ? LucideIcons300.chartColumn : LucideIcons300.table, size: 18),
          label: Text(_table ? l.viewAsChart : l.viewAsTable),
        ),
      ),
      if (_table)
        _Table(
          columns: [l.colLabel, l.colValue],
          rows: [
            for (var i = 0; i < n; i++)
              [widget.labels[i], widget.values[i].toStringAsFixed(0)],
          ],
        )
      else
        _chart(context, n),
    ]);
  }

  Widget _chart(BuildContext context, int n) {
    final labels = widget.labels;
    final values = widget.values;
    final color = Theme.of(context).colorScheme.primary;
    final neg = Theme.of(context).colorScheme.error;
    return SizedBox(
      height: 180,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
        child: BarChart(BarChartData(
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= n) return const SizedBox.shrink();
                  final t = labels[i];
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(t.length > 6 ? '${t.substring(0, 6)}…' : t,
                        style: const TextStyle(fontSize: 10)),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < n; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: values[i],
                  color: values[i] < 0 ? neg : color,
                  width: 16,
                  borderRadius: BorderRadius.zero,
                ),
              ]),
          ],
        )),
      ),
    );
  }
}

String _m(int poisha) => Money(poisha).format();

// ------------------------------------------------------------------ daily

class _DailyReport extends ConsumerWidget {
  const _DailyReport({required this.period});

  final DatePeriod period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final q = ref.watch(reportQueriesProvider);
    ref.watch(codRevisionProvider);
    return FutureBuilder<(List<DailyRow>, int)>(
      future: (() async => (await q.daily(period), await q.payoutsReceived(period)))(),
      builder: (_, snap) {
        final data = snap.data;
        if (data == null) return const Center(child: CircularProgressIndicator());
        final rows = data.$1;
        final total = rows.fold(0, (s, r) => s + r.created);
        if (rows.isEmpty || total == 0 && data.$2 == 0) {
          return EmptyState(icon: LucideIcons300.chartLine, title: l.noData);
        }
        return ListView(padding: const EdgeInsets.all(12), children: [
          ListTile(
            title: Text(l.payoutsReceivedLabel),
            trailing: Text(_m(data.$2), style: Theme.of(context).textTheme.titleMedium),
          ),
          _Bars(
            labels: [for (final r in rows) '${r.day.day}/${r.day.month}'],
            values: [for (final r in rows) r.created.toDouble()],
          ),
          _Table(
            columns: [
              l.reportDaily,
              l.colCreated,
              l.colDispatched,
              l.colDelivered,
              l.colFailed,
              l.colCollected,
            ],
            rows: [
              for (final r in rows)
                [
                  formatDate(r.day),
                  '${r.created}',
                  '${r.dispatched}',
                  '${r.delivered}',
                  '${r.failed}',
                  _m(r.codCollected),
                ],
            ],
          ),
        ]);
      },
    );
  }
}

// ----------------------------------------------------------------- ageing

class _AgeingReport extends ConsumerWidget {
  const _AgeingReport();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    ref.watch(codRevisionProvider);
    return FutureBuilder<List<AgeingRow>>(
      future: ref.read(codQueriesProvider).ageing(),
      builder: (_, snap) {
        final rows = snap.data;
        if (rows == null) return const Center(child: CircularProgressIndicator());
        String bucket(AgeBucket b) => switch (b) {
              AgeBucket.d0to3 => l.bucket0to3,
              AgeBucket.d4to7 => l.bucket4to7,
              AgeBucket.d8to14 => l.bucket8to14,
              AgeBucket.d15plus => l.bucket15plus,
            };
        return ListView(padding: const EdgeInsets.all(12), children: [
          _Bars(
            labels: [for (final r in rows) bucket(r.bucket)],
            values: [for (final r in rows) r.total.poisha / 100],
          ),
          _Table(
            columns: [l.ageingTitle, l.colOrders, l.outstandingLabel],
            rows: [
              for (final r in rows) [bucket(r.bucket), '${r.count}', r.total.format()],
            ],
          ),
          TextButton(
            onPressed: () => context.push('/cod/ageing'),
            child: Text(l.ageingTitle),
          ),
        ]);
      },
    );
  }
}

// ---------------------------------------------------------------- courier

class _CourierReport extends ConsumerWidget {
  const _CourierReport({required this.period});

  final DatePeriod period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    ref.watch(codRevisionProvider);
    return FutureBuilder<List<CourierPerformance>>(
      future: ref.read(reportQueriesProvider).courierPerformance(period),
      builder: (_, snap) {
        final rows = snap.data;
        if (rows == null) return const Center(child: CircularProgressIndicator());
        if (rows.every((r) => r.parcels == 0)) {
          return EmptyState(icon: LucideIcons300.chartLine, title: l.noData);
        }
        String days(double? v) => v == null ? '—' : v.toStringAsFixed(1);
        return ListView(padding: const EdgeInsets.all(12), children: [
          _Bars(
            labels: [for (final r in rows) r.name],
            values: [for (final r in rows) (r.deliveredPct ?? 0) * 100],
          ),
          _Table(
            columns: [
              l.courier,
              l.colOrders,
              l.colDelivered,
              l.colReturned,
              l.colAvgDays,
              l.colPayoutLag,
              l.colFees,
              l.colShortfall,
            ],
            rows: [
              for (final r in rows)
                [
                  r.name,
                  '${r.parcels}',
                  formatRate(r.deliveredPct),
                  formatRate(r.returnPct),
                  days(r.avgDeliveryDays),
                  days(r.avgPayoutLagDays),
                  _m(r.totalFees),
                  _m(r.shortfalls),
                ],
            ],
          ),
        ]);
      },
    );
  }
}

// ----------------------------------------------------------------- profit

class _ProfitReport extends ConsumerStatefulWidget {
  const _ProfitReport({required this.period});

  final DatePeriod period;

  @override
  ConsumerState<_ProfitReport> createState() => _ProfitReportState();
}

class _ProfitReportState extends ConsumerState<_ProfitReport> {
  ReportGroup _by = ReportGroup.day;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final q = ref.watch(reportQueriesProvider);
    final repo = ref.watch(orderRepositoryProvider);
    final filter = OrderFilter(from: widget.period.from, to: widget.period.to);
    final counted = filter.copyWith(
      profitStates: {ProfitState.provisional, ProfitState.finalised},
    );
    String groupLabel(ReportGroup g) => switch (g) {
          ReportGroup.day => l.groupDay,
          ReportGroup.courier => l.groupCourier,
          ReportGroup.channel => l.groupChannel,
          ReportGroup.customer => l.groupCustomer,
          ReportGroup.product => l.groupProduct,
          ReportGroup.area => l.groupArea,
        };
    return FutureBuilder<(List<GroupRow>, List<OrderListItem>, List<OrderListItem>, FilterTotals)>(
      future: (() async => (
            await q.grouped(filter, _by),
            await repo.fetchPage(filter: counted, sort: OrderSort.profitHigh, limit: 5),
            await repo.fetchPage(filter: counted, sort: OrderSort.profitLow, limit: 5),
            await repo.totals(filter),
          ))(),
      builder: (_, snap) {
        final d = snap.data;
        return ListView(padding: const EdgeInsets.all(12), children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final g in ReportGroup.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(groupLabel(g)),
                    selected: _by == g,
                    onSelected: (_) => setState(() => _by = g),
                  ),
                ),
            ]),
          ),
          if (d == null)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (d.$1.isEmpty)
            EmptyState(icon: LucideIcons300.chartLine, title: l.noData)
          else ...[
            const SizedBox(height: 8),
            if (d.$4.incompleteCount > 0)
              Text(l.incompleteExcluded(d.$4.incompleteCount),
                  style: Theme.of(context).textTheme.bodySmall),
            _Bars(
              labels: [for (final r in d.$1) r.label],
              values: [for (final r in d.$1) r.profit / 100],
            ),
            _Table(
              columns: _by == ReportGroup.product
                  ? [l.colName, l.colUnits, l.colRevenue, l.colProfit, l.colReturned]
                  : [l.colName, l.colOrders, l.colRevenue, l.colProfit, l.colMargin],
              rows: [
                for (final r in d.$1)
                  _by == ReportGroup.product
                      ? [r.label, '${r.units}', _m(r.revenue), _m(r.profit), '${r.returnedUnits}']
                      : [
                          r.label.isEmpty ? '—' : r.label,
                          '${r.orders}',
                          _m(r.revenue),
                          _m(r.profit),
                          formatBp(r.marginBp),
                        ],
              ],
            ),
            const SizedBox(height: 16),
            Text(l.bestOrders, style: Theme.of(context).textTheme.titleSmall),
            for (final o in d.$2) _orderTile(context, o),
            const SizedBox(height: 8),
            Text(l.worstOrders, style: Theme.of(context).textTheme.titleSmall),
            for (final o in d.$3) _orderTile(context, o),
          ],
        ]);
      },
    );
  }

  Widget _orderTile(BuildContext context, OrderListItem o) => ListTile(
        dense: true,
        title: Text('${o.order.orderNo} · ${o.customerName ?? '—'}'),
        trailing: Text(_m(o.order.profit ?? 0)),
        onTap: () => context.push('/orders/${o.order.id}'),
      );
}

// ---------------------------------------------------------------- returns

class _ReturnsReport extends ConsumerStatefulWidget {
  const _ReturnsReport({required this.period});

  final DatePeriod period;

  @override
  ConsumerState<_ReturnsReport> createState() => _ReturnsReportState();
}

class _ReturnsReportState extends ConsumerState<_ReturnsReport> {
  int _dim = 0;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final q = ref.watch(reportQueriesProvider);
    final future = switch (_dim) {
      0 => q.returnsByReason(widget.period),
      1 => q.returnsByProduct(widget.period),
      _ => q.returnsByCourier(widget.period),
    };
    return ListView(padding: const EdgeInsets.all(12), children: [
      SegmentedButton<int>(
        segments: [
          ButtonSegment(value: 0, label: Text(l.byReason)),
          ButtonSegment(value: 1, label: Text(l.groupProduct)),
          ButtonSegment(value: 2, label: Text(l.groupCourier)),
        ],
        selected: {_dim},
        onSelectionChanged: (s) => setState(() => _dim = s.first),
      ),
      FutureBuilder<List<ReasonRow>>(
        future: future,
        builder: (_, snap) {
          final rows = snap.data;
          if (rows == null) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (rows.isEmpty) return EmptyState(icon: LucideIcons300.chartLine, title: l.noData);
          final total = rows.fold(0, (s, r) => s + r.loss);
          return Column(children: [
            ListTile(
              title: Text(l.lossTotal),
              trailing: Text(_m(total), style: Theme.of(context).textTheme.titleMedium),
            ),
            _Bars(
              labels: [for (final r in rows) _label(l, r.reason)],
              values: [for (final r in rows) r.count.toDouble()],
            ),
            _Table(
              columns: [l.colName, l.colOrders, l.lossAmountLabel],
              rows: [
                for (final r in rows) [_label(l, r.reason), '${r.count}', _m(r.loss)],
              ],
            ),
          ]);
        },
      ),
    ]);
  }

  String _label(AppLocalizations l, String raw) =>
      _dim == 0 ? reasonLabel(l, raw) : (raw.isEmpty ? '—' : raw);
}

// -------------------------------------------------------------------- P&L

class _PnlReport extends ConsumerWidget {
  const _PnlReport({required this.period});

  final DatePeriod period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final t = Theme.of(context);
    ref.watch(codRevisionProvider);
    return FutureBuilder<BusinessPnl>(
      future: ref.read(pnlQueriesProvider).compute(period),
      builder: (_, snap) {
        final p = snap.data;
        if (p == null) return const Center(child: CircularProgressIndicator());
        Widget row(String k, Money v, {bool bold = false, bool minus = false, Color? color}) =>
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                Expanded(child: Text(minus ? '− $k' : k, style: bold ? t.textTheme.titleSmall : null)),
                Text(v.format(),
                    style: (bold ? t.textTheme.titleMedium : null)?.copyWith(color: color)),
              ]),
            );
        final profit = p.businessProfit;
        return ListView(padding: const EdgeInsets.all(16), children: [
          if (p.incompleteCount > 0)
            Text(l.incompleteExcluded(p.incompleteCount), style: t.textTheme.bodySmall),
          row(l.pnlRevenue, p.revenue, bold: true),
          const Divider(),
          row(l.pnlCogs, p.cogs, minus: true),
          row(l.pnlCourierFees, p.courierFees, minus: true),
          row(l.pnlReturnLoss, p.returnLoss, minus: true),
          row(l.pnlPackaging, p.packaging, minus: true),
          row(l.pnlAds, p.ads, minus: true),
          if (!p.otherOrderCosts.isZero) row(l.pnlOtherCosts, p.otherOrderCosts, minus: true),
          const Divider(),
          row(l.pnlOrderProfit, p.orderProfit, bold: true),
          const SizedBox(height: 12),
          Text(l.pnlExpenses, style: t.textTheme.titleSmall),
          for (final e in p.expensesByCategory.entries)
            row(categoryLabel(l, e.key), e.value, minus: true),
          row(l.expenseTotal, p.unallocatedExpenses, minus: true),
          const Divider(),
          row(l.pnlBusinessProfit, profit,
              bold: true, color: profit.isNegative ? t.colorScheme.error : null),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => context.push('/expenses'),
            icon: const Icon(LucideIcons300.banknote),
            label: Text(l.openExpenses),
          ),
        ]);
      },
    );
  }
}
