import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:parcel_khata/core/platform/share_origin.dart';
import 'package:parcel_khata/core/db/app_database.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/features/cod/application/cod_queries.dart';
import 'package:parcel_khata/features/cod/application/payout_service.dart';
import 'package:parcel_khata/features/orders/presentation/order_labels.dart';
import 'package:parcel_khata/core/time/providers.dart';
import 'package:parcel_khata/features/couriers/application/courier_repository.dart';
import 'package:parcel_khata/features/export/application/pdf_documents.dart';
import 'package:parcel_khata/features/export/application/pdf_theme.dart';
import 'package:parcel_khata/features/settings/application/settings_repository.dart';
import 'package:printing/printing.dart';
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
      appBar: AppBar(
        title: Text(l.payoutsHistory),
        actions: [
          IconButton(
            tooltip: l.stmtImport,
            icon: const Icon(Icons.upload_file),
            onPressed: () => context.push('/cod/payout/statement'),
          ),
          IconButton(
            tooltip: l.shareStatement,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () => _statement(context, ref),
          ),
        ],
      ),
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

/// Courier dispute statement for this month: expected vs received per order.
Future<void> _statement(BuildContext context, WidgetRef ref) async {
  final l = context.l10n;
  final couriers = await ref.read(courierRepositoryProvider).watchAll().first;
  if (!context.mounted || couriers.isEmpty) return;
  final courier = await showModalBottomSheet<Courier>(
    context: context,
    builder: (_) => SafeArea(
      child: ListView(shrinkWrap: true, children: [
        for (final c in couriers)
          ListTile(title: Text(c.name), onTap: () => Navigator.pop(context, c)),
      ]),
    ),
  );
  if (courier == null) return;
  final now = ref.read(clockProvider).now();
  final from = DateTime(now.year, now.month);
  final to = DateTime(now.year, now.month + 1);
  final rows = await ref.read(payoutServiceProvider).statementRows(courier.id, from, to);
  final settings = await ref.read(settingsRepositoryProvider).read();
  final bytes = await PdfDocuments.courierStatement(
    shopName: settings.businessName.isEmpty ? l.appName : settings.businessName,
    courier: courier.name,
    period: '${formatDate(from)} - ${formatDate(to.subtract(const Duration(days: 1)))}',
    rows: [
      for (final r in rows)
        StatementRow(
          orderNo: r.order.orderNo,
          cn: r.order.consignmentNo ?? '',
          deliveredOn: r.order.deliveredAt == null ? '' : formatDate(r.order.deliveredAt!),
          expected: Money(r.expected),
          received: Money(r.received),
        ),
    ],
    theme: await loadPdfTheme(),
  );
  await Printing.sharePdf(
      bytes: bytes, filename: 'statement_${courier.name}.pdf', bounds: shareOrigin());
}
