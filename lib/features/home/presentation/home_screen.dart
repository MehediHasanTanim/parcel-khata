import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:parcel_khata/app/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:parcel_khata/core/time/providers.dart';
import 'package:parcel_khata/features/orders/domain/order_filter.dart';
import 'package:parcel_khata/features/reminders/application/attention_service.dart';
import 'package:parcel_khata/features/reminders/presentation/attention_widgets.dart';
import 'package:parcel_khata/features/reports/application/dashboard_service.dart';
import 'package:parcel_khata/features/reports/domain/report_math.dart';
import 'package:parcel_khata/features/reports/presentation/format.dart';
import 'package:parcel_khata/features/search/application/saved_view_repository.dart';
import 'package:parcel_khata/features/settings/application/settings_repository.dart';
import 'package:parcel_khata/features/search/presentation/saved_views_sheet.dart';
import 'package:parcel_khata/l10n/l10n.dart';
import 'package:parcel_khata/shared/blueprint.dart';
import 'package:parcel_khata/shared/sync_pill.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

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
    final attention = ref.watch(attentionProvider).value ?? const [];

    String presetLabel(PeriodPreset p) => switch (p) {
          PeriodPreset.today => l.periodToday,
          PeriodPreset.yesterday => l.periodYesterday,
          PeriodPreset.last7Days => l.period7d,
          PeriodPreset.thisMonth => l.periodThisMonth,
          PeriodPreset.lastMonth => l.periodLastMonth,
          PeriodPreset.custom => l.periodCustom,
        };

    return Scaffold(
      appBar: AppBar(
        title: Text(l.homeTitle),
        actions: [
          const SyncPill(),
          IconButton(
            tooltip: l.attentionTitle,
            onPressed: () => context.push('/attention'),
            // One badge; its number is exactly the queue length (F11 AC1).
            icon: Badge(
              isLabelVisible: attention.isNotEmpty,
              label: Text('${attention.length}'),
              child: const Icon(LucideIcons300.bell),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(dashboardProvider),
        child: ListView(padding: const EdgeInsets.all(16), children: [
          SizedBox(
            height: 44 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 2),
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
              height: 40 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 2),
              child: ListView(scrollDirection: Axis.horizontal, children: [
                for (final v in views)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      avatar: Icon(v.isDefault ? LucideIcons300.pin : LucideIcons300.bookmark,
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
          if (attention.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: Text('${l.attentionTitle} (${attention.length})',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              TextButton(
                onPressed: () => context.push('/attention'),
                child: Text(l.viewAll),
              ),
            ]),
            for (final i in attention.take(3)) AttentionTile(item: i),
          ],
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

class _Sections extends ConsumerStatefulWidget {
  const _Sections({required this.data});

  final DashboardData data;

  @override
  ConsumerState<_Sections> createState() => _SectionsState();
}

class _SectionsState extends ConsumerState<_Sections> {
  // Tiles the seller tapped to reveal while "hide amounts" is on.
  final Set<TileId> _revealed = {};

  bool _isMoney(Measure m) => const {
        Measure.outstanding,
        Measure.codExpected,
        Measure.revenue,
        Measure.profitFinal,
        Measure.profitProvisional,
        Measure.avgProfit,
      }.contains(m);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final data = widget.data;
    final settings = ref.watch(shopSettingsProvider).value;
    final hideAmounts = settings?.hideAmountsOnDashboard ?? false;
    final hideProfit = settings?.hideProfitInLists ?? false;

    Widget tile(TileId id, String label, IconData icon, {bool warn = false}) {
      final t = data.tiles[id]!;
      final isProfit = const {
        TileId.profitFinal,
        TileId.profitProvisional,
        TileId.margin,
        TileId.avgProfit,
      }.contains(id);
      final masked = (hideAmounts && _isMoney(t.measure) && !_revealed.contains(id)) ||
          (hideProfit && isProfit);
      return _TileCard(
        label: label,
        icon: icon,
        warn: warn,
        value: masked ? '••••' : formatMeasure(t.measure, t.value),
        onTap: () {
          if (masked && !(hideProfit && isProfit)) {
            setState(() => _revealed.add(id));
            return;
          }
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
              child: Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65))),
            ),
            // Row height follows the text scale so tiles never clip at 200%.
            GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                mainAxisExtent:
                    92 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 2),
              ),
              children: tiles,
            ),
          ],
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      section(l.sectionCash, [
        tile(TileId.pending, l.pendingWithCourier, LucideIcons300.wallet),
        tile(TileId.inTransitCod, l.inTransitCod, LucideIcons300.truck),
        _TileCard(
          label: l.settledThisMonth,
          icon: LucideIcons300.piggyBank,
          value: hideAmounts && !_revealed.contains(TileId.settled)
              ? '••••'
              : formatMoneyOrDash(data.settled),
          onTap: () {
            if (hideAmounts && !_revealed.contains(TileId.settled)) {
              setState(() => _revealed.add(TileId.settled));
              return;
            }
            context.push('/cod/payouts');
          },
        ),
        tile(TileId.disputed, l.codDisputed, LucideIcons300.flag, warn: true),
      ]),
      section(l.sectionOps, [
        tile(TileId.ordersInPeriod, l.tileOrders, LucideIcons300.receiptText),
        tile(TileId.toDispatch, l.tileToDispatch, LucideIcons300.send),
        tile(TileId.inTransit, l.tileInTransitOps, LucideIcons300.bike),
        tile(TileId.stuck, l.tileStuck, LucideIcons300.hourglass, warn: true),
        tile(TileId.returnsAwaiting, l.tileReturnsAwaiting, LucideIcons300.undo2),
      ]),
      section(l.sectionPerformance, [
        tile(TileId.revenue, l.tileRevenue, LucideIcons300.banknote),
        tile(TileId.profitFinal, l.tileProfitFinal, LucideIcons300.badgeCheck),
        tile(TileId.profitProvisional, l.tileProfitProvisional, LucideIcons300.hourglass),
        tile(TileId.margin, l.tileMargin, LucideIcons300.percent),
        tile(TileId.deliverySuccess, l.tileDeliverySuccess, LucideIcons300.checkCheck),
        tile(TileId.returnRate, l.tileReturnRate, LucideIcons300.undo2),
        tile(TileId.avgProfit, l.tileAvgProfit, LucideIcons300.trendingUp),
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
    this.warn = false,
  });

  final String label;
  final IconData icon;
  final String value;
  final VoidCallback onTap;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final warnColor = t.extension<StatusColors>()!.warning;
    return Blueprint(
      borderColor: warn ? warnColor : null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, size: 16, color: warn ? warnColor : null),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label,
                    style: t.textTheme.bodySmall?.copyWith(color: warn ? warnColor : null),
                    maxLines: 2),
              ),
            ]),
            const Spacer(),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  style: t.textTheme.headlineSmall?.copyWith(
                    fontSize: 26,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  )),
            ),
          ]),
        ),
      ),
    );
  }
}
