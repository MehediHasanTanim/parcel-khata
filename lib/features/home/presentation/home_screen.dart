import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:parcel_khata/core/time/providers.dart';
import 'package:parcel_khata/features/orders/domain/order_filter.dart';
import 'package:parcel_khata/features/reports/application/dashboard_service.dart';
import 'package:parcel_khata/features/reports/domain/report_math.dart';
import 'package:parcel_khata/features/reports/presentation/format.dart';
import 'package:parcel_khata/features/search/application/saved_view_repository.dart';
import 'package:parcel_khata/features/search/presentation/saved_views_sheet.dart';
import 'package:parcel_khata/l10n/l10n.dart';

/// Opens a filtered order list whose header total equals the tapped tile.
void openDrillDown(
  BuildContext context, {
  required String title,
  required OrderFilter filter,
  Measure? measure,
  bool stuck = false,
}) {
  final q = <String, String>{
    'title': title,
    'filter': filter.encode(),
    if (measure != null) 'measure': measure.name,
    if (stuck) 'stuck': '1',
  };
  context.push(Uri(path: '/drill', queryParameters: q).toString());
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final preset = ref.watch(periodPresetProvider);
    final dash = ref.watch(dashboardProvider);
    final views = ref.watch(savedViewsProvider).value ?? const <SavedViewItem>[];

    String presetLabel(PeriodPreset p) => switch (p) {
          PeriodPreset.today => l.periodToday,
          PeriodPreset.yesterday => l.periodYesterday,
          PeriodPreset.last7Days => l.period7d,
          PeriodPreset.thisMonth => l.periodThisMonth,
          PeriodPreset.lastMonth => l.periodLastMonth,
          PeriodPreset.custom => l.periodCustom,
        };

    return Scaffold(
      appBar: AppBar(title: Text(l.homeTitle)),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(dashboardProvider),
        child: ListView(padding: const EdgeInsets.all(16), children: [
          SizedBox(
            height: 44,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              for (final p in PeriodPreset.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(presetLabel(p)),
                    selected: preset == p,
                    onSelected: (_) async {
                      if (p == PeriodPreset.custom) {
                        final now = ref.read(clockProvider).now();
                        final r = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(now.year - 3),
                          lastDate: DateTime(now.year + 1),
                        );
                        if (r == null) return;
                        ref.read(customPeriodProvider.notifier).set(DatePeriod(
                              DateTime(r.start.year, r.start.month, r.start.day),
                              DateTime(r.end.year, r.end.month, r.end.day)
                                  .add(const Duration(days: 1)),
                            ));
                      }
                      ref.read(periodPresetProvider.notifier).set(p);
                    },
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 12),
          if (views.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                for (final v in views)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      avatar: Icon(v.isDefault ? Icons.push_pin_outlined : Icons.bookmark_outline,
                          size: 16),
                      label: Text(viewDisplayName(l, v)),
                      onPressed: () => openDrillDown(
                        context,
                        title: viewDisplayName(l, v),
                        filter: v.filter,
                        measure: Measure.count,
                      ),
                    ),
                  ),
              ]),
            ),
          const SizedBox(height: 8),
          dash.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('$e'),
            data: (d) => _Sections(data: d),
          ),
        ]),
      ),
    );
  }
}

class _Sections extends StatelessWidget {
  const _Sections({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    Widget tile(TileId id, String label, IconData icon) {
      final t = data.tiles[id]!;
      return _TileCard(
        label: label,
        icon: icon,
        value: formatMeasure(t.measure, t.value),
        onTap: () {
          if (id == TileId.stuck) {
            openDrillDown(context, title: label, filter: t.filter, stuck: true, measure: t.measure);
          } else {
            openDrillDown(context, title: label, filter: t.filter, measure: t.measure);
          }
        },
      );
    }

    Widget section(String title, List<Widget> tiles) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
              child: Text(title, style: Theme.of(context).textTheme.titleMedium),
            ),
            GridView.count(
              crossAxisCount: 2,
              childAspectRatio: 1.7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: tiles,
            ),
          ],
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      section(l.sectionCash, [
        tile(TileId.pending, l.pendingWithCourier, Icons.account_balance_wallet_outlined),
        tile(TileId.inTransitCod, l.inTransitCod, Icons.local_shipping_outlined),
        _TileCard(
          label: l.settledThisMonth,
          icon: Icons.savings_outlined,
          value: formatMoneyOrDash(data.settled),
          onTap: () => context.push('/cod/payouts'),
        ),
        tile(TileId.disputed, l.codDisputed, Icons.flag_outlined),
      ]),
      section(l.sectionOps, [
        tile(TileId.ordersInPeriod, l.tileOrders, Icons.receipt_long_outlined),
        tile(TileId.toDispatch, l.tileToDispatch, Icons.outbox_outlined),
        tile(TileId.inTransit, l.tileInTransitOps, Icons.directions_bike_outlined),
        tile(TileId.stuck, l.tileStuck, Icons.hourglass_bottom),
        tile(TileId.returnsAwaiting, l.tileReturnsAwaiting, Icons.assignment_return_outlined),
      ]),
      section(l.sectionPerformance, [
        tile(TileId.revenue, l.tileRevenue, Icons.payments_outlined),
        tile(TileId.profitFinal, l.tileProfitFinal, Icons.verified_outlined),
        tile(TileId.profitProvisional, l.tileProfitProvisional, Icons.hourglass_empty),
        tile(TileId.margin, l.tileMargin, Icons.percent),
        tile(TileId.deliverySuccess, l.tileDeliverySuccess, Icons.done_all),
        tile(TileId.returnRate, l.tileReturnRate, Icons.undo),
        tile(TileId.avgProfit, l.tileAvgProfit, Icons.trending_up),
      ]),
      const SizedBox(height: 24),
    ]);
  }
}

class _TileCard extends StatelessWidget {
  const _TileCard({
    required this.label,
    required this.icon,
    required this.value,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, size: 18),
              const SizedBox(width: 6),
              Expanded(child: Text(label, style: t.textTheme.labelMedium, maxLines: 2)),
            ]),
            const Spacer(),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: t.textTheme.titleLarge),
            ),
          ]),
        ),
      ),
    );
  }
}
