import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:parcel_khata/features/cod/application/cod_queries.dart';
import 'package:parcel_khata/l10n/l10n.dart';
import 'package:parcel_khata/shared/empty_state.dart';
import 'package:parcel_khata/shared/status_chip.dart';

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
            icon: const Icon(Icons.hourglass_empty),
            onPressed: () => context.push('/cod/ageing'),
          ),
          IconButton(
            tooltip: l.payoutsHistory,
            icon: const Icon(Icons.receipt),
            onPressed: () => context.push('/cod/payouts'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/cod/payout/new'),
        icon: const Icon(Icons.add_card),
        label: Text(l.recordPayout),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        summary.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('$e'),
          data: (s) => GridView.count(
            crossAxisCount: 2,
            childAspectRatio: 1.9,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              _Tile(l.pendingWithCourier, s.pending.format(), Icons.account_balance_wallet,
                  () => context.push('/cod/ageing')),
              _Tile(l.inTransitCod, s.inTransit.format(), Icons.local_shipping_outlined,
                  () => context.go('/orders')),
              _Tile(l.codDisputed, s.disputed.format(), Icons.flag_outlined,
                  () => context.push('/cod/disputed')),
              _Tile(l.settledThisMonth, s.settledThisMonth.format(), Icons.savings_outlined,
                  () => context.push('/cod/payouts')),
            ],
          ),
        ),
        const SizedBox(height: 20),
        couriers.when(
          loading: () => const SizedBox.shrink(),
          error: (e, _) => Text('$e'),
          data: (rows) => rows.isEmpty
              ? EmptyState(icon: Icons.payments_outlined, title: l.noPayableOrders)
              : Column(children: [
                  for (final r in rows)
                    Card(
                      child: ListTile(
                        title: Text(r.courier.name),
                        subtitle: Wrap(spacing: 8, runSpacing: 4, children: [
                          Text(l.ordersCountN(r.orderCount)),
                          Text(l.oldestDays(r.oldestAgeDays)),
                          if (r.overdueCount > 0)
                            StatusChip(
                              label: '${l.overdueLabel}: ${r.overdueCount}',
                              icon: Icons.schedule,
                              tone: StatusTone.danger,
                            ),
                        ]),
                        trailing: Text(r.total.format(),
                            style: Theme.of(context).textTheme.titleMedium),
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
    return Card(
      child: InkWell(
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
            Text(value, style: t.textTheme.titleLarge),
          ]),
        ),
      ),
    );
  }
}
