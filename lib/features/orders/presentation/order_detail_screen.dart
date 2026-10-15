import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/features/orders/application/order_repository.dart';
import 'package:parcel_khata/features/orders/domain/order_enums.dart';
import 'package:parcel_khata/features/orders/presentation/order_labels.dart';
import 'package:parcel_khata/core/db/app_database.dart';
import 'package:parcel_khata/features/cod/presentation/ledger_panel.dart';
import 'package:parcel_khata/features/profit/presentation/profit_panel.dart';
import 'package:parcel_khata/features/returns/application/return_service.dart';
import 'package:parcel_khata/features/returns/presentation/return_sheets.dart';
import 'package:parcel_khata/core/time/providers.dart';
import 'package:parcel_khata/features/couriers/application/courier_repository.dart';
import 'package:parcel_khata/features/couriers/domain/tracking_url.dart';
import 'package:parcel_khata/features/orders/application/order_status_service.dart';
import 'package:parcel_khata/features/orders/domain/order_status_machine.dart';
import 'package:parcel_khata/features/orders/presentation/status_actions.dart';
import 'package:parcel_khata/features/settings/application/settings_repository.dart';
import 'package:parcel_khata/l10n/l10n.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:parcel_khata/shared/status_chip.dart';

final orderDetailProvider =
    StreamProvider.family<OrderDetail?, String>((ref, id) async* {
  final repo = ref.watch(orderRepositoryProvider);
  yield await repo.detail(id);
  await for (final _ in repo.changes) {
    yield await repo.detail(id);
  }
});

final _courierProvider = FutureProvider.family<Courier?, String>(
    (ref, id) => ref.watch(courierRepositoryProvider).getById(id));

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
                    case 'change':
                      await _changeStatusDialog(context, ref, o);
                    case 'courier':
                      await showCourierSheet(context, ref, order: o);
                    case 'correct':
                      await _correctDialog(context, ref, o);
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
                  if (status != OrderStatus.draft)
                    PopupMenuItem(value: 'change', child: Text(l.changeStatusTitle)),
                  if (status != OrderStatus.draft)
                    PopupMenuItem(value: 'courier', child: Text(l.assignCourier)),
                  if (status != OrderStatus.draft)
                    PopupMenuItem(value: 'correct', child: Text(l.correctStatus)),
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
            const SizedBox(height: 12),
            _ActionBar(order: o),
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
            if (status != OrderStatus.draft) LedgerPanel(order: o, charges: d.charges),
            if (status != OrderStatus.draft) ProfitPanel(detail: d),
            if (const {
              OrderStatus.delivered,
              OrderStatus.deliveryFailed,
              OrderStatus.returnInTransit,
              OrderStatus.returned,
            }.contains(status))
              _ReturnCard(order: o),
            if (d.charges.isNotEmpty)
              _section(context, l.charges, [
                for (final c in d.charges)
                  _kv(
                    context,
                    '${chargeLabel(l, c.type)}${c.actualAmount == null ? ' (${l.expected})' : ''}',
                    Money(c.actualAmount ?? c.expectedAmount).format(),
                  ),
              ]),
            if (status != OrderStatus.draft)
              _CourierCard(order: o, lastEventAt: d.events.isEmpty ? null : d.events.last.at),
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
          (e.fromStatus == null
                  ? statusLabel(l, OrderStatus.fromDb(e.toStatus))
                  : '${statusLabel(l, OrderStatus.fromDb(e.fromStatus!))} → '
                      '${statusLabel(l, OrderStatus.fromDb(e.toStatus))}') +
              (e.reason == null ? '' : ' · ${reasonLabel(l, e.reason!)}') +
              (e.note == null ? '' : ' — ${e.note}'),
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

Future<void> _changeStatusDialog(BuildContext context, WidgetRef ref, Order o) async {
  final l = context.l10n;
  final settings = await ref.read(settingsRepositoryProvider).read();
  final machine = OrderStatusMachine(
    packedEnabled: settings.packedStepEnabled,
    inTransitEnabled: settings.inTransitStepEnabled,
  );
  if (!context.mounted) return;
  final next = machine.allowedNext(OrderStatus.fromDb(o.status));
  final to = await showModalBottomSheet<OrderStatus>(
    context: context,
    builder: (_) => SafeArea(
      child: ListView(shrinkWrap: true, children: [
        for (final s in next)
          ListTile(
            leading: Icon(actionIcon(s)),
            title: Text(actionLabel(l, s)),
            onTap: () => Navigator.pop(context, s),
          ),
      ]),
    ),
  );
  if (to == null || !context.mounted) return;
  await runStatusAction(context, ref, order: o, to: to, askDetails: true);
}

Future<void> _correctDialog(BuildContext context, WidgetRef ref, Order o) async {
  final l = context.l10n;
  final note = TextEditingController();
  var target = OrderStatus.fromDb(o.status);
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setState) => AlertDialog(
        title: Text(l.correctStatus),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<OrderStatus>(
            initialValue: target,
            items: [
              for (final s in OrderStatus.values.where((s) => s != OrderStatus.draft))
                DropdownMenuItem(value: s, child: Text(statusLabel(l, s))),
            ],
            onChanged: (v) => setState(() => target = v ?? target),
          ),
          const SizedBox(height: 12),
          TextField(controller: note, decoration: InputDecoration(labelText: l.correctionNote)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l.confirm)),
        ],
      ),
    ),
  );
  if (ok != true || !context.mounted) return;
  final r = await ref
      .read(orderStatusServiceProvider)
      .correctStatus(o.id, to: target, note: note.text);
  if (!context.mounted) return;
  final f = r.failureOrNull;
  if (f != null) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(f is TransitionFailure ? transitionErrorText(l, f.error) : f.message)));
  }
}

class _ActionBar extends ConsumerWidget {
  const _ActionBar({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(shopSettingsProvider).value;
    final machine = OrderStatusMachine(
      packedEnabled: s?.packedStepEnabled ?? true,
      inTransitEnabled: s?.inTransitStepEnabled ?? true,
    );
    final next = machine.allowedNext(OrderStatus.fromDb(order.status));
    if (next.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (var i = 0; i < next.length; i++)
        i == 0
            ? FilledButton.icon(
                onPressed: () => runStatusAction(context, ref, order: order, to: next[i]),
                icon: Icon(actionIcon(next[i])),
                label: Text(actionLabel(l, next[i])),
              )
            : OutlinedButton.icon(
                onPressed: () => runStatusAction(context, ref, order: order, to: next[i]),
                icon: Icon(actionIcon(next[i])),
                label: Text(actionLabel(l, next[i])),
              ),
    ]);
  }
}

class _CourierCard extends ConsumerWidget {
  const _CourierCard({required this.order, required this.lastEventAt});

  final Order order;
  final DateTime? lastEventAt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final courier =
        order.courierId == null ? null : ref.watch(_courierProvider(order.courierId!)).value;
    final cn = order.consignmentNo;
    final url = (courier?.trackingUrlTemplate == null || cn == null)
        ? null
        : TrackingUrl.build(courier!.trackingUrlTemplate!, cn);
    final now = ref.watch(clockProvider).now();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.courier, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(courier?.name ?? l.noCourier),
          if (cn != null) Text('${l.consignmentNo}: $cn'),
          if (lastEventAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${l.lastUpdatedByYou}: ${l.daysAgo(now.difference(lastEventAt!).inDays)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            OutlinedButton.icon(
              onPressed: () => showCourierSheet(context, ref, order: order),
              icon: const Icon(Icons.local_shipping_outlined),
              label: Text(l.assignCourier),
            ),
            if (courier != null && cn != null)
              OutlinedButton.icon(
                onPressed: url == null
                    ? () => ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(l.trackUnavailable)))
                    : () => launchUrl(url, mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.open_in_new),
                label: Text(l.trackParcel),
              ),
          ]),
        ]),
      ),
    );
  }
}

class _ReturnCard extends ConsumerWidget {
  const _ReturnCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final status = OrderStatus.fromDb(order.status);
    return FutureBuilder<ReturnView?>(
      future: ref.read(returnServiceProvider).forOrder(order.id),
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) return const SizedBox.shrink();
        final v = snap.data;
        final received = v?.record.receivedBackAt != null;
        final canStartFull = v == null &&
            (status == OrderStatus.deliveryFailed || status == OrderStatus.returnInTransit);
        final canPartial = v == null && status == OrderStatus.delivered;
        final canReceive = !received &&
            (v != null ||
                status == OrderStatus.deliveryFailed ||
                status == OrderStatus.returnInTransit);
        if (!canStartFull && !canPartial && !canReceive && v == null) {
          return const SizedBox.shrink();
        }
        return Card(
          margin: const EdgeInsets.only(bottom: 20),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.returnCard, style: Theme.of(context).textTheme.titleMedium),
              if (v != null) ...[
                const SizedBox(height: 4),
                Text('${v.record.type == 'full' ? l.fullReturn : l.partialReturn} · '
                    '${reasonLabel(l, v.record.reason)}'),
                if (received)
                  Text('${l.receivedBackOn}: ${formatDate(v.record.receivedBackAt!)} · '
                      '${l.lossAmountLabel}: ${Money(v.record.lossAmount).format()}'),
              ],
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                if (canStartFull)
                  OutlinedButton(
                    onPressed: () =>
                        showInitiateReturnSheet(context, ref, order: order, full: true),
                    child: Text(l.startReturn),
                  ),
                if (canPartial)
                  OutlinedButton(
                    onPressed: () =>
                        showInitiateReturnSheet(context, ref, order: order, full: false),
                    child: Text(l.partialReturn),
                  ),
                if (canReceive)
                  FilledButton(
                    onPressed: () => showReceiveReturnSheet(context, ref, order: order),
                    child: Text(l.actionReturned),
                  ),
              ]),
            ]),
          ),
        );
      },
    );
  }
}
