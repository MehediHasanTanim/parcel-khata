import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:parcel_khata/core/db/app_database.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/core/result/result.dart';
import 'package:parcel_khata/features/couriers/application/courier_repository.dart';
import 'package:parcel_khata/features/couriers/domain/charge_calculator.dart';
import 'package:parcel_khata/features/customers/application/customer_repository.dart';
import 'package:parcel_khata/features/orders/application/order_repository.dart';
import 'package:parcel_khata/features/orders/domain/cod_amount_calculator.dart';
import 'package:parcel_khata/features/orders/domain/order_enums.dart';
import 'package:parcel_khata/features/orders/domain/order_input.dart';
import 'package:parcel_khata/features/orders/presentation/order_labels.dart';
import 'package:parcel_khata/features/products/application/product_repository.dart';
import 'package:parcel_khata/features/settings/application/settings_repository.dart';
import 'package:parcel_khata/l10n/l10n.dart';
import 'package:parcel_khata/shared/form_helpers.dart';
import 'package:parcel_khata/shared/status_chip.dart';

class _LineCtl {
  _LineCtl({
    String name = '',
    this.qty = 1,
    String sell = '',
    String cost = '',
    String discount = '',
    this.productId,
    this.variantId,
  })  : name = TextEditingController(text: name),
        sell = TextEditingController(text: sell),
        cost = TextEditingController(text: cost),
        discount = TextEditingController(text: discount);

  final TextEditingController name;
  final TextEditingController sell;
  final TextEditingController cost;
  final TextEditingController discount;
  int qty;
  String? productId;
  String? variantId;

  LineInput toInput() => LineInput(
        name: name.text.trim(),
        qty: qty,
        unitSell: parseMoneyOrNull(sell.text) ?? Money.zero,
        unitCost: parseMoneyOrNull(cost.text),
        discount: Discount.amount(parseMoneyOrNull(discount.text) ?? Money.zero),
        productId: productId,
        variantId: variantId,
      );

  void dispose() {
    name.dispose();
    sell.dispose();
    cost.dispose();
    discount.dispose();
  }
}

String _plain(int poisha) =>
    poisha == 0 ? '' : Money(poisha).format(symbol: false, decimals: poisha % 100 != 0);

/// Create or edit an order (also used to resume a draft).
class OrderFormScreen extends ConsumerStatefulWidget {
  const OrderFormScreen({this.orderId, super.key});

  final String? orderId;

  @override
  ConsumerState<OrderFormScreen> createState() => _OrderFormScreenState();
}

class _OrderFormScreenState extends ConsumerState<OrderFormScreen> {
  late final OrderRepository _repo;
  late final ProductRepository _products;

  Customer? _customer;
  final _address = TextEditingController();
  final List<_LineCtl> _lines = [];
  final _orderDiscount = TextEditingController();
  bool _discountPercent = false;
  final _delivery = TextEditingController();
  final _advance = TextEditingController();
  final _advanceMethod = TextEditingController();
  final _codOverride = TextEditingController();
  bool _overrideOn = false;
  PaymentType _payment = PaymentType.cod;
  String? _courierId;
  String? _zone = 'inside_dhaka';
  final _weight = TextEditingController();
  final _cn = TextEditingController();
  Channel _channel = Channel.facebook;
  final _sourceRef = TextEditingController();
  final _notes = TextEditingController();
  DateTime? _orderDate;

  bool _loaded = false;
  bool _dirty = false;
  bool _saved = false;
  bool _isDraft = false;
  bool _existingNonDraft = false;
  String? _error;
  String? _conflictOrderId;

  List<TextEditingController> get _all =>
      [_address, _orderDiscount, _delivery, _advance, _advanceMethod, _codOverride, _weight, _cn, _sourceRef, _notes];

  @override
  void initState() {
    super.initState();
    _repo = ref.read(orderRepositoryProvider);
    _products = ref.read(productRepositoryProvider);
    _all.forEach((c) => c.addListener(_changed));
    unawaited(_init());
  }

  void _changed() {
    if (!_loaded) return;
    setState(() => _dirty = true);
  }

  Future<void> _init() async {
    final settings = await ref.read(settingsRepositoryProvider).read();
    if (widget.orderId == null) {
      _channel = Channel.fromDb(settings.defaultChannel);
      _delivery.text = settings.defaultDeliveryChargeTaka == 0
          ? ''
          : '${settings.defaultDeliveryChargeTaka}';
      _courierId = settings.defaultCourierId;
    } else {
      final d = await _repo.detail(widget.orderId!);
      if (d == null) {
        if (mounted) context.pop();
        return;
      }
      final o = d.order;
      _customer = d.customer;
      _address.text = o.addressSnapshot;
      _channel = Channel.fromDb(o.channel);
      _sourceRef.text = o.sourceRef ?? '';
      _payment = PaymentType.fromDb(o.paymentType);
      _delivery.text = _plain(o.deliveryChargeCustomer);
      _advance.text = _plain(o.advanceReceived);
      _advanceMethod.text = o.advanceMethod ?? '';
      _orderDiscount.text = _plain(o.discountTotal);
      _courierId = o.courierId;
      _zone = o.zone ?? 'inside_dhaka';
      _weight.text = o.weightG?.toString() ?? '';
      _cn.text = o.consignmentNo ?? '';
      _notes.text = o.notes ?? '';
      _orderDate = o.orderDate;
      _overrideOn = o.codOverridden;
      if (o.codOverridden) _codOverride.text = _plain(o.codExpected);
      _isDraft = OrderStatus.fromDb(o.status) == OrderStatus.draft;
      _existingNonDraft = !_isDraft;
      for (final l in d.lines) {
        _lines.add(_LineCtl(
          name: l.nameSnapshot,
          qty: l.qty,
          sell: _plain(l.unitSellPrice),
          cost: l.unitCostPrice == null ? '' : _plain(l.unitCostPrice!),
          discount: _plain(l.lineDiscount),
          productId: l.productId,
          variantId: l.variantId,
        ));
      }
    }
    if (!mounted) return;
    setState(() => _loaded = true);
    for (final l in _lines) {
      _listen(l);
    }
  }

  void _listen(_LineCtl l) {
    for (final c in [l.name, l.sell, l.cost, l.discount]) {
      c.addListener(_changed);
    }
  }

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  // ----------------------------------------------------------- build input

  OrderInput _input() {
    final disc = parseMoneyOrNull(_orderDiscount.text) ?? Money.zero;
    return OrderInput(
      customerId: _customer?.id,
      address: _address.text,
      orderDate: _orderDate,
      channel: _channel,
      sourceRef: _sourceRef.text,
      lines: [for (final l in _lines) l.toInput()],
      paymentType: _payment,
      advance: parseMoneyOrNull(_advance.text) ?? Money.zero,
      advanceMethod: _advanceMethod.text,
      deliveryCharge: parseMoneyOrNull(_delivery.text) ?? Money.zero,
      // Percent mode stores the entered number as whole percent.
      orderDiscount: _discountPercent
          ? Discount.percentBp(disc.poisha.clamp(0, 10000))
          : Discount.amount(disc),
      codOverride: _overrideOn ? parseMoneyOrNull(_codOverride.text) : null,
      courierId: _courierId,
      consignmentNo: _cn.text,
      zone: _courierId == null ? null : _zone,
      weightG: int.tryParse(_weight.text.trim()),
      notes: _notes.text,
    );
  }

  // ---------------------------------------------------------------- save

  Future<void> _save({required bool asDraft}) async {
    final l = context.l10n;
    final input = _input();
    setState(() {
      _error = null;
      _conflictOrderId = null;
    });
    final Result<Order> result;
    var confirmed = false;
    if (widget.orderId == null) {
      result = await _repo.create(input, draft: asDraft);
    } else if (asDraft && _isDraft) {
      result = await _repo.saveDraft(widget.orderId, input);
    } else {
      var r = await _repo.update(widget.orderId!, input,
          promoteDraft: _isDraft && !asDraft);
      if (r.failureOrNull is ConfirmationRequiredFailure && mounted) {
        confirmed = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                content: Text(l.confirmEditDelivered),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
                  FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l.confirm)),
                ],
              ),
            ) ??
            false;
        if (!confirmed) return;
        r = await _repo.update(widget.orderId!, input,
            confirmed: true, promoteDraft: _isDraft && !asDraft);
      }
      if (!mounted) return;
      if (r.isOk && r.valueOrNull!.warnings.isNotEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.warnEditAfterHandover)));
      }
      result = r.when(ok: (o) => Result.ok(o.order), err: Result.err);
    }
    if (!mounted) return;
    result.when(
      ok: (o) {
        _saved = true;
        final m = ScaffoldMessenger.of(context);
        if (asDraft) {
          m.showSnackBar(SnackBar(content: Text(l.draftSaved)));
          context.pop();
        } else if (widget.orderId == null) {
          m.showSnackBar(SnackBar(content: Text(l.orderCreated)));
          context.pushReplacement('/orders/${o.id}');
        } else {
          m.showSnackBar(SnackBar(content: Text(l.orderUpdated)));
          context.pop();
        }
      },
      err: (f) => setState(() {
        if (f is ConflictFailure) {
          _error = l.errCnTaken;
          _conflictOrderId = f.conflictingId;
        } else {
          _error = switch (f.message) {
            'customer_required' => l.errCustomerRequired,
            'items_required' => l.errItemsRequired,
            'address_required' => l.errAddressRequired,
            _ => f.message,
          };
        }
      }),
    );
  }

  /// Leaving a new order or a draft with data keeps it as a draft (F1 AC4).
  void _autosaveDraft() {
    if (_saved || !_dirty || _existingNonDraft) return;
    final input = _input();
    if (!input.hasAnyData) return;
    unawaited(_repo.saveDraft(widget.orderId, input));
  }

  // -------------------------------------------------------------- pickers

  Future<void> _pickCustomer() async {
    final picked = await showModalBottomSheet<Customer>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CustomerPickerSheet(),
    );
    if (picked == null || !mounted) return;
    final addrs = await ref.read(customerRepositoryProvider).addresses(picked.id);
    if (!mounted) return;
    setState(() {
      _customer = picked;
      _dirty = true;
      if (_address.text.trim().isEmpty && addrs.isNotEmpty) {
        _address.text = addrs.first.fullText;
      }
    });
  }

  Future<void> _chooseAddress() async {
    if (_customer == null) return;
    final addrs = await ref.read(customerRepositoryProvider).addresses(_customer!.id);
    if (!mounted) return;
    final a = await showModalBottomSheet<CustomerAddress>(
      context: context,
      builder: (_) => ListView(
        shrinkWrap: true,
        children: [
          for (final a in addrs)
            ListTile(
              leading: Icon(a.isDefault ? Icons.star : Icons.place_outlined),
              title: Text(a.fullText),
              subtitle: Text(a.label),
              onTap: () => Navigator.pop(context, a),
            ),
        ],
      ),
    );
    if (a != null) _address.text = a.fullText;
  }

  Future<void> _addFromCatalog() async {
    final p = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ProductPickerSheet(),
    );
    if (p == null || !mounted) return;
    final variants = await _products.variants(p.id);
    if (!mounted) return;
    ProductVariant? v;
    if (variants.isNotEmpty) {
      v = await showModalBottomSheet<ProductVariant>(
        context: context,
        builder: (_) => ListView(shrinkWrap: true, children: [
          for (final x in variants)
            ListTile(title: Text(x.label), onTap: () => Navigator.pop(context, x)),
        ]),
      );
      if (v == null) return;
    }
    // Snapshot price and cost onto the line now (F3).
    final sell = v?.sellPrice ?? p.defaultSellPrice;
    final cost = v?.costPrice ?? p.defaultCostPrice;
    final line = _LineCtl(
      name: v == null ? p.name : '${p.name} (${v.label})',
      sell: _plain(sell),
      cost: cost == null ? '' : _plain(cost),
      productId: p.id,
      variantId: v?.id,
    );
    _listen(line);
    setState(() {
      _lines.add(line);
      _dirty = true;
    });
  }

  void _addFreeText() {
    final line = _LineCtl();
    _listen(line);
    setState(() {
      _lines.add(line);
      _dirty = true;
    });
  }

  Future<void> _saveLineToCatalog(_LineCtl line) async {
    final name = line.name.text.trim();
    if (name.isEmpty) return;
    final r = await _products.create(ProductInput(
      name: name,
      sellPrice: parseMoneyOrNull(line.sell.text) ?? Money.zero,
      costPrice: parseMoneyOrNull(line.cost.text),
    ));
    if (!mounted) return;
    r.when(
      ok: (p) {
        setState(() => line.productId = p.id);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.savedToCatalog)));
      },
      err: (f) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(f.message))),
    );
  }

  // ------------------------------------------------------------------ UI

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context);
    final input = _input();
    final b = input.breakdown;
    final couriers = ref.watch(couriersProvider).value ?? const <Courier>[];
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _autosaveDraft();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.orderId == null ? l.orderNew : l.orderEdit),
        ),
        bottomNavigationBar: !_loaded
            ? null
            : SafeArea(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  decoration: BoxDecoration(
                    color: t.colorScheme.surface,
                    border: Border(top: BorderSide(color: t.dividerColor)),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.codAmount, style: t.textTheme.labelMedium),
                          Text(b.effective.format(), style: t.textTheme.headlineSmall),
                          if (b.overridden)
                            Text(l.codOverriddenMark,
                                style: t.textTheme.labelSmall
                                    ?.copyWith(color: t.colorScheme.error)),
                        ],
                      ),
                    ),
                    if (!_existingNonDraft)
                      OutlinedButton(
                        onPressed: () => _save(asDraft: true),
                        child: Text(l.saveDraft),
                      ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => _save(asDraft: false),
                      child: Text(l.saveOrder),
                    ),
                  ]),
                ),
              ),
        body: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.all(16), children: [
                if (_error != null)
                  Card(
                    color: t.colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(children: [
                        Icon(Icons.error_outline, color: t.colorScheme.onErrorContainer),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_error!,
                              style: TextStyle(color: t.colorScheme.onErrorContainer)),
                        ),
                        if (_conflictOrderId != null)
                          TextButton(
                            onPressed: () => context.push('/orders/$_conflictOrderId'),
                            child: Text(l.viewConflictingOrder),
                          ),
                      ]),
                    ),
                  ),
                _heading(l.customer),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text(_customer?.name ?? l.selectCustomer),
                    subtitle: _customer == null ? null : Text(_customer!.phonePrimary),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _pickCustomer,
                  ),
                ),
                gap(8),
                TextField(
                  controller: _address,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: l.deliveryAddress,
                    suffixIcon: _customer == null
                        ? null
                        : IconButton(
                            tooltip: l.chooseSavedAddress,
                            icon: const Icon(Icons.bookmark_outline),
                            onPressed: _chooseAddress,
                          ),
                  ),
                ),
                gap(20),
                _heading(l.items),
                for (var i = 0; i < _lines.length; i++) _lineCard(l, i),
                gap(8),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _addFromCatalog,
                      icon: const Icon(Icons.inventory_2_outlined),
                      label: Text(l.addFromCatalog),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _addFreeText,
                      icon: const Icon(Icons.edit_outlined),
                      label: Text(l.addFreeText),
                    ),
                  ),
                ]),
                gap(20),
                _heading(l.paymentType),
                SegmentedButton<PaymentType>(
                  segments: [
                    ButtonSegment(value: PaymentType.cod, label: Text(l.payCod)),
                    ButtonSegment(value: PaymentType.prepaid, label: Text(l.payPrepaid)),
                    ButtonSegment(value: PaymentType.partialAdvance, label: Text(l.payPartial)),
                  ],
                  selected: {_payment},
                  onSelectionChanged: (s) => setState(() {
                    _payment = s.first;
                    _dirty = true;
                  }),
                ),
                if (_payment == PaymentType.partialAdvance) ...[
                  gap(),
                  MoneyFormField(controller: _advance, label: l.advanceReceived),
                  gap(8),
                  TextField(
                    controller: _advanceMethod,
                    decoration: InputDecoration(labelText: l.advanceMethod),
                  ),
                ],
                gap(),
                MoneyFormField(controller: _delivery, label: l.deliveryCharge),
                gap(),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _orderDiscount,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: l.orderDiscount,
                        prefixText: _discountPercent ? null : '৳ ',
                        suffixText: _discountPercent ? '%' : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: Text(l.discountPercent),
                    selected: _discountPercent,
                    onSelected: (v) => setState(() {
                      _discountPercent = v;
                      _dirty = true;
                    }),
                  ),
                ]),
                gap(16),
                _totals(l, b),
                gap(20),
                _heading(l.courier),
                DropdownButtonFormField<String?>(
                  initialValue: couriers.any((c) => c.id == _courierId) ? _courierId : null,
                  decoration: InputDecoration(labelText: l.courier),
                  items: [
                    DropdownMenuItem<String?>(child: Text(l.noCourier)),
                    for (final c in couriers)
                      DropdownMenuItem<String?>(value: c.id, child: Text(c.name)),
                  ],
                  onChanged: (v) => setState(() {
                    _courierId = v;
                    _dirty = true;
                  }),
                ),
                if (_courierId != null) ...[
                  gap(),
                  Row(children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _zone,
                        decoration: InputDecoration(labelText: l.zone),
                        items: [
                          for (final z in kZones)
                            DropdownMenuItem(value: z, child: Text(zoneLabel(l, z))),
                        ],
                        onChanged: (v) => setState(() {
                          _zone = v;
                          _dirty = true;
                        }),
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
                  gap(),
                  TextField(
                    controller: _cn,
                    decoration: InputDecoration(labelText: l.consignmentNo),
                  ),
                  _ExpectedFees(
                    key: ValueKey('${_courierId}_${_zone}_${_weight.text}_${b.effective.poisha}'),
                    repo: _repo,
                    courierId: _courierId,
                    zone: _zone,
                    weightG: int.tryParse(_weight.text.trim()),
                    cod: b.effective,
                  ),
                ],
                gap(20),
                DropdownButtonFormField<Channel>(
                  initialValue: _channel,
                  decoration: InputDecoration(labelText: l.channel),
                  items: [
                    for (final c in Channel.values)
                      DropdownMenuItem(value: c, child: Text(channelLabel(l, c))),
                  ],
                  onChanged: (v) => setState(() {
                    _channel = v ?? _channel;
                    _dirty = true;
                  }),
                ),
                gap(),
                TextField(
                  controller: _sourceRef,
                  decoration: InputDecoration(labelText: l.sourceRef),
                ),
                gap(),
                TextField(
                  controller: _notes,
                  maxLines: 2,
                  decoration: InputDecoration(labelText: l.internalNotes),
                ),
                gap(24),
              ]),
      ),
    );
  }

  Widget _heading(String s) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(s, style: Theme.of(context).textTheme.titleMedium),
      );

  Widget _totals(AppLocalizations l, CodBreakdown b) {
    Widget row(String k, String v, {bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(k, style: bold ? Theme.of(context).textTheme.titleSmall : null),
            Text(v, style: bold ? Theme.of(context).textTheme.titleSmall : null),
          ]),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          row(l.itemsTotal, b.itemsTotal.format()),
          if (!b.orderDiscount.isZero)
            row(l.discountLabel, '−${b.orderDiscount.format()}'),
          row(l.deliveryCharge, b.deliveryCharge.format()),
          row(l.total, b.grandTotal.format(), bold: true),
          if (!b.advance.isZero) row(l.advanceLabel, '−${b.advance.format()}'),
          const Divider(),
          row(l.codAmount, b.calculated.format(), bold: true),
          if (_payment != PaymentType.prepaid)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.overrideCod),
              value: _overrideOn,
              onChanged: (v) => setState(() {
                _overrideOn = v;
                _dirty = true;
                if (v && _codOverride.text.isEmpty) {
                  _codOverride.text = _plain(b.calculated.poisha);
                }
              }),
            ),
          if (_overrideOn && _payment != PaymentType.prepaid) ...[
            MoneyFormField(controller: _codOverride, label: l.codAmount),
            Align(
              alignment: Alignment.centerLeft,
              child: Row(children: [
                StatusChip(
                    label: l.codOverriddenMark,
                    icon: Icons.edit,
                    tone: StatusTone.warning),
                TextButton(
                  onPressed: () => setState(() {
                    _overrideOn = false;
                    _codOverride.clear();
                  }),
                  child: Text(l.resetToCalculated),
                ),
              ]),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _lineCard(AppLocalizations l, int i) {
    final line = _lines[i];
    final fromCatalog = line.productId != null;
    final costMissing = line.cost.text.trim().isEmpty;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Row(children: [
            Expanded(
              child: TextField(
                controller: line.name,
                decoration: InputDecoration(labelText: l.itemName),
              ),
            ),
            IconButton(
              tooltip: l.remove,
              icon: const Icon(Icons.delete_outline),
              onPressed: () => setState(() {
                _lines.removeAt(i).dispose();
                _dirty = true;
              }),
            ),
          ]),
          gap(8),
          Row(children: [
            IconButton.outlined(
              onPressed: line.qty > 1
                  ? () => setState(() {
                        line.qty--;
                        _dirty = true;
                      })
                  : null,
              icon: const Icon(Icons.remove),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('${line.qty}', style: Theme.of(context).textTheme.titleMedium),
            ),
            IconButton.outlined(
              onPressed: () => setState(() {
                line.qty++;
                _dirty = true;
              }),
              icon: const Icon(Icons.add),
            ),
            const SizedBox(width: 12),
            Expanded(child: MoneyFormField(controller: line.sell, label: l.unitPrice)),
          ]),
          gap(8),
          Row(children: [
            Expanded(child: MoneyFormField(controller: line.cost, label: l.unitCost)),
            const SizedBox(width: 8),
            Expanded(child: MoneyFormField(controller: line.discount, label: l.lineDiscount)),
          ]),
          gap(8),
          Row(children: [
            if (costMissing)
              StatusChip(
                  label: l.costMissing,
                  icon: Icons.warning_amber,
                  tone: StatusTone.warning),
            const Spacer(),
            if (!fromCatalog)
              TextButton.icon(
                onPressed: () => _saveLineToCatalog(line),
                icon: const Icon(Icons.bookmark_add_outlined),
                label: Text(l.saveToCatalog),
              ),
          ]),
        ]),
      ),
    );
  }
}

class _ExpectedFees extends StatelessWidget {
  const _ExpectedFees({
    required this.repo,
    required this.courierId,
    required this.zone,
    required this.weightG,
    required this.cod,
    super.key,
  });

  final OrderRepository repo;
  final String? courierId;
  final String? zone;
  final int? weightG;
  final Money cod;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return FutureBuilder<ExpectedCharges?>(
      future: repo.previewCharges(
          courierId: courierId, zone: zone, weightG: weightG, cod: cod),
      builder: (_, snap) {
        final e = snap.data;
        if (e == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            '${l.expectedDeliveryFee}: ${e.deliveryFee?.format() ?? '—'}   '
            '${l.expectedCodFee}: ${e.codFee.format()}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        );
      },
    );
  }
}

class _CustomerPickerSheet extends ConsumerStatefulWidget {
  const _CustomerPickerSheet();

  @override
  ConsumerState<_CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends ConsumerState<_CustomerPickerSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final rows = ref.watch(customerSearchProvider(_q)).value ?? const <Customer>[];
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search), hintText: l.searchCustomers),
                onChanged: (v) => setState(() => _q = v),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person_add),
              title: Text(l.addNewCustomer),
              onTap: () async {
                final nav = Navigator.of(context);
                final id = await context.push<String>('/customers/new');
                if (id == null) return;
                final c = await ref.read(customerRepositoryProvider).getById(id);
                if (c != null) nav.pop(c);
              },
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: rows.length,
                itemBuilder: (_, i) => ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(rows[i].name),
                  subtitle: Text(rows[i].phonePrimary),
                  onTap: () => Navigator.pop(context, rows[i]),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ProductPickerSheet extends ConsumerStatefulWidget {
  const _ProductPickerSheet();

  @override
  ConsumerState<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends ConsumerState<_ProductPickerSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final rows = (ref.watch(productsProvider(_q)).value ?? const <Product>[])
        .where((p) => p.isActive)
        .toList();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search), hintText: l.searchProducts),
                onChanged: (v) => setState(() => _q = v),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: rows.length,
                itemBuilder: (_, i) => ListTile(
                  title: Text(rows[i].name),
                  subtitle: Text(Money(rows[i].defaultSellPrice).format()),
                  onTap: () => Navigator.pop(context, rows[i]),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
