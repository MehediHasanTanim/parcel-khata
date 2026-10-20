import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:parcel_khata/features/cod/application/cod_queries.dart';
import 'package:parcel_khata/l10n/l10n.dart';
import 'package:parcel_khata/shared/blueprint.dart';
import 'package:parcel_khata/shared/empty_state.dart';
import 'package:parcel_khata/shared/status_chip.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

class CodScreen extends ConsumerWidget {
  const CodScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final summary = ref.watch(codSummaryProvider);
    final couriers = ref.watch(courierPendingProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.codTitle),
        actions: [
          IconButton(
            tooltip: l.ageingTitle,
            icon: const Icon(LucideIcons300.hourglass),
            onPressed: () => context.push('/cod/ageing'),
          ),
          IconButton(
            tooltip: l.payoutsHistory,
            icon: const Icon(LucideIcons300.receipt),
            onPressed: () => context.push('/cod/payouts'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/cod/payout/new'),
        icon: const Icon(LucideIcons300.creditCard),
        label: Text(l.recordPayout),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        summary.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('$e'),
          data: (s) => GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              mainAxisExtent: 92 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 2),
            ),
            children: [
              _Tile(l.pendingWithCourier, s.pending.format(), LucideIcons300.wallet,
                  () => context.push('/cod/ageing')),
              _Tile(l.inTransitCod, s.inTransit.format(), LucideIcons300.truck,
                  () => context.go('/orders')),
              _Tile(l.codDisputed, s.disputed.format(), LucideIcons300.flag,
                  () => context.push('/cod/disputed')),
              _Tile(l.settledThisMonth, s.settledThisMonth.format(), LucideIcons300.piggyBank,
                  () => context.push('/cod/payouts')),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(l.codWhoOwesYou, style: Theme.of(context).textTheme.titleMedium),
        ),
        couriers.when(
          loading: () => const SizedBox.shrink(),
          error: (e, _) => Text('$e'),
          data: (rows) => rows.isEmpty
              ? EmptyState(icon: LucideIcons300.banknote, title: l.noPayableOrders)
              : Column(children: [
                  for (final r in rows)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(r.courier.name,
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Wrap(spacing: 8, runSpacing: 4, children: [
                          Text(l.ordersCountN(r.orderCount)),
                          Text(l.oldestDays(r.oldestAgeDays)),
                          if (r.overdueCount > 0)
                            StatusChip(
                              label: '${l.overdueLabel}: ${r.overdueCount}',
                              icon: LucideIcons300.clock,
                              tone: StatusTone.danger,
                            ),
                        ]),
                        trailing: Text(r.total.format(),
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 19)),
                        onTap: () => context.push('/cod/payout/new?courier=${r.courier.id}'),
                      ),
                    ),
                ]),
        ),
        const SizedBox(height: 80),
      ]),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.label, this.value, this.icon, this.onTap);

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Blueprint(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, size: 18),
              const SizedBox(width: 6),
              Expanded(child: Text(label, style: t.textTheme.labelMedium, maxLines: 2)),
            ]),
            const Spacer(),
            Text(value, style: t.textTheme.headlineSmall?.copyWith(fontSize: 26)),
          ]),
        ),
      ),
    );
  }
}
