import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:parcel_khata/core/db/app_database.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/features/cod/application/cod_queries.dart';
import 'package:parcel_khata/features/cod/application/payout_service.dart';
import 'package:parcel_khata/features/orders/presentation/order_labels.dart';
import 'package:parcel_khata/l10n/l10n.dart';
import 'package:parcel_khata/shared/empty_state.dart';
import 'package:parcel_khata/shared/status_chip.dart';

final _payoutsProvider = StreamProvider<List<Payout>>(
    (ref) => ref.watch(payoutServiceProvider).watchPayouts());

class PayoutsScreen extends ConsumerWidget {
  const PayoutsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final rows = ref.watch(_payoutsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.payoutsHistory)),
      body: rows.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) => list.isEmpty
            ? EmptyState(icon: Icons.receipt_long_outlined, title: l.noPayouts)
            : ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final p = list[i];
                  return ListTile(
                    title: Text(Money(p.totalReceived).format()),
                    subtitle: Text('${formatDate(p.paidAt)} · ${p.method}'
                        '${p.reference == null ? '' : ' · ${p.reference}'}'),
                    trailing: p.status == 'reversed'
                        ? StatusChip(
                            label: l.payoutStatusReversed,
                            icon: Icons.undo,
                            tone: StatusTone.danger)
                        : null,
                    onTap: () => context.push('/cod/payouts/${p.id}'),
                  );
                },
              ),
      ),
    );
  }
}

class PayoutDetailScreen extends ConsumerWidget {
  const PayoutDetailScreen({required this.payoutId, super.key});

  final String payoutId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    ref.watch(codRevisionProvider);
    return FutureBuilder<PayoutDetail?>(
      future: ref.read(payoutServiceProvider).detail(payoutId),
      builder: (_, snap) {
        final d = snap.data;
        if (d == null) {
          return Scaffold(
              appBar: AppBar(),
              body: const Center(child: CircularProgressIndicator()));
        }
        final p = d.payout;
        final reversed = p.status == 'reversed';
        return Scaffold(
          appBar: AppBar(title: Text(Money(p.totalReceived).format())),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            if (reversed)
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: ListTile(
                  leading: const Icon(Icons.undo),
                  title: Text(l.payoutReversed),
                  subtitle: Text(p.reversedReason ?? ''),
                ),
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${l.paidOn}: ${formatDate(p.paidAt)}'),
              subtitle: Text('${l.payMethod}: ${p.method}'
                  '${p.reference == null ? '' : '\n${l.referenceNo}: ${p.reference}'}'),
            ),
            const Divider(),
            Text(l.allocationsTitle, style: Theme.of(context).textTheme.titleMedium),
            for (final (a, o) in d.rows)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(o.orderNo),
                subtitle: Text([
                  if (a.writeOffAmount > 0) '${l.writtenOffAmount}: ${Money(a.writeOffAmount).format()}',
                  if (a.disputedSet) l.codDisputed,
                  if (a.isOverpayment) l.allowOverpayment,
                ].join(' · ')),
                trailing: Text(Money(a.amountApplied).format()),
                onTap: () => context.push('/orders/${o.id}'),
              ),
            const SizedBox(height: 16),
            if (!reversed)
              OutlinedButton.icon(
                icon: const Icon(Icons.undo),
                label: Text(l.reversePayout),
                onPressed: () async {
                  final c = TextEditingController();
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (dc) => AlertDialog(
                      title: Text(l.reversePayout),
                      content: TextField(
                          controller: c,
                          decoration: InputDecoration(labelText: l.reverseReason)),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(dc, false),
                            child: Text(l.cancel)),
                        FilledButton(
                            onPressed: () => Navigator.pop(dc, true),
                            child: Text(l.confirm)),
                      ],
                    ),
                  );
                  final reason = c.text;
                  c.dispose();
                  if (ok != true) return;
                  await ref.read(payoutServiceProvider).reversePayout(payoutId, reason);
                },
              ),
          ]),
        );
      },
    );
  }
}

class DisputedScreen extends ConsumerWidget {
  const DisputedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    ref.watch(codRevisionProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.disputedOrders)),
      body: FutureBuilder<List<OpenCodOrder>>(
        future: ref.read(codQueriesProvider).openOrders(disputedOnly: true),
        builder: (_, snap) {
          final rows = snap.data ?? const <OpenCodOrder>[];
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (rows.isEmpty) {
            return EmptyState(icon: Icons.flag_outlined, title: l.emptyDefaultTitle);
          }
          return ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final r = rows[i];
              return ListTile(
                title: Text('${r.order.orderNo} · ${r.courier?.name ?? ''}'),
                subtitle: Text(r.order.disputeNote ?? ''),
                trailing: Text(r.outstanding.format()),
                onTap: () => context.push('/orders/${r.order.id}'),
              );
            },
          );
        },
      ),
    );
  }
}
