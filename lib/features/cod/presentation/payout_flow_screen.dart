import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/core/time/providers.dart';
import 'package:parcel_khata/features/cod/application/payout_service.dart';
import 'package:parcel_khata/features/cod/domain/payout_reconciler.dart';
import 'package:parcel_khata/features/couriers/application/courier_repository.dart';
import 'package:parcel_khata/features/orders/presentation/order_labels.dart';
import 'package:parcel_khata/l10n/l10n.dart';
import 'package:parcel_khata/shared/empty_state.dart';

const _methods = ['bank', 'bkash', 'nagad', 'cash', 'other'];

/// Record payout: 1) courier + total, 2) pick orders + amounts with the live
/// expected-vs-received bar, 3) shortfall handling and save.
class PayoutFlowScreen extends ConsumerStatefulWidget {
  const PayoutFlowScreen({this.courierId, super.key});

  final String? courierId;

  @override
  ConsumerState<PayoutFlowScreen> createState() => _PayoutFlowScreenState();
}

class _PayoutFlowScreenState extends ConsumerState<PayoutFlowScreen> {
  int _step = 0;
  String? _courierId;
  final _total = TextEditingController();
  final _reference = TextEditingController();
  final _note = TextEditingController();
  String _method = 'bank';
  DateTime? _paidAt;

  List<PayableOrder> _payable = [];
  final Set<String> _selected = {};
  final Map<String, TextEditingController> _amounts = {};
  ShortfallPolicy? _policy;
  bool _allowOver = false;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _courierId = widget.courierId;
  }

  @override
  void dispose() {
    _total.dispose();
    _reference.dispose();
    _note.dispose();
    for (final c in _amounts.values) {
      c.dispose();
    }
    super.dispose();
  }

  Money get _received => Money.tryParse(_total.text) ?? Money.zero;

  Money _amountOf(String id) => Money.tryParse(_amounts[id]?.text ?? '') ?? Money.zero;

  List<ReconcileOrder> get _selectedOrders =>
      [for (final p in _payable) if (_selected.contains(p.order.id)) p.reconcile];

  Future<void> _loadStep2() async {
    final l = context.l10n;
    if (_courierId == null) {
      setState(() => _error = l.errCourierRequired);
      return;
    }
    if (_received.poisha <= 0) {
      setState(() => _error = l.errTotalPositive);
      return;
    }
    final rows = await ref.read(payoutServiceProvider).payableOrders(_courierId!);
    if (!mounted) return;
    for (final c in _amounts.values) {
      c.dispose();
    }
    _amounts.clear();
    _selected
      ..clear()
      ..addAll(rows.where((r) => r.order.deliveredAt != null).map((r) => r.order.id));
    for (final r in rows) {
      _amounts[r.order.id] = TextEditingController();
    }
    setState(() {
      _payable = rows;
      _error = null;
      _step = 1;
    });
    _autoAllocate();
  }

  void _autoAllocate() {
    final lines = PayoutReconciler.autoAllocate(_selectedOrders, _received);
    final byId = {for (final x in lines) x.orderId: x.amount};
    setState(() {
      for (final p in _payable) {
        final a = byId[p.order.id];
        _amounts[p.order.id]!.text =
            a == null ? '' : a.format(symbol: false, decimals: a.poisha % 100 != 0);
      }
    });
  }

  List<AllocationLine> _lines() {
    final lines = [
      for (final o in _selectedOrders)
        if (_amountOf(o.id).poisha > 0) AllocationLine(o.id, _amountOf(o.id)),
    ];
    // Explicit overpayment: park the surplus on the last allocated order.
    final diff = _received - lines.fold(Money.zero, (s, a) => s + a.amount);
    if (_allowOver && diff.poisha > 0) {
      if (lines.isEmpty && _selectedOrders.isNotEmpty) {
        lines.add(AllocationLine(_selectedOrders.last.id, diff));
      } else if (lines.isNotEmpty) {
        final last = lines.removeLast();
        lines.add(AllocationLine(last.orderId, last.amount + diff));
      }
    }
    return lines;
  }

  String _errText(AppLocalizations l, ReconcileError e) => switch (e) {
        ReconcileError.noOrders => l.errNoOrdersSelected,
        ReconcileError.totalNotPositive => l.errTotalPositive,
        ReconcileError.allocationMismatch => l.errAllocationMismatch,
        ReconcileError.exceedsOutstanding => l.errExceedsOutstanding,
        ReconcileError.shortfallNeedsPolicy => l.errShortfallPolicy,
        _ => e.name,
      };

  bool get _hasShortfall {
    final lines = _lines();
    final applied = {for (final a in lines) a.orderId: a.amount};
    return _selectedOrders
        .any((o) => (o.outstanding - (applied[o.id] ?? Money.zero)).poisha > 0);
  }

  Future<void> _next() async {
    final l = context.l10n;
    final check = PayoutReconciler.plan(
      orders: _selectedOrders,
      allocations: _lines(),
      totalReceived: _received,
      policy: ShortfallPolicy.allocate, // only validating amounts here
      allowOverpayment: _allowOver,
    );
    if (!check.isOk) {
      setState(() => _error = _errText(l, check.error!));
      return;
    }
    if (_hasShortfall) {
      setState(() {
        _error = null;
        _step = 2;
      });
    } else {
      await _save();
    }
  }

  Future<void> _save() async {
    final l = context.l10n;
    if (_saving) return;
    if (_hasShortfall && _policy == null) {
      setState(() => _error = l.errShortfallPolicy);
      return;
    }
    setState(() => _saving = true);
    final r = await ref.read(payoutServiceProvider).recordPayout(RecordPayoutInput(
          courierId: _courierId!,
          totalReceived: _received,
          selectedOrderIds: _selected.toList(),
          allocations: _lines(),
          paidAt: _paidAt,
          method: _method,
          reference: _reference.text,
          note: _note.text,
          policy: _hasShortfall ? _policy : null,
          allowOverpayment: _allowOver,
        ));
    if (!mounted) return;
    setState(() => _saving = false);
    final f = r.failureOrNull;
    if (f != null) {
      setState(() => _error = f is PayoutFailure ? _errText(l, f.error) : f.message);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.payoutSaved)));
    context.pushReplacement('/cod/payouts/${r.valueOrNull!.id}');
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.payoutNewTitle),
        leading: _step > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() {
                  _step--;
                  _error = null;
                }),
              )
            : null,
      ),
      body: switch (_step) {
        0 => _stepOne(l),
        1 => _stepTwo(l),
        _ => _stepThree(l),
      },
    );
  }

  Widget _errorBox() => _error == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        );

  Widget _stepOne(AppLocalizations l) {
    final couriers = ref.watch(couriersProvider).value ?? const [];
    final now = ref.watch(clockProvider).now();
    return ListView(padding: const EdgeInsets.all(16), children: [
      DropdownButtonFormField<String>(
        initialValue: couriers.any((c) => c.id == _courierId) ? _courierId : null,
        decoration: InputDecoration(labelText: l.courier),
        items: [for (final c in couriers) DropdownMenuItem(value: c.id, child: Text(c.name))],
        onChanged: (v) => setState(() => _courierId = v),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _total,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: l.totalReceived, prefixText: '৳ '),
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 12),
      Wrap(spacing: 8, children: [
        for (final m in _methods)
          ChoiceChip(
            label: Text(_methodLabel(l, m)),
            selected: _method == m,
            onSelected: (_) => setState(() => _method = m),
          ),
      ]),
      const SizedBox(height: 12),
      TextField(controller: _reference, decoration: InputDecoration(labelText: l.referenceNo)),
      const SizedBox(height: 12),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.event),
        title: Text(l.paidOn),
        subtitle: Text(formatDate(_paidAt ?? now)),
        onTap: () async {
          final d = await showDatePicker(
            context: context,
            initialDate: _paidAt ?? now,
            firstDate: now.subtract(const Duration(days: 365)),
            lastDate: now,
          );
          if (d != null) setState(() => _paidAt = d);
        },
      ),
      TextField(controller: _note, decoration: InputDecoration(labelText: l.fieldNotes)),
      _errorBox(),
      const SizedBox(height: 20),
      FilledButton(onPressed: _loadStep2, child: Text(l.nextStep)),
    ]);
  }

  String _methodLabel(AppLocalizations l, String m) => switch (m) {
        'bank' => l.methodBank,
        'bkash' => l.methodBkash,
        'nagad' => l.methodNagad,
        'cash' => l.methodCash,
        _ => l.methodOther,
      };

  Widget _stepTwo(AppLocalizations l) {
    if (_payable.isEmpty) {
      return EmptyState(icon: Icons.task_alt, title: l.noPayableOrders);
    }
    final expected = PayoutReconciler.expectedTotal(_selectedOrders);
    final diff = _received - expected;
    final shortfall = diff.poisha < 0;
    final t = Theme.of(context);
    final surplusNeedsFlag = diff.poisha > 0;
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(12),
        color: t.colorScheme.surfaceContainerHighest,
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('${l.expectedLabel}: ${expected.format()}'),
            Text('${l.receivedLabel}: ${_received.format()}'),
          ]),
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              Icon(diff.isZero ? Icons.check_circle : Icons.warning_amber,
                  size: 18,
                  color: diff.isZero ? Colors.green : t.colorScheme.error),
              const SizedBox(width: 6),
              Text(
                '${diff.isZero ? l.differenceLabel : (shortfall ? l.shortfallLabel : l.surplusLabel)}: '
                '${diff.format()}',
                style: t.textTheme.titleSmall,
              ),
            ]),
            TextButton(onPressed: _autoAllocate, child: Text(l.autoAllocate)),
          ]),
          if (surplusNeedsFlag)
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(l.allowOverpayment),
              value: _allowOver,
              onChanged: (v) => setState(() => _allowOver = v),
            ),
        ]),
      ),
      Expanded(
        child: ListView(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(l.selectOrdersTitle, style: t.textTheme.titleSmall),
          ),
          for (final p in _payable)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(children: [
                Checkbox(
                  value: _selected.contains(p.order.id),
                  onChanged: (v) {
                    setState(() {
                      v == true ? _selected.add(p.order.id) : _selected.remove(p.order.id);
                    });
                    _autoAllocate();
                  },
                ),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.order.orderNo, style: t.textTheme.titleSmall),
                    Text(
                      '${l.outstandingLabel}: ${p.reconcile.outstanding.format()}'
                      '${p.order.deliveredAt == null ? '' : ' · ${formatDate(p.order.deliveredAt!)}'}',
                      style: t.textTheme.bodySmall,
                    ),
                  ]),
                ),
                SizedBox(
                  width: 110,
                  child: TextField(
                    controller: _amounts[p.order.id],
                    enabled: _selected.contains(p.order.id),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      isDense: true,
                      prefixText: '৳ ',
                      labelText: l.amountApplied,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ]),
            ),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _errorBox()),
          const SizedBox(height: 80),
        ]),
      ),
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: _next, child: Text(l.nextStep)),
          ),
        ),
      ),
    ]);
  }

  Widget _stepThree(AppLocalizations l) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text(l.shortfallHandling, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      RadioGroup<ShortfallPolicy>(
        groupValue: _policy,
        onChanged: (v) => setState(() => _policy = v),
        child: Column(children: [
          RadioListTile<ShortfallPolicy>(
              value: ShortfallPolicy.allocate, title: Text(l.handleAllocate)),
          RadioListTile<ShortfallPolicy>(
              value: ShortfallPolicy.dispute, title: Text(l.handleDispute)),
          RadioListTile<ShortfallPolicy>(
              value: ShortfallPolicy.writeOff, title: Text(l.handleWriteOff)),
        ]),
      ),
      _errorBox(),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(l.confirmPayout),
      ),
    ]);
  }
}
