import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/features/products/application/product_repository.dart';
import 'package:parcel_khata/features/settings/application/settings_repository.dart';
import 'package:parcel_khata/l10n/l10n.dart';
import 'package:parcel_khata/shared/form_helpers.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

class _VarCtl {
  _VarCtl({this.id, String label = '', String sell = '', String cost = ''})
      : label = TextEditingController(text: label),
        sell = TextEditingController(text: sell),
        cost = TextEditingController(text: cost);

  final String? id;
  final TextEditingController label;
  final TextEditingController sell;
  final TextEditingController cost;

  void dispose() {
    label.dispose();
    sell.dispose();
    cost.dispose();
  }
}

class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({this.productId, super.key});

  final String? productId;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _sku = TextEditingController();
  final _sell = TextEditingController();
  final _cost = TextEditingController();
  final _stock = TextEditingController();
  final List<_VarCtl> _vars = [];
  bool _active = true;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (widget.productId == null) {
      _loaded = true;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    final repo = ref.read(productRepositoryProvider);
    final p = await repo.getById(widget.productId!);
    final vs = await repo.variants(widget.productId!);
    if (!mounted || p == null) return;
    String fmt(int? v) => v == null ? '' : Money(v).format(symbol: false, decimals: v % 100 != 0);
    setState(() {
      _name.text = p.name;
      _sku.text = p.sku ?? '';
      _sell.text = fmt(p.defaultSellPrice);
      _cost.text = fmt(p.defaultCostPrice);
      _stock.text = p.stockQty?.toString() ?? '';
      _active = p.isActive;
      for (final v in vs) {
        _vars.add(_VarCtl(
            id: v.id, label: v.label, sell: fmt(v.sellPrice), cost: fmt(v.costPrice)));
      }
      _loaded = true;
    });
  }

  @override
  void dispose() {
    for (final c in [_name, _sku, _sell, _cost, _stock]) {
      c.dispose();
    }
    for (final v in _vars) {
      v.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final input = ProductInput(
      name: _name.text,
      sku: _sku.text,
      sellPrice: parseMoneyOrNull(_sell.text) ?? Money.zero,
      costPrice: parseMoneyOrNull(_cost.text),
      stockQty: parseIntOrNull(_stock.text),
      isActive: _active,
      variants: [
        for (final v in _vars)
          VariantInput(
            id: v.id,
            label: v.label.text,
            sellPrice: parseMoneyOrNull(v.sell.text),
            costPrice: parseMoneyOrNull(v.cost.text),
          ),
      ],
    );
    final repo = ref.read(productRepositoryProvider);
    final r = widget.productId == null
        ? await repo.create(input)
        : await repo.update(widget.productId!, input);
    if (!mounted) return;
    r.when(
      ok: (_) => context.pop(),
      err: (f) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(f.message))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final stockEnabled =
        ref.watch(shopSettingsProvider).value?.stockTrackingEnabled ?? false;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.productId == null ? l.productNew : l.productEdit),
        actions: [TextButton(onPressed: _loaded ? _save : null, child: Text(l.save))],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _form,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                TextFormField(
                  controller: _name,
                  decoration: InputDecoration(labelText: l.fieldName),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? l.errNameRequired : null,
                ),
                gap(),
                TextFormField(
                    controller: _sku, decoration: InputDecoration(labelText: l.sku)),
                gap(),
                MoneyFormField(controller: _sell, label: l.sellPrice, required: true),
                gap(),
                MoneyFormField(controller: _cost, label: l.costPrice),
                if (stockEnabled) ...[
                  gap(),
                  TextFormField(
                    controller: _stock,
                    decoration: InputDecoration(labelText: l.stockQty),
                    keyboardType: TextInputType.number,
                  ),
                ],
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.activeLabel),
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                ),
                gap(8),
                Text(l.variants, style: Theme.of(context).textTheme.titleMedium),
                for (var i = 0; i < _vars.length; i++)
                  Card(
                    margin: const EdgeInsets.only(top: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(children: [
                        Row(children: [
                          Expanded(
                            child: TextFormField(
                              controller: _vars[i].label,
                              decoration: InputDecoration(labelText: l.variantLabel),
                            ),
                          ),
                          IconButton(
                            tooltip: l.remove,
                            icon: const Icon(LucideIcons300.trash2),
                            onPressed: () => setState(() => _vars.removeAt(i).dispose()),
                          ),
                        ]),
                        gap(8),
                        Row(children: [
                          Expanded(
                              child: MoneyFormField(
                                  controller: _vars[i].sell, label: l.sellPrice)),
                          const SizedBox(width: 8),
                          Expanded(
                              child: MoneyFormField(
                                  controller: _vars[i].cost, label: l.costPrice)),
                        ]),
                      ]),
                    ),
                  ),
                gap(),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _vars.add(_VarCtl())),
                  icon: const Icon(LucideIcons300.plus),
                  label: Text(l.addVariant),
                ),
                gap(80),
              ]),
            ),
    );
  }
}
