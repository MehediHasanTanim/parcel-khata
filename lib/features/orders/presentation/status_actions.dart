import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:parcel_khata/core/db/app_database.dart';
import 'package:parcel_khata/core/result/result.dart';
import 'package:parcel_khata/core/time/providers.dart';
import 'package:parcel_khata/features/couriers/application/courier_repository.dart';
import 'package:parcel_khata/features/orders/application/order_repository.dart';
import 'package:parcel_khata/features/orders/application/order_status_service.dart';
import 'package:parcel_khata/features/orders/domain/order_enums.dart';
import 'package:parcel_khata/features/orders/domain/order_status_machine.dart';
import 'package:parcel_khata/features/orders/presentation/order_labels.dart';
import 'package:parcel_khata/features/settings/application/settings_repository.dart';
import 'package:parcel_khata/l10n/l10n.dart';

String transitionErrorText(AppLocalizations l, TransitionError e) => switch (e) {
      TransitionError.notAllowed => l.errNotAllowed,
      TransitionError.courierRequired => l.errCourierRequired,
      TransitionError.cnRequired => l.errCnRequired,
      TransitionError.reasonRequired => l.errReasonRequired,
      TransitionError.futureDate => l.errFutureDate,
      TransitionError.beforeInitiated => l.errBeforeInitiated,
    };

String actionLabel(AppLocalizations l, OrderStatus to) => switch (to) {
      OrderStatus.packed => l.actionPacked,
      OrderStatus.handedToCourier => l.actionHanded,
      OrderStatus.inTransit => l.actionInTransit,
      OrderStatus.delivered => l.actionDelivered,
      OrderStatus.deliveryFailed => l.actionFailed,
      OrderStatus.returnInTransit => l.actionReturnTransit,
      OrderStatus.returned => l.actionReturned,
      OrderStatus.cancelled => l.actionCancel,
      _ => statusLabel(l, to),
    };

String reasonLabel(AppLocalizations l, String key) => switch (key) {
      'customer_refused' => l.reasonCustomerRefused,
      'not_reachable' => l.reasonNotReachable,
      'wrong_address' => l.reasonWrongAddress,
      'customer_cancelled' => l.reasonCustomerCancelled,
      'out_of_stock' => l.reasonOutOfStock,
      'courier_issue' => l.reasonCourierIssue,
      kCorrectionReason => l.reasonCorrection,
      _ => l.reasonOther,
    };

List<String> reasonsFor(OrderStatus to) =>
    to == OrderStatus.cancelled ? kCancelReasons : kFailedReasons;

IconData actionIcon(OrderStatus to) => statusIcon(to);

class StatusParams {
  const StatusParams({required this.at, this.reason, this.note});
  final DateTime at;
  final String? reason;
  final String? note;
}

Future<StatusParams?> showStatusParamsSheet(
  BuildContext context, {
  required OrderStatus to,
  required DateTime now,
}) {
  return showModalBottomSheet<StatusParams>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _StatusParamsSheet(to: to, now: now),
  );
}

class _StatusParamsSheet extends StatefulWidget {
  const _StatusParamsSheet({required this.to, required this.now});

  final OrderStatus to;
  final DateTime now;

  @override
  State<_StatusParamsSheet> createState() => _StatusParamsSheetState();
}

class _StatusParamsSheetState extends State<_StatusParamsSheet> {
  late DateTime _at = widget.now;
  String? _reason;
  final _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    // One-tap default: the most common reason is preselected (F5 AC3).
    if (OrderStatusMachine.requiresReason(widget.to)) {
      _reason = reasonsFor(widget.to).first;
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _at,
      firstDate: widget.now.subtract(const Duration(days: 365)),
      lastDate: widget.now,
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_at));
    if (!mounted) return;
    var picked = DateTime(d.year, d.month, d.day, t?.hour ?? _at.hour, t?.minute ?? _at.minute);
    if (picked.isAfter(widget.now)) picked = widget.now;
    setState(() => _at = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(actionLabel(l, widget.to), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule),
              title: Text(l.whenLabel),
              subtitle: Text(formatDateTime(_at)),
              trailing: TextButton(onPressed: _pickDate, child: Text(l.change)),
            ),
            if (OrderStatusMachine.requiresReason(widget.to)) ...[
              Text(l.reasonLabel, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final r in reasonsFor(widget.to))
                  ChoiceChip(
                    label: Text(reasonLabel(l, r)),
                    selected: _reason == r,
                    onSelected: (_) => setState(() => _reason = r),
                  ),
              ]),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _note,
              decoration: InputDecoration(labelText: l.noteOptional),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(
                  context,
                  StatusParams(
                    at: _at,
                    reason: _reason,
                    note: _note.text.trim().isEmpty ? null : _note.text.trim(),
                  ),
                ),
                child: Text(l.confirm),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Courier + CN (+ zone/weight) sheet. Saves via assignCourier and, when
/// [markHanded] is true, immediately moves the order to Handed to Courier.
Future<bool> showCourierSheet(
  BuildContext context,
  WidgetRef ref, {
  required Order order,
  bool markHanded = false,
}) async {
  final done = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _CourierSheet(order: order, markHanded: markHanded),
  );
  return done ?? false;
}

class _CourierSheet extends ConsumerStatefulWidget {
  const _CourierSheet({required this.order, required this.markHanded});

  final Order order;
  final bool markHanded;

  @override
  ConsumerState<_CourierSheet> createState() => _CourierSheetState();
}

class _CourierSheetState extends ConsumerState<_CourierSheet> {
  String? _courierId;
  String _zone = 'inside_dhaka';
  late bool _handed = widget.markHanded;
  final _cn = TextEditingController();
  final _weight = TextEditingController();
  String? _error;
  String? _conflictId;
  bool _patternWarn = false;

  @override
  void initState() {
    super.initState();
    final o = widget.order;
    _courierId = o.courierId;
    _zone = o.zone ?? 'inside_dhaka';
    _cn.text = o.consignmentNo ?? '';
    _weight.text = o.weightG?.toString() ?? '';
    if (_courierId == null) {
      unawaited(ref.read(settingsRepositoryProvider).read().then((s) {
        if (mounted && _courierId == null) setState(() => _courierId = s.defaultCourierId);
      }));
    }
  }

  @override
  void dispose() {
    _cn.dispose();
    _weight.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = context.l10n;
    if (_courierId == null) {
      setState(() => _error = l.errCourierRequired);
      return;
    }
    if (_handed && _cn.text.trim().isEmpty) {
      setState(() => _error = l.errCnRequired);
      return;
    }
    final repo = ref.read(orderRepositoryProvider);
    final r = await repo.assignCourier(
      widget.order.id,
      courierId: _courierId!,
      consignmentNo: _cn.text,
      zone: _zone,
      weightG: int.tryParse(_weight.text.trim()),
    );
    if (!mounted) return;
    final failure = r.failureOrNull;
    if (failure != null) {
      setState(() {
        _error = failure is ConflictFailure ? l.errCnTaken : failure.message;
        _conflictId = failure is ConflictFailure ? failure.conflictingId : null;
      });
      return;
    }
    _patternWarn = r.valueOrNull!.warnings.isNotEmpty;
    if (_handed) {
      final sr = await ref
          .read(orderStatusServiceProvider)
          .changeStatus(widget.order.id, to: OrderStatus.handedToCourier);
      if (!mounted) return;
      final f = sr.failureOrNull;
      if (f != null) {
        setState(() => _error = f is TransitionFailure
            ? transitionErrorText(l, f.error)
            : f.message);
        return;
      }
    }
    if (_patternWarn && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.cnPatternWarn)));
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final couriers = ref.watch(couriersProvider).value ?? const <Courier>[];
    final canHand = OrderStatus.fromDb(widget.order.status) == OrderStatus.confirmed ||
        OrderStatus.fromDb(widget.order.status) == OrderStatus.packed;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.assignCourier, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: couriers.any((c) => c.id == _courierId) ? _courierId : null,
              decoration: InputDecoration(labelText: l.courier),
              items: [
                for (final c in couriers) DropdownMenuItem(value: c.id, child: Text(c.name)),
              ],
              onChanged: (v) => setState(() => _courierId = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _cn,
              decoration: InputDecoration(
                labelText: l.consignmentNo,
                suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    tooltip: l.paste,
                    icon: const Icon(Icons.content_paste),
                    onPressed: () async {
                      final d = await Clipboard.getData(Clipboard.kTextPlain);
                      if (d?.text != null) _cn.text = d!.text!.trim();
                    },
                  ),
                  IconButton(
                    tooltip: l.remove,
                    icon: const Icon(Icons.clear),
                    onPressed: _cn.clear,
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _zone,
                  decoration: InputDecoration(labelText: l.zone),
                  items: [
                    for (final z in kZones)
                      DropdownMenuItem(value: z, child: Text(zoneLabel(l, z))),
                  ],
                  onChanged: (v) => setState(() => _zone = v ?? _zone),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _weight,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: l.weightGrams),
                ),
              ),
            ]),
            if (canHand)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.markHandedOver),
                value: _handed,
                onChanged: (v) => setState(() => _handed = v),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(children: [
                  Expanded(
                    child: Text(_error!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
                  if (_conflictId != null)
                    TextButton(
                      onPressed: () => context.push('/orders/$_conflictId'),
                      child: Text(l.viewConflictingOrder),
                    ),
                ]),
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

/// Runs one status action the way the UI offers it: asks for missing courier
/// or CN first, asks for reason/date only when the move needs one, then
/// applies. Returns true when the order changed.
Future<bool> runStatusAction(
  BuildContext context,
  WidgetRef ref, {
  required Order order,
  required OrderStatus to,
  bool askDetails = false,
}) async {
  final l = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final service = ref.read(orderStatusServiceProvider);

  if (to == OrderStatus.handedToCourier &&
      (order.courierId == null || (order.consignmentNo ?? '').isEmpty)) {
    return showCourierSheet(context, ref, order: order, markHanded: true);
  }
  StatusParams? params;
  if (askDetails || OrderStatusMachine.requiresReason(to) || to == OrderStatus.returned) {
    final now = ref.read(clockProvider).now();
    params = await showStatusParamsSheet(context, to: to, now: now);
    if (params == null) return false;
  }
  final r = await service.changeStatus(
    order.id,
    to: to,
    at: params?.at,
    reason: params?.reason,
    note: params?.note,
  );
  final f = r.failureOrNull;
  if (f != null) {
    messenger.showSnackBar(SnackBar(
        content: Text(f is TransitionFailure ? transitionErrorText(l, f.error) : f.message)));
    return false;
  }
  return true;
}
