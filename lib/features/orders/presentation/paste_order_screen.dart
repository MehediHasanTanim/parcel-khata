import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:parcel_khata/core/db/app_database.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/features/customers/application/customer_repository.dart';
import 'package:parcel_khata/features/customers/domain/phone_normalizer.dart';
import 'package:parcel_khata/features/orders/application/order_prefill.dart';
import 'package:parcel_khata/features/orders/domain/paste_parser.dart';
import 'package:parcel_khata/features/products/application/product_repository.dart';
import 'package:parcel_khata/features/telemetry/application/telemetry_providers.dart';
import 'package:parcel_khata/l10n/l10n.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

class _LineDraft {
  _LineDraft({
    required this.mention,
    required this.qty,
    required this.product,
    required this.confidence,
    required this.ambiguous,
    String price = '',
  }) : price = TextEditingController(text: price);

  final String mention;
  int qty;
  CatalogProduct? product;
  Confidence confidence;
  final bool ambiguous;
  final TextEditingController price;
}

/// Paste a customer's chat message, review what was understood, then open
/// the normal order form pre-filled. Nothing is saved from here.
class PasteOrderScreen extends ConsumerStatefulWidget {
  const PasteOrderScreen({this.initialText = '', super.key});

  final String initialText;

  @override
  ConsumerState<PasteOrderScreen> createState() => _PasteOrderScreenState();
}

class _PasteOrderScreenState extends ConsumerState<PasteOrderScreen> {
  late final TextEditingController _text = TextEditingController(text: widget.initialText);
  final _phone = TextEditingController();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final List<_LineDraft> _lines = [];
  List<Product> _products = const [];
  ParsedOrderDraft? _draft;
  Customer? _existing;
  bool _useDelivery = true;
  bool _useAdvance = true;
  bool _busy = false;
  final Stopwatch _watch = Stopwatch()..start();

  @override
  void initState() {
    super.initState();
    if (widget.initialText.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _parse());
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _phone.dispose();
    _name.dispose();
    _address.dispose();
    for (final l in _lines) {
      l.price.dispose();
    }
    super.dispose();
  }

  CatalogProduct _cat(Product p) => CatalogProduct(
        id: p.id,
        name: p.name,
        sellPrice: Money(p.defaultSellPrice),
        costPrice: p.defaultCostPrice == null ? null : Money(p.defaultCostPrice!),
      );

  Future<void> _paste() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    if (d?.text == null) return;
    setState(() => _text.text = d!.text!);
    await _parse();
  }

  Future<void> _parse() async {
    setState(() => _busy = true);
    final products = await ref.read(productRepositoryProvider).watchAll(includeInactive: false).first;
    final draft = PasteParser.parse(_text.text, catalog: [for (final p in products) _cat(p)]);
    if (!mounted) return;
    for (final l in _lines) {
      l.price.dispose();
    }
    _lines.clear();
    for (final l in draft.lines) {
      final price = l.priceHint ?? l.product?.sellPrice;
      _lines.add(_LineDraft(
        mention: l.mention,
        qty: l.qty,
        product: l.product,
        confidence: l.confidence,
        ambiguous: l.ambiguousWith.isNotEmpty,
        price: price == null ? '' : price.format(symbol: false, decimals: price.poisha % 100 != 0),
      ));
    }
    _phone.text = draft.phone?.value ?? '';
    _name.text = draft.name?.value ?? '';
    _address.text = draft.address?.value ?? '';
    _products = products;
    _draft = draft;
    await _lookup();
    ref.read(telemetryProvider).event('paste_parsed', {
      'phone': draft.phone != null,
      'name': draft.name != null,
      'address': draft.address != null,
      'lines': draft.lines.length,
      'matched': draft.lines.where((l) => l.product != null).length,
    });
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _lookup() async {
    final p = PhoneNormalizer.normalize(_phone.text);
    final c = p == null ? null : await ref.read(customerRepositoryProvider).findByPhone(p);
    if (mounted) setState(() => _existing = c);
  }

  Future<void> _create() async {
    final phone = PhoneNormalizer.normalize(_phone.text);
    String? customerId = _existing?.id;
    if (customerId == null && phone != null) {
      // New person: the normal customer form (duplicate check included).
      customerId = await context.push<String>(
        '/customers/new',
        extra: CustomerPrefill(name: _name.text.trim(), phone: phone, address: _address.text.trim()),
      );
      if (customerId == null || !mounted) return;
    }
    final d = _draft;
    final prefill = OrderPrefill(
      customerId: customerId,
      address: _address.text.trim(),
      lines: [
        for (final l in _lines)
          PrefillLine(
            name: l.product?.name ?? l.mention,
            qty: l.qty,
            sell: Money.tryParse(l.price.text.trim()),
            cost: l.product?.costPrice,
            productId: l.product?.id,
          ),
      ],
      deliveryCharge: _useDelivery ? d?.deliveryHint : null,
      advance: _useAdvance ? d?.advanceHint : null,
    );
    ref.read(telemetryProvider).event('paste_to_form', {'ms': _watch.elapsedMilliseconds});
    if (mounted) context.pushReplacement('/orders/new', extra: prefill);
  }

  Color _tone(BuildContext c, Confidence k) => switch (k) {
        Confidence.high => const Color(0xFF1B7F3B),
        Confidence.medium => const Color(0xFFB26A00),
        Confidence.low => Theme.of(c).colorScheme.error,
      };

  InputDecoration _deco(BuildContext c, String label, Confidence? k) => InputDecoration(
        labelText: label,
        enabledBorder: k == null
            ? null
            : OutlineInputBorder(borderSide: BorderSide(color: _tone(c, k), width: 1.5)),
        suffixIcon: k == null
            ? null
            : Icon(k == Confidence.high ? LucideIcons300.circleCheck : LucideIcons300.circleHelp,
                color: _tone(c, k)),
      );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final d = _draft;
    return Scaffold(
      appBar: AppBar(title: Text(l.pasteTitle)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(
          controller: _text,
          minLines: 4,
          maxLines: 10,
          decoration: InputDecoration(hintText: l.pasteHint, border: const OutlineInputBorder()),
        ),
        const SizedBox(height: 8),
        Row(children: [
          OutlinedButton.icon(
            onPressed: _paste,
            icon: const Icon(LucideIcons300.clipboardPaste),
            label: Text(l.pasteFromClipboard),
          ),
          const SizedBox(width: 8),
          FilledButton(onPressed: _busy ? null : _parse, child: Text(l.pasteParse)),
        ]),
        if (_busy) const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
        if (d != null) ...[
          const SizedBox(height: 16),
          if (d.isEmpty)
            Text(l.pasteNothing)
          else
            Text(l.pasteReview, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: _deco(context, l.fieldPhone, d.phone?.confidence),
            onChanged: (_) => _lookup(),
          ),
          if (_existing != null)
            Card(
              child: ListTile(
                leading: const Icon(LucideIcons300.user),
                title: Text('${l.pasteExisting}: ${_existing!.name}'),
                subtitle: Text(l.pasteExistingNote +
                    (_name.text.trim().isNotEmpty && _name.text.trim() != _existing!.name
                        ? '\n${l.pasteNameDiffers}: ${_name.text.trim()}'
                        : '')),
              ),
            )
          else if (PhoneNormalizer.normalize(_phone.text) != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(l.pasteNewCustomer, style: Theme.of(context).textTheme.bodySmall),
            ),
          const SizedBox(height: 12),
          if (_existing == null)
            TextField(
              controller: _name,
              decoration: _deco(context, l.fieldName, d.name?.confidence),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _address,
            maxLines: 3,
            decoration: _deco(context, l.deliveryAddress, d.address?.confidence),
          ),
          const SizedBox(height: 16),
          Text(l.pasteLines, style: Theme.of(context).textTheme.titleMedium),
          for (var i = 0; i < _lines.length; i++) _lineCard(l, i),
          if (d.totalHint != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('${l.pasteTotalHint} ${d.totalHint!.format()}',
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          if (d.deliveryHint != null)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${l.pasteUseDelivery} (${d.deliveryHint!.format()})'),
              value: _useDelivery,
              onChanged: (v) => setState(() => _useDelivery = v),
            ),
          if (d.advanceHint != null)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${l.pasteUseAdvance} (${d.advanceHint!.format()})'),
              value: _useAdvance,
              onChanged: (v) => setState(() => _useAdvance = v),
            ),
          if (d.altPhones.isNotEmpty || d.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(l.pasteMoreNumbers, style: Theme.of(context).textTheme.labelLarge),
            for (final p in d.altPhones) Text(p),
            for (final n in d.notes) Text(n, style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 16),
          FilledButton(onPressed: _create, child: Text(l.pasteCreate)),
        ],
      ]),
    );
  }

  Widget _lineCard(AppLocalizations l, int i) {
    final line = _lines[i];
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: _tone(context, line.confidence), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(line.mention, style: Theme.of(context).textTheme.titleSmall),
          if (line.ambiguous)
            Text(l.pasteAmbiguous, style: TextStyle(color: _tone(context, Confidence.medium))),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
 icon: const Icon(LucideIcons300.chevronDown),
            initialValue: line.product?.id,
            isExpanded: true,
            decoration: InputDecoration(labelText: l.pasteMatch, isDense: true),
            items: [
              DropdownMenuItem<String?>(child: Text(l.pasteNoMatch)),
              for (final p in _products) DropdownMenuItem<String?>(value: p.id, child: Text(p.name)),
            ],
            onChanged: (v) => setState(() {
              final p = _products.where((x) => x.id == v).firstOrNull;
              line.product = p == null ? null : _cat(p);
              line.confidence = p == null ? Confidence.low : Confidence.high;
              if (p != null && line.price.text.trim().isEmpty) {
                line.price.text = Money(p.defaultSellPrice)
                    .format(symbol: false, decimals: p.defaultSellPrice % 100 != 0);
              }
            }),
          ),
          const SizedBox(height: 8),
          Row(children: [
            IconButton(
              icon: const Icon(LucideIcons300.circleMinus),
              onPressed: line.qty > 1 ? () => setState(() => line.qty--) : null,
            ),
            Text('${l.pasteQty}: ${line.qty}'),
            IconButton(
              icon: const Icon(LucideIcons300.circlePlus),
              onPressed: () => setState(() => line.qty++),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: line.price,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText: l.exchangeSell, prefixText: '৳ ', isDense: true),
              ),
            ),
            IconButton(
              tooltip: l.remove,
              icon: const Icon(LucideIcons300.trash2),
              onPressed: () => setState(() => _lines.removeAt(i).price.dispose()),
            ),
          ]),
        ]),
      ),
    );
  }
}
