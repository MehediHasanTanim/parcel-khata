import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/features/couriers/application/courier_repository.dart';
import 'package:parcel_khata/features/orders/domain/order_enums.dart';
import 'package:parcel_khata/features/orders/domain/order_filter.dart';
import 'package:parcel_khata/features/orders/presentation/order_labels.dart';
import 'package:parcel_khata/l10n/l10n.dart';

const _filterStatuses = [
  OrderStatus.confirmed,
  OrderStatus.packed,
  OrderStatus.handedToCourier,
  OrderStatus.inTransit,
  OrderStatus.delivered,
  OrderStatus.deliveryFailed,
  OrderStatus.returnInTransit,
  OrderStatus.returned,
  OrderStatus.cancelled,
];

Future<OrderFilter?> showOrderFilterSheet(BuildContext context, OrderFilter current) {
  return showModalBottomSheet<OrderFilter>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _FilterSheet(initial: current),
  );
}

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet({required this.initial});

  final OrderFilter initial;

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late OrderFilter _f = widget.initial;
  late final _min = TextEditingController(
      text: _f.amountMinPoisha == null ? '' : '${_f.amountMinPoisha! ~/ 100}');
  late final _max = TextEditingController(
      text: _f.amountMaxPoisha == null ? '' : '${_f.amountMaxPoisha! ~/ 100}');
  late final _tag = TextEditingController(text: _f.tag ?? '');
  late final _area = TextEditingController(text: _f.area ?? '');

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    _tag.dispose();
    _area.dispose();
    super.dispose();
  }

  Future<void> _pickRange({
    required DateTime? from,
    required DateTime? to,
    required void Function(DateTime, DateTime) onPicked,
  }) async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
      initialDateRange: from == null || to == null
          ? null
          : DateTimeRange(start: from, end: to.subtract(const Duration(days: 1))),
    );
    if (r == null) return;
    onPicked(
      DateTime(r.start.year, r.start.month, r.start.day),
      DateTime(r.end.year, r.end.month, r.end.day).add(const Duration(days: 1)),
    );
  }

  OrderFilter _finish() {
    final min = Money.tryParse(_min.text);
    final max = Money.tryParse(_max.text);
    var f = _f.copyWith(clearAmount: true, clearTag: true, clearArea: true);
    f = f.copyWith(
      amountMinPoisha: min?.poisha,
      amountMaxPoisha: max?.poisha,
      tag: _tag.text.trim().isEmpty ? null : _tag.text.trim(),
      area: _area.text.trim().isEmpty ? null : _area.text.trim(),
    );
    return f;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final couriers = ref.watch(couriersProvider).value ?? const [];
    Widget dateRow(String label, DateTime? from, DateTime? to, VoidCallback pick, VoidCallback clear) =>
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          subtitle: from == null ? null : Text('${formatDate(from)} – ${formatDate(to!.subtract(const Duration(days: 1)))}'),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            if (from != null) IconButton(icon: const Icon(Icons.clear), onPressed: clear),
            IconButton(icon: const Icon(Icons.date_range), onPressed: pick),
          ]),
        );
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.85,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Expanded(child: Text(l.filtersTitle, style: t.titleLarge)),
                TextButton(
                  onPressed: () => Navigator.pop(context, OrderFilter(customerId: _f.customerId)),
                  child: Text(l.resetFilters),
                ),
              ]),
            ),
            Expanded(
              child: ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: [
                Text(l.ordersTitle, style: t.titleSmall),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final s in _filterStatuses)
                    FilterChip(
                      label: Text(statusLabel(l, s)),
                      selected: _f.statuses.contains(s),
                      onSelected: (v) => setState(() {
                        final n = {..._f.statuses};
                        v ? n.add(s) : n.remove(s);
                        _f = _f.copyWith(statuses: n);
                      }),
                    ),
                ]),
                const SizedBox(height: 16),
                Text(l.filterCodStatus, style: t.titleSmall),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final c in CodStatus.values)
                    FilterChip(
                      label: Text(codLabel(l, c)),
                      selected: _f.codStatuses.contains(c),
                      onSelected: (v) => setState(() {
                        final n = {..._f.codStatuses};
                        v ? n.add(c) : n.remove(c);
                        _f = _f.copyWith(codStatuses: n);
                      }),
                    ),
                ]),
                const SizedBox(height: 16),
                DropdownButtonFormField<String?>(
                  initialValue: couriers.any((c) => c.id == _f.courierId) ? _f.courierId : null,
                  decoration: InputDecoration(labelText: l.courier),
                  items: [
                    DropdownMenuItem<String?>(child: Text(l.allCouriers)),
                    for (final c in couriers)
                      DropdownMenuItem<String?>(value: c.id, child: Text(c.name)),
                  ],
                  onChanged: (v) => setState(() => _f = v == null
                      ? _f.copyWith(clearCourier: true)
                      : _f.copyWith(courierId: v)),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<Channel?>(
                  initialValue: _f.channel,
                  decoration: InputDecoration(labelText: l.channel),
                  items: [
                    DropdownMenuItem<Channel?>(child: Text(l.statusAll)),
                    for (final c in Channel.values)
                      DropdownMenuItem<Channel?>(value: c, child: Text(channelLabel(l, c))),
                  ],
                  onChanged: (v) => setState(() => _f = v == null
                      ? _f.copyWith(clearChannel: true)
                      : _f.copyWith(channel: v)),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<PaymentType?>(
                  initialValue: _f.paymentType,
                  decoration: InputDecoration(labelText: l.paymentType),
                  items: [
                    DropdownMenuItem<PaymentType?>(child: Text(l.statusAll)),
                    for (final p in PaymentType.values)
                      DropdownMenuItem<PaymentType?>(value: p, child: Text(paymentLabel(l, p))),
                  ],
                  onChanged: (v) => setState(() => _f = v == null
                      ? _f.copyWith(clearPaymentType: true)
                      : _f.copyWith(paymentType: v)),
                ),
                const SizedBox(height: 12),
                dateRow(
                  l.orderDates,
                  _f.from,
                  _f.to,
                  () => _pickRange(
                    from: _f.from,
                    to: _f.to,
                    onPicked: (a, b) => setState(() => _f = _f.copyWith(from: a, to: b)),
                  ),
                  () => setState(() => _f = _f.copyWith(clearDates: true)),
                ),
                dateRow(
                  l.dispatchDates,
                  _f.dispatchFrom,
                  _f.dispatchTo,
                  () => _pickRange(
                    from: _f.dispatchFrom,
                    to: _f.dispatchTo,
                    onPicked: (a, b) =>
                        setState(() => _f = _f.copyWith(dispatchFrom: a, dispatchTo: b)),
                  ),
                  () => setState(() => _f = _f.copyWith(clearDispatch: true)),
                ),
                dateRow(
                  l.deliveredDates,
                  _f.deliveredFrom,
                  _f.deliveredTo,
                  () => _pickRange(
                    from: _f.deliveredFrom,
                    to: _f.deliveredTo,
                    onPicked: (a, b) =>
                        setState(() => _f = _f.copyWith(deliveredFrom: a, deliveredTo: b)),
                  ),
                  () => setState(() => _f = _f.copyWith(clearDelivered: true)),
                ),
                const SizedBox(height: 8),
                Text(l.filterProfit, style: t.titleSmall),
                const SizedBox(height: 8),
                SegmentedButton<ProfitSign?>(
                  emptySelectionAllowed: true,
                  segments: [
                    ButtonSegment(value: ProfitSign.profit, label: Text(l.profitOnly)),
                    ButtonSegment(value: ProfitSign.loss, label: Text(l.lossOnly)),
                  ],
                  selected: {if (_f.profitSign != null) _f.profitSign},
                  onSelectionChanged: (s) => setState(() => _f = s.isEmpty
                      ? _f.copyWith(clearProfitSign: true)
                      : _f.copyWith(profitSign: s.first)),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _min,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: l.amountMin, prefixText: '৳ '),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _max,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: l.amountMax, prefixText: '৳ '),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _tag,
                      decoration: InputDecoration(labelText: l.tagLabel),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _area,
                      decoration: InputDecoration(labelText: l.areaLabel),
                    ),
                  ),
                ]),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.hasReturnLabel),
                  value: _f.hasReturn ?? false,
                  onChanged: (v) => setState(() => _f = v
                      ? _f.copyWith(hasReturn: true)
                      : _f.copyWith(clearHasReturn: true)),
                ),
                const SizedBox(height: 16),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, _finish()),
                  child: Text(l.applyFilters),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
