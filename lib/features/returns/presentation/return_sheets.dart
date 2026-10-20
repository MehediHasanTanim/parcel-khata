import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parcel_khata/core/db/app_database.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/core/result/result.dart';
import 'package:parcel_khata/core/time/providers.dart';
import 'package:parcel_khata/features/orders/application/order_repository.dart';
import 'package:parcel_khata/features/orders/application/order_status_service.dart';
import 'package:parcel_khata/features/orders/presentation/order_labels.dart';
import 'package:parcel_khata/features/orders/presentation/status_actions.dart';
import 'package:parcel_khata/features/profit/domain/profit_calculator.dart';
import 'package:parcel_khata/features/returns/application/return_service.dart';
import 'package:parcel_khata/features/returns/domain/return_loss_calculator.dart';
import 'package:parcel_khata/features/settings/application/settings_repository.dart';
import 'package:parcel_khata/l10n/l10n.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

String conditionLabel(AppLocalizations l, ReturnCondition c) => switch (c) {
      ReturnCondition.resellable => l.conditionResellable,
      ReturnCondition.damaged => l.conditionDamaged,
      ReturnCondition.lost => l.conditionLost,
    };

String returnErrorText(AppLocalizations l, Failure f) {
  if (f is TransitionFailure) return transitionErrorText(l, f.error);
  if (f is ReturnFailure) {
    return switch (f.code) {
      'invalid_status' => l.errReturnStatus,
      'no_lines' => l.errReturnNoLines,
      'bad_qty' => l.errReturnBadQty,
      'use_full' => l.errReturnUseFull,
      'future_date' => l.errFutureDate,
      'before_initiated' => l.errBeforeInitiated,
      _ => f.code,
    };
  }
  if (f is ConflictFailure) return l.errReturnExists;
  return f.message;
}

/// Start a full (after failed delivery) or partial (after delivery) return.
Future<bool> showInitiateReturnSheet(
  BuildContext context,
  WidgetRef ref, {
  required Order order,
  required bool full,
}) async {
  final lines = (await ref.read(orderRepositoryProvider).detail(order.id))?.lines ?? const [];
  if (!context.mounted) return false;
  final done = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _InitiateSheet(order: order, full: full, lines: lines),
  );
  return done ?? false;
}

class _InitiateSheet extends ConsumerStatefulWidget {
  const _InitiateSheet({required this.order, required this.full, required this.lines});

  final Order order;
  final bool full;
  final List<OrderLine> lines;

  @override
  ConsumerState<_InitiateSheet> createState() => _InitiateSheetState();
}

class _InitiateSheetState extends ConsumerState<_InitiateSheet> {
  late final Map<String, int> _qty = {for (final l in widget.lines) l.id: 0};
  String _reason = kReturnReasons.first;
  String? _error;

  Future<void> _save() async {
    final l = context.l10n;
    final r = await ref.read(returnServiceProvider).initiate(
          widget.order.id,
          full: widget.full,
          reason: _reason,
          lines: [for (final e in _qty.entries) ReturnQty(e.key, e.value)],
        );
    if (!mounted) return;
    final f = r.failureOrNull;
    if (f != null) {
      setState(() => _error = returnErrorText(l, f));
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.full ? l.fullReturn : l.partialReturn,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
 icon: const Icon(LucideIcons300.chevronDown),
 isExpanded: true,
              initialValue: _reason,
              decoration: InputDecoration(labelText: l.returnReason),
              items: [
                for (final r in kReturnReasons)
                  DropdownMenuItem(value: r, child: Text(reasonLabel(l, r))),
              ],
              onChanged: (v) => setState(() => _reason = v ?? _reason),
            ),
            if (!widget.full) ...[
              const SizedBox(height: 12),
              for (final line in widget.lines)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(line.nameSnapshot),
                  subtitle: Text('${l.quantity}: ${line.qty}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton.outlined(
                      onPressed: (_qty[line.id] ?? 0) > 0
                          ? () => setState(() => _qty[line.id] = _qty[line.id]! - 1)
                          : null,
                      icon: const Icon(LucideIcons300.minus),
                    ),
                    SizedBox(
                      width: 28,
                      child: Text('${_qty[line.id]}', textAlign: TextAlign.center),
                    ),
                    IconButton.outlined(
                      onPressed: (_qty[line.id] ?? 0) < line.qty
                          ? () => setState(() => _qty[line.id] = _qty[line.id]! + 1)
                          : null,
                      icon: const Icon(LucideIcons300.plus),
                    ),
                  ]),
                ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: _save, child: Text(l.save)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Receive the goods back: date, condition per line, live loss preview.
Future<bool> showReceiveReturnSheet(
  BuildContext context,
  WidgetRef ref, {
  required Order order,
}) async {
  final detail = await ref.read(orderRepositoryProvider).detail(order.id);
  final view = await ref.read(returnServiceProvider).forOrder(order.id);
  if (!context.mounted || detail == null) return false;
  final done = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ReceiveSheet(order: order, detail: detail, view: view),
  );
  return done ?? false;
}

class _ReceiveSheet extends ConsumerStatefulWidget {
  const _ReceiveSheet({required this.order, required this.detail, required this.view});

  final Order order;
  final OrderDetail detail;
  final ReturnView? view;

  @override
  ConsumerState<_ReceiveSheet> createState() => _ReceiveSheetState();
}

class _ReceiveSheetState extends ConsumerState<_ReceiveSheet> {
  late final List<(OrderLine, int)> _items;
  late final Map<String, ReturnCondition> _cond;
  late DateTime _at;
  String? _error;

  @override
  void initState() {
    super.initState();
    final v = widget.view;
    final lines = widget.detail.lines;
    // With no record yet, the whole order is coming back.
    _items = [
      for (final line in lines)
        (
          line,
          v == null
              ? line.qty
              : v.lines.where((r) => r.orderLineId == line.id).fold(0, (s, r) => s + r.qty),
        ),
    ].where((e) => e.$2 > 0).toList();
    _cond = {for (final e in _items) e.$1.id: ReturnCondition.resellable};
    _at = ref.read(clockProvider).now();
  }

  bool get _full => widget.view == null || widget.view!.record.type == 'full';

  Money _fee(String type) => widget.detail.charges
      .where((c) => c.type == type && c.deletedAt == null)
      .fold(Money.zero, (s, c) => s + Money(c.actualAmount ?? c.expectedAmount));

  ReturnLoss get _loss => ReturnLossCalculator.compute(
        fullReturn: _full,
        lines: [
          for (final e in _items)
            ReturnedLine(
              qty: e.$2,
              unitCost: e.$1.unitCostPrice == null ? null : Money(e.$1.unitCostPrice!),
              condition: _cond[e.$1.id],
            ),
        ],
        deliveryFee: _fee('delivery_fee'),
        returnFee: _fee('return_fee'),
      );

  Future<void> _save() async {
    final l = context.l10n;
    final r = await ref.read(returnServiceProvider).receive(
          widget.order.id,
          conditions: _cond,
          receivedAt: _at,
        );
    if (!mounted) return;
    final f = r.failureOrNull;
    if (f != null) {
      setState(() => _error = returnErrorText(l, f));
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final stock = ref.watch(shopSettingsProvider).value?.stockTrackingEnabled ?? false;
    final loss = _loss;
    final resellable = _cond.values.any((c) => c == ReturnCondition.resellable);
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.actionReturned, style: Theme.of(context).textTheme.titleLarge),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons300.calendar),
              title: Text(l.receivedBackOn),
              subtitle: Text(formatDateTime(_at)),
              trailing: TextButton(
                child: Text(l.change),
                onPressed: () async {
                  final now = ref.read(clockProvider).now();
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _at,
                    firstDate: now.subtract(const Duration(days: 365)),
                    lastDate: now,
                  );
                  if (d != null) setState(() => _at = DateTime(d.year, d.month, d.day, _at.hour, _at.minute));
                },
              ),
            ),
            for (final e in _items) ...[
              Text('${e.$1.nameSnapshot} × ${e.$2}',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Wrap(spacing: 8, children: [
                for (final c in ReturnCondition.values)
                  ChoiceChip(
                    label: Text(conditionLabel(l, c)),
                    selected: _cond[e.$1.id] == c,
                    onSelected: (_) => setState(() => _cond[e.$1.id] = c),
                  ),
              ]),
              const SizedBox(height: 8),
            ],
            const Divider(),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(l.lossAmountLabel, style: Theme.of(context).textTheme.titleSmall),
              Text(loss.total.format(), style: Theme.of(context).textTheme.titleMedium),
            ]),
            if (stock && resellable)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(l.stockWillRestore, style: Theme.of(context).textTheme.bodySmall),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: _save, child: Text(l.confirm)),
            ),
          ],
        ),
      ),
    );
  }
}
