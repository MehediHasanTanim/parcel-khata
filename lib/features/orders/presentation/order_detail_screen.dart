import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/features/orders/application/order_repository.dart';
import 'package:parcel_khata/features/orders/domain/order_enums.dart';
import 'package:parcel_khata/features/orders/presentation/order_labels.dart';
import 'package:parcel_khata/l10n/l10n.dart';
import 'package:parcel_khata/shared/status_chip.dart';

final orderDetailProvider =
    StreamProvider.family<OrderDetail?, String>((ref, id) async* {
  final repo = ref.watch(orderRepositoryProvider);
  yield await repo.detail(id);
  await for (final _ in repo.changes) {
    yield await repo.detail(id);
  }
});

class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({required this.orderId, super.key});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(orderDetailProvider(orderId));
    return async.when(
      loading: () => Scaffold(
          appBar: AppBar(), body: const Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(appBar: AppBar(), body: Center(child: Text('$e'))),
      data: (d) {
        if (d == null) return Scaffold(appBar: AppBar());
        final o = d.order;
        final status = OrderStatus.fromDb(o.status);
        final cod = CodStatus.fromDb(o.codStatus);
        final repo = ref.read(orderRepositoryProvider);
        return Scaffold(
          appBar: AppBar(
            title: Text(o.orderNo),
            actions: [
              PopupMenuButton<String>(
                onSelected: (v) async {
                  final nav = GoRouter.of(context);
                  final messenger = ScaffoldMessenger.of(context);
                  switch (v) {
                    case 'edit':
                      unawaited(nav.push('/orders/$orderId/edit'));
                    case 'dup':
                      final r = await repo.duplicate(orderId);
                      r.when(
                        ok: (n) => nav.pushReplacement('/orders/${n.id}'),
                        err: (f) => messenger.showSnackBar(SnackBar(content: Text(f.message))),
                      );
                    case 'del':
                      await repo.softDelete(orderId);
                      nav.pop();
                      messenger
                        ..hideCurrentSnackBar()
                        ..showSnackBar(SnackBar(
                          content: Text(l.orderDeleted),
                          action: SnackBarAction(
                            label: l.undo,
                            onPressed: () => unawaited(repo.restore(orderId)),
                          ),
                        ));
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: Text(l.edit)),
                  PopupMenuItem(value: 'dup', child: Text(l.duplicateOrder)),
                  PopupMenuItem(value: 'del', child: Text(l.deleteOrder)),
                ],
              ),
            ],
          ),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            Wrap(spacing: 8, runSpacing: 8, children: [
              StatusChip(
                  label: statusLabel(l, status),
                  icon: statusIcon(status),
                  tone: statusTone(status)),
              if (cod != CodStatus.notApplicable)
                StatusChip(
                    label: codLabel(l, cod),
                    icon: Icons.payments_outlined,
                    tone: codTone(cod)),
            ]),
            const SizedBox(height: 16),
            _section(context, l.customer, [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person),
                title: Text(d.customer?.name ?? '—'),
                subtitle: Text(d.customer?.phonePrimary ?? ''),
                onTap: d.customer == null
                    ? null
                    : () => context.push('/customers/${d.customer!.id}'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.place_outlined),
                title: Text(o.addressSnapshot.isEmpty ? '—' : o.addressSnapshot),
              ),
            ]),
            _section(context, l.items, [
              for (final line in d.lines)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(line.nameSnapshot),
                  subtitle: Text('${line.qty} × ${Money(line.unitSellPrice).format()}'
                      '${line.lineDiscount > 0 ? '  −${Money(line.lineDiscount).format()}' : ''}'),
                  trailing: line.unitCostPrice == null
                      ? StatusChip(
                          label: l.costMissing,
                          icon: Icons.warning_amber,
                          tone: StatusTone.warning)
                      : null,
                ),
            ]),
            _section(context, l.codAmount, [
              _kv(context, l.itemsTotal, Money(o.itemsTotal).format()),
              if (o.discountTotal > 0)
                _kv(context, l.discountLabel, '−${Money(o.discountTotal).format()}'),
              _kv(context, l.deliveryCharge, Money(o.deliveryChargeCustomer).format()),
              if (o.advanceReceived > 0)
                _kv(context, l.advanceLabel, '−${Money(o.advanceReceived).format()}'),
              const Divider(),
              _kv(context, l.codAmount, Money(o.codExpected).format(), bold: true),
              if (o.codOverridden)
                Align(
                  alignment: Alignment.centerLeft,
                  child: StatusChip(
                      label: l.codOverriddenMark,
                      icon: Icons.edit,
                      tone: StatusTone.warning),
                ),
            ]),
            if (d.charges.isNotEmpty)
              _section(context, l.charges, [
                for (final c in d.charges)
                  _kv(
                    context,
                    '${chargeLabel(l, c.type)}${c.actualAmount == null ? ' (${l.expected})' : ''}',
                    Money(c.actualAmount ?? c.expectedAmount).format(),
                  ),
              ]),
            if (o.courierId != null || o.consignmentNo != null)
              _section(context, l.courier, [
                _kv(context, l.consignmentNo, o.consignmentNo ?? '—'),
              ]),
            _section(context, l.timeline, _timeline(l, d)),
          ]),
        );
      },
    );
  }

  List<Widget> _timeline(AppLocalizations l, OrderDetail d) {
    final entries = <(DateTime, IconData, String)>[
      for (final e in d.events)
        (
          e.at,
          statusIcon(OrderStatus.fromDb(e.toStatus)),
          e.fromStatus == null
              ? statusLabel(l, OrderStatus.fromDb(e.toStatus))
              : '${statusLabel(l, OrderStatus.fromDb(e.fromStatus!))} → '
                  '${statusLabel(l, OrderStatus.fromDb(e.toStatus))}',
        ),
      for (final e in d.edits)
        (
          e.at,
          Icons.edit_outlined,
          '${e.field}: ${e.oldValue ?? '—'} → ${e.newValue ?? '—'}',
        ),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    return [
      for (final e in entries)
        ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: Icon(e.$2, size: 20),
          title: Text(e.$3),
          subtitle: Text(formatDateTime(e.$1)),
        ),
    ];
  }

  Widget _section(BuildContext context, String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...children,
      ]),
    );
  }

  Widget _kv(BuildContext context, String k, String v, {bool bold = false}) {
    final style = bold ? Theme.of(context).textTheme.titleMedium : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Flexible(child: Text(k, style: style)),
        Text(v, style: style),
      ]),
    );
  }
}
