import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:parcel_khata/core/db/app_database.dart';
import 'package:parcel_khata/core/db/providers.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:drift/drift.dart' show BooleanExpressionOperators;
import 'package:parcel_khata/features/orders/domain/cod_amount_calculator.dart';
import 'package:parcel_khata/features/returns/application/exchange_service.dart';
import 'package:parcel_khata/features/returns/application/return_service.dart';
import 'package:parcel_khata/features/returns/domain/exchange_calculator.dart';
import 'package:parcel_khata/l10n/l10n.dart';

class _Row {
  _Row({String name = '', String qty = '1', String sell = '', String cost = ''})
      : name = TextEditingController(text: name),
        qty = TextEditingController(text: qty),
        sell = TextEditingController(text: sell),
        cost = TextEditingController(text: cost);
  final TextEditingController name;
  final TextEditingController qty;
  final TextEditingController sell;
  final TextEditingController cost;

  void dispose() {
    name.dispose();
    qty.dispose();
    sell.dispose();
    cost.dispose();
  }
}

/// "Wrong size, send replacement": one linked return + replacement order.
class ExchangeScreen extends ConsumerStatefulWidget {
  const ExchangeScreen({required this.orderId, super.key});

  final String orderId;

  @override
  ConsumerState<ExchangeScreen> createState() => _ExchangeScreenState();
}

class _ExchangeScreenState extends ConsumerState<ExchangeScreen> {
  List<OrderLine> _lines = const [];
  final Map<String, int> _returnQty = {};
  final List<_Row> _rows = [];
  final _delivery = TextEditingController();
  final _returnShipping = TextEditingController();
  ExchangePayer _payer = ExchangePayer.seller;
  ExchangePreview? _preview;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    _delivery.dispose();
    _returnShipping.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final lines = await (db.select(db.orderLines)
          ..where((l) => l.orderId.equals(widget.orderId) & l.deletedAt.isNull()))
        .get();
    if (!mounted) return;
    setState(() {
      _lines = lines;
      _loading = false;
    });
  }

  Money _money(TextEditingController c) => Money.tryParse(c.text.trim()) ?? Money.zero;

  List<LineInput> _replacementLines() => [
        for (final r in _rows)
          if (r.name.text.trim().isNotEmpty &&
              (int.tryParse(r.qty.text.trim()) ?? 0) > 0 &&
              Money.tryParse(r.sell.text.trim()) != null)
            LineInput(
              name: r.name.text.trim(),
              qty: int.parse(r.qty.text.trim()),
              unitSell: Money.tryParse(r.sell.text.trim())!,
              unitCost: Money.tryParse(r.cost.text.trim()),
            ),
      ];

  ExchangeRequest _request() => ExchangeRequest(
        originalOrderId: widget.orderId,
        returned: [
          for (final e in _returnQty.entries)
            if (e.value > 0) ReturnQty(e.key, e.value),
        ],
        replacementLines: _replacementLines(),
        payer: _payer,
        replacementDelivery: _money(_delivery),
        returnShipping: _money(_returnShipping),
      );

  Future<void> _refresh() async {
    final res = await ref.read(exchangeServiceProvider).preview(_request());
    if (!mounted) return;
    setState(() => _preview = res.isOk ? res.valueOrNull : null);
  }

  void _sameItems() {
    for (final r in _rows) {
      r.dispose();
    }
    _rows.clear();
    for (final l in _lines) {
      final q = _returnQty[l.id] ?? 0;
      if (q <= 0) continue;
      _rows.add(_Row(
        name: l.nameSnapshot,
        qty: '$q',
        sell: Money(l.unitSellPrice).format(symbol: false, decimals: l.unitSellPrice % 100 != 0),
        cost: l.unitCostPrice == null
            ? ''
            : Money(l.unitCostPrice!)
                .format(symbol: false, decimals: l.unitCostPrice! % 100 != 0),
      ));
    }
    setState(() {});
    _refresh();
  }

  Future<void> _create() async {
    final l = context.l10n;
    setState(() => _saving = true);
    final res = await ref.read(exchangeServiceProvider).create(_request());
    if (!mounted) return;
    setState(() => _saving = false);
    final messenger = ScaffoldMessenger.of(context);
    if (res.isOk) {
      messenger.showSnackBar(SnackBar(content: Text(l.exchangeCreated)));
      context.pushReplacement('/orders/${res.valueOrNull!.replacement.id}');
    } else {
      final f = res.failureOrNull!;
      final msg = switch (f.message) {
        'exchange_needs_delivered' => l.exchangeNotDelivered,
        'return_exists' => l.exchangeExists,
        'no_lines' || 'no_replacement' => l.exchangeNeedItems,
        _ => f.message,
      };
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final pv = _preview;
    final canCreate = pv != null && !_saving;
    return Scaffold(
      appBar: AppBar(title: Text(l.exchangeTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              Text(l.exchangeReturnedItems, style: theme.textTheme.titleMedium),
              for (final line in _lines)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(line.nameSnapshot),
                  subtitle: Text(Money(line.unitSellPrice).format()),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: (_returnQty[line.id] ?? 0) > 0
                          ? () {
                              setState(() => _returnQty[line.id] = _returnQty[line.id]! - 1);
                              _refresh();
                            }
                          : null,
                    ),
                    Text('${_returnQty[line.id] ?? 0} / ${line.qty}'),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: (_returnQty[line.id] ?? 0) < line.qty
                          ? () {
                              setState(() =>
                                  _returnQty[line.id] = (_returnQty[line.id] ?? 0) + 1);
                              _refresh();
                            }
                          : null,
                    ),
                  ]),
                ),
              const SizedBox(height: 16),
              Text(l.exchangeReplacementItems, style: theme.textTheme.titleMedium),
              for (var i = 0; i < _rows.length; i++) _rowCard(l, i),
              Wrap(spacing: 8, children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.add),
                  label: Text(l.exchangeAddItem),
                  onPressed: () => setState(() => _rows.add(_Row())),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.swap_horiz),
                  label: Text(l.exchangeSameItems),
                  onPressed: _sameItems,
                ),
              ]),
              const SizedBox(height: 16),
              Text(l.exchangeWhoPays, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<ExchangePayer>(
                segments: [
                  ButtonSegment(
                      value: ExchangePayer.seller, label: Text(l.exchangePayerSeller)),
                  ButtonSegment(
                      value: ExchangePayer.customer, label: Text(l.exchangePayerCustomer)),
                ],
                selected: {_payer},
                onSelectionChanged: (s) {
                  setState(() => _payer = s.first);
                  _refresh();
                },
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _moneyField(_delivery, l.exchangeDeliveryCharge)),
                const SizedBox(width: 8),
                Expanded(child: _moneyField(_returnShipping, l.exchangeReturnShipping)),
              ]),
              const SizedBox(height: 16),
              if (pv != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(children: [
                      _kv(l.exchangeValueReturned, pv.returnedValue.format()),
                      _kv(l.exchangeValueReplacement, pv.replacementValue.format()),
                      const Divider(),
                      _kv(l.exchangeCollect, pv.outcome.replacementCod.format(), bold: true),
                      if (!pv.outcome.refundDue.isZero)
                        _kv(l.exchangeRefundDue, pv.outcome.refundDue.format(), bold: true),
                      if (!pv.outcome.businessShippingLoss.isZero)
                        _kv(l.exchangeShippingLoss,
                            pv.outcome.businessShippingLoss.format()),
                    ]),
                  ),
                )
              else
                Text(l.exchangeNeedItems, style: theme.textTheme.bodySmall),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: canCreate ? _create : null,
                child: Text(l.exchangeCreate),
              ),
            ]),
    );
  }

  Widget _kv(String k, String v, {bool bold = false}) {
    final style = bold ? Theme.of(context).textTheme.titleMedium : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Flexible(child: Text(k, style: style)),
        Text(v, style: style),
      ]),
    );
  }

  Widget _moneyField(TextEditingController c, String label) => TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, prefixText: '৳ '),
        onChanged: (_) => _refresh(),
      );

  Widget _rowCard(AppLocalizations l, int i) {
    final r = _rows[i];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(children: [
          Row(children: [
            Expanded(
              child: TextField(
                controller: r.name,
                decoration: InputDecoration(labelText: l.exchangeItemName),
                onChanged: (_) => _refresh(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                setState(() => _rows.removeAt(i).dispose());
                _refresh();
              },
            ),
          ]),
          Row(children: [
            SizedBox(
              width: 70,
              child: TextField(
                controller: r.qty,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l.exchangeQty),
                onChanged: (_) => _refresh(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: _moneyField(r.sell, l.exchangeSell)),
            const SizedBox(width: 8),
            Expanded(child: _moneyField(r.cost, l.exchangeCost)),
          ]),
        ]),
      ),
    );
  }
}

/// Order-detail card: link to the other half and the pair's combined profit.
class ExchangeLinkCard extends ConsumerWidget {
  const ExchangeLinkCard({required this.orderId, super.key});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return FutureBuilder<ExchangeGroup?>(
      future: ref.read(exchangeServiceProvider).groupFor(orderId),
      builder: (_, snap) {
        final g = snap.data;
        if (g == null) return const SizedBox.shrink();
        final isOriginal = g.original.id == orderId;
        final other = isOriginal ? g.replacement : g.original;
        return Card(
          margin: const EdgeInsets.only(bottom: 20),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.exchangeLinked, style: Theme.of(context).textTheme.titleMedium),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.swap_horiz),
                title: Text(other.orderNo),
                subtitle: Text(isOriginal
                    ? l.exchangeReplacementOrder
                    : l.exchangeOriginalOrder),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/orders/${other.id}'),
              ),
              if (!g.incomplete)
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(l.exchangeGroupProfit),
                  Text(g.net.format(), style: Theme.of(context).textTheme.titleMedium),
                ]),
            ]),
          ),
        );
      },
    );
  }
}
