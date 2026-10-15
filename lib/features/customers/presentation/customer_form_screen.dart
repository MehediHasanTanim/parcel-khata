import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:parcel_khata/core/result/result.dart';
import 'package:parcel_khata/features/customers/application/customer_repository.dart';
import 'package:parcel_khata/features/customers/domain/phone_normalizer.dart';
import 'package:parcel_khata/l10n/l10n.dart';
import 'package:parcel_khata/shared/form_helpers.dart';

class _AddrCtl {
  _AddrCtl({String label = '', String text = '', String district = '', String area = '', this.isDefault = false, this.id})
      : label = TextEditingController(text: label),
        text = TextEditingController(text: text),
        district = TextEditingController(text: district),
        area = TextEditingController(text: area);

  final String? id;
  final TextEditingController label;
  final TextEditingController text;
  final TextEditingController district;
  final TextEditingController area;
  bool isDefault;

  void dispose() {
    label.dispose();
    text.dispose();
    district.dispose();
    area.dispose();
  }
}

/// Create (customerId == null) or edit a customer and their address book.
class CustomerFormScreen extends ConsumerStatefulWidget {
  const CustomerFormScreen({this.customerId, super.key});

  final String? customerId;

  @override
  ConsumerState<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends ConsumerState<CustomerFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _alt = TextEditingController();
  final _wa = TextEditingController();
  final _notes = TextEditingController();
  final List<_AddrCtl> _addrs = [];
  String? _duplicateId;
  String? _duplicateName;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (widget.customerId == null) {
      _addrs.add(_AddrCtl(isDefault: true));
      _loaded = true;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    final repo = ref.read(customerRepositoryProvider);
    final c = await repo.getById(widget.customerId!);
    final a = await repo.addresses(widget.customerId!);
    if (!mounted || c == null) return;
    setState(() {
      _name.text = c.name;
      _phone.text = c.phonePrimary;
      _alt.text = c.phoneAlt ?? '';
      _wa.text = c.whatsapp ?? '';
      _notes.text = c.notes ?? '';
      for (final x in a) {
        _addrs.add(_AddrCtl(
            id: x.id,
            label: x.label,
            text: x.fullText,
            district: x.district ?? '',
            area: x.area ?? '',
            isDefault: x.isDefault));
      }
      _loaded = true;
    });
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _alt, _wa, _notes]) {
      c.dispose();
    }
    for (final a in _addrs) {
      a.dispose();
    }
    super.dispose();
  }

  Future<void> _checkDuplicate() async {
    final p = _phone.text.trim();
    if (PhoneNormalizer.normalize(p) == null) {
      setState(() => _duplicateId = null);
      return;
    }
    final existing = await ref.read(customerRepositoryProvider).findByPhone(p);
    if (!mounted) return;
    setState(() {
      final dup = existing != null && existing.id != widget.customerId;
      _duplicateId = dup ? existing.id : null;
      _duplicateName = dup ? existing.name : null;
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final input = CustomerInput(
      name: _name.text,
      phone: _phone.text,
      phoneAlt: _alt.text,
      whatsapp: _wa.text,
      notes: _notes.text,
      addresses: [
        for (final a in _addrs)
          AddressInput(
            id: a.id,
            label: a.label.text,
            fullText: a.text.text,
            district: a.district.text,
            area: a.area.text,
            isDefault: a.isDefault,
          ),
      ],
    );
    final repo = ref.read(customerRepositoryProvider);
    final result = widget.customerId == null
        ? await repo.create(input)
        : await repo.update(widget.customerId!, input);
    if (!mounted) return;
    result.when(
      ok: (c) => context.pop(c.id),
      err: (f) {
        if (f is ConflictFailure) {
          setState(() {
            _duplicateId = f.conflictingId;
            _duplicateName = null;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(f.message)));
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final editing = widget.customerId != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? l.customerEdit : l.customerNew),
        actions: [TextButton(onPressed: _loaded ? _save : null, child: Text(l.save))],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _form,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                if (_duplicateId != null)
                  MaterialBanner(
                    content: Text(_duplicateName == null
                        ? l.duplicatePhone
                        : '${l.duplicatePhone}: $_duplicateName'),
                    leading: const Icon(Icons.warning_amber),
                    actions: [
                      TextButton(
                        onPressed: () => context.pushReplacement('/customers/$_duplicateId'),
                        child: Text(l.useExisting),
                      ),
                    ],
                  ),
                TextFormField(
                  controller: _name,
                  decoration: InputDecoration(labelText: l.fieldName),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? l.errNameRequired : null,
                ),
                gap(),
                TextFormField(
                  controller: _phone,
                  decoration: InputDecoration(labelText: l.fieldPhone),
                  keyboardType: TextInputType.phone,
                  onChanged: (_) => _checkDuplicate(),
                  validator: (v) => PhoneNormalizer.normalize(v ?? '') == null
                      ? l.errInvalidPhone
                      : null,
                ),
                gap(),
                TextFormField(
                  controller: _alt,
                  decoration: InputDecoration(labelText: l.fieldPhoneAlt),
                  keyboardType: TextInputType.phone,
                ),
                gap(),
                TextFormField(
                  controller: _wa,
                  decoration: InputDecoration(labelText: l.fieldWhatsapp),
                  keyboardType: TextInputType.phone,
                ),
                gap(),
                TextFormField(
                  controller: _notes,
                  decoration: InputDecoration(labelText: l.fieldNotes),
                  maxLines: 2,
                ),
                gap(20),
                Text(l.addresses, style: Theme.of(context).textTheme.titleMedium),
                for (var i = 0; i < _addrs.length; i++) _addressCard(l, i),
                gap(),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _addrs.add(_AddrCtl(isDefault: _addrs.isEmpty))),
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: Text(l.addAddress),
                ),
                gap(80),
              ]),
            ),
    );
  }

  Widget _addressCard(AppLocalizations l, int i) {
    final a = _addrs[i];
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: a.label,
                decoration: InputDecoration(labelText: l.addressLabel),
              ),
            ),
            IconButton(
              tooltip: l.remove,
              icon: const Icon(Icons.delete_outline),
              onPressed: () => setState(() => _addrs.removeAt(i).dispose()),
            ),
          ]),
          gap(8),
          TextFormField(
            controller: a.text,
            decoration: InputDecoration(labelText: l.addressText),
            maxLines: 2,
          ),
          gap(8),
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: a.district,
                decoration: InputDecoration(labelText: l.district),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: a.area,
                decoration: InputDecoration(labelText: l.area),
              ),
            ),
          ]),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.defaultAddress),
            value: a.isDefault,
            onChanged: (v) => setState(() {
              for (final x in _addrs) {
                x.isDefault = false;
              }
              a.isDefault = v;
            }),
          ),
        ]),
      ),
    );
  }
}
