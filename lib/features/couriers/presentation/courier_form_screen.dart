import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/features/couriers/application/courier_repository.dart';
import 'package:parcel_khata/features/couriers/domain/charge_calculator.dart';
import 'package:parcel_khata/features/couriers/domain/tracking_url.dart';
import 'package:parcel_khata/l10n/l10n.dart';
import 'package:parcel_khata/shared/form_helpers.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

class _RuleCtl {
  _RuleCtl({this.zone = 'inside_dhaka', String fee = '', String min = '0', String max = ''})
      : fee = TextEditingController(text: fee),
        min = TextEditingController(text: min),
        max = TextEditingController(text: max);

  String zone;
  final TextEditingController fee;
  final TextEditingController min;
  final TextEditingController max;

  void dispose() {
    fee.dispose();
    min.dispose();
    max.dispose();
  }
}

String _fmt(int v, {bool decimals = true}) =>
    Money(v).format(symbol: false, decimals: decimals);

class CourierFormScreen extends ConsumerStatefulWidget {
  const CourierFormScreen({this.courierId, super.key});

  final String? courierId;

  @override
  ConsumerState<CourierFormScreen> createState() => _CourierFormScreenState();
}

class _CourierFormScreenState extends ConsumerState<CourierFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _tracking = TextEditingController();
  final _cycle = TextEditingController(text: '3');
  final _stuck = TextEditingController(text: '3');
  final _regex = TextEditingController();
  final _codPct = TextEditingController();
  final _codFlat = TextEditingController();
  final _codFree = TextEditingController();
  final _returnValue = TextEditingController();
  ReturnFeeMode _returnMode = ReturnFeeMode.none;
  final List<_RuleCtl> _rules = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (widget.courierId == null) {
      _loaded = true;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    final repo = ref.read(courierRepositoryProvider);
    final c = await repo.getById(widget.courierId!);
    final rs = await repo.rateRules(widget.courierId!);
    if (!mounted || c == null) return;
    setState(() {
      _name.text = c.name;
      _phone.text = c.phone ?? '';
      _tracking.text = c.trackingUrlTemplate ?? '';
      _cycle.text = '${c.payoutCycleDays}';
      _stuck.text = '${c.stuckDays}';
      _regex.text = c.cnRegex ?? '';
      _codPct.text = c.codFeePercentBp == 0 ? '' : _fmt(c.codFeePercentBp);
      _codFlat.text = c.codFeeFlat == 0 ? '' : _fmt(c.codFeeFlat);
      _codFree.text = c.codFeeFreeUnder == null ? '' : _fmt(c.codFeeFreeUnder!);
      _returnMode = ReturnFeeMode.fromDb(c.returnFeeMode);
      _returnValue.text = c.returnFeeValue == 0 ? '' : _fmt(c.returnFeeValue);
      for (final r in rs) {
        _rules.add(_RuleCtl(
            zone: r.zone,
            fee: _fmt(r.fee),
            min: '${r.weightMinG}',
            max: r.weightMaxG?.toString() ?? ''));
      }
      _loaded = true;
    });
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _tracking, _cycle, _stuck, _regex, _codPct,
        _codFlat, _codFree, _returnValue]) {
      c.dispose();
    }
    for (final r in _rules) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final input = CourierInput(
      name: _name.text,
      phone: _phone.text,
      trackingUrlTemplate: _tracking.text,
      payoutCycleDays: parseIntOrNull(_cycle.text) ?? 3,
      stuckDays: parseIntOrNull(_stuck.text) ?? 3,
      cnRegex: _regex.text,
      // Percent entered as "1.5" == 150 basis points == Money(150).poisha.
      codFeePercentBp: parseMoneyOrNull(_codPct.text)?.poisha ?? 0,
      codFeeFlat: parseMoneyOrNull(_codFlat.text) ?? Money.zero,
      codFeeFreeUnder: parseMoneyOrNull(_codFree.text),
      returnFeeMode: _returnMode,
      returnFeeValue: _returnMode == ReturnFeeMode.none
          ? 0
          : (parseMoneyOrNull(_returnValue.text)?.poisha ?? 0),
      rateRules: [
        for (final r in _rules)
          RateRuleInput(
            zone: r.zone,
            fee: parseMoneyOrNull(r.fee.text) ?? Money.zero,
            weightMinG: parseIntOrNull(r.min.text) ?? 0,
            weightMaxG: parseIntOrNull(r.max.text),
          ),
      ],
    );
    final repo = ref.read(courierRepositoryProvider);
    final r = widget.courierId == null
        ? await repo.create(input)
        : await repo.update(widget.courierId!, input);
    if (!mounted) return;
    r.when(
      ok: (_) => context.pop(),
      err: (f) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(f.message))),
    );
  }

  String _zoneLabel(AppLocalizations l, String z) => switch (z) {
        'inside_dhaka' => l.zoneInsideDhaka,
        'dhaka_suburb' => l.zoneDhakaSuburb,
        'outside_dhaka' => l.zoneOutsideDhaka,
        _ => l.zoneCustom,
      };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final preview = TrackingUrl.build(_tracking.text, 'CN12345');
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.courierId == null ? l.courierNew : l.courierEdit),
        actions: [TextButton(onPressed: _loaded ? _save : null, child: Text(l.save))],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _form,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                if (widget.courierId == null) ...[
                  Text(l.quickAdd, style: Theme.of(context).textTheme.labelLarge),
                  gap(8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final p in kCourierPresets)
                      ActionChip(
                        label: Text(p.name),
                        onPressed: () => setState(() {
                          _name.text = p.name;
                          _tracking.text = p.tracking ?? '';
                        }),
                      ),
                  ]),
                  gap(16),
                ],
                TextFormField(
                  controller: _name,
                  decoration: InputDecoration(labelText: l.fieldName),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? l.errNameRequired : null,
                ),
                gap(),
                TextFormField(
                  controller: _phone,
                  decoration: InputDecoration(labelText: l.fieldPhone),
                  keyboardType: TextInputType.phone,
                ),
                gap(),
                TextFormField(
                  controller: _tracking,
                  decoration: InputDecoration(labelText: l.trackingTemplate),
                  keyboardType: TextInputType.url,
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    final t = v?.trim() ?? '';
                    return t.isEmpty || TrackingUrl.isValidTemplate(t)
                        ? null
                        : l.errTrackingTemplate;
                  },
                ),
                if (preview != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('${l.trackingPreview}: $preview',
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
                gap(),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cycle,
                      decoration: InputDecoration(labelText: l.payoutCycleDays),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _stuck,
                      decoration: InputDecoration(labelText: l.stuckDays),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ]),
                gap(),
                TextFormField(
                  controller: _regex,
                  decoration: InputDecoration(labelText: l.cnPattern),
                ),
                gap(20),
                Text(l.codFeePercent, style: Theme.of(context).textTheme.titleMedium),
                gap(8),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _codPct,
                      decoration: InputDecoration(labelText: l.codFeePercent, suffixText: '%'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: MoneyFormField(controller: _codFlat, label: l.codFeeFlat)),
                ]),
                gap(),
                MoneyFormField(controller: _codFree, label: l.codFeeFreeUnder),
                gap(20),
                Text(l.returnFee, style: Theme.of(context).textTheme.titleMedium),
                gap(8),
                SegmentedButton<ReturnFeeMode>(
                  segments: [
                    ButtonSegment(value: ReturnFeeMode.none, label: Text(l.returnNone)),
                    ButtonSegment(value: ReturnFeeMode.flat, label: Text(l.returnFlat)),
                    ButtonSegment(
                        value: ReturnFeeMode.percentOfDelivery, label: Text(l.returnPercent)),
                  ],
                  selected: {_returnMode},
                  onSelectionChanged: (s) => setState(() => _returnMode = s.first),
                ),
                if (_returnMode != ReturnFeeMode.none) ...[
                  gap(),
                  TextFormField(
                    controller: _returnValue,
                    decoration: InputDecoration(
                        labelText: l.returnValue,
                        suffixText: _returnMode == ReturnFeeMode.percentOfDelivery ? '%' : '৳'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ],
                gap(20),
                Text(l.rateCard, style: Theme.of(context).textTheme.titleMedium),
                for (var i = 0; i < _rules.length; i++) _ruleCard(l, i),
                gap(),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _rules.add(_RuleCtl())),
                  icon: const Icon(LucideIcons300.plus),
                  label: Text(l.addRule),
                ),
                gap(80),
              ]),
            ),
    );
  }

  Widget _ruleCard(AppLocalizations l, int i) {
    final r = _rules[i];
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
 icon: const Icon(LucideIcons300.chevronDown),
 isExpanded: true,
                initialValue: r.zone,
                decoration: InputDecoration(labelText: l.zone),
                items: [
                  for (final z in kZones)
                    DropdownMenuItem(value: z, child: Text(_zoneLabel(l, z))),
                ],
                onChanged: (v) => setState(() => r.zone = v ?? r.zone),
              ),
            ),
            IconButton(
              tooltip: l.remove,
              icon: const Icon(LucideIcons300.trash2),
              onPressed: () => setState(() => _rules.removeAt(i).dispose()),
            ),
          ]),
          gap(8),
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: r.min,
                decoration: InputDecoration(labelText: l.weightMinG),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: r.max,
                decoration: InputDecoration(labelText: l.weightMaxG),
                keyboardType: TextInputType.number,
              ),
            ),
          ]),
          gap(8),
          MoneyFormField(controller: r.fee, label: l.fee, required: true),
        ]),
      ),
    );
  }
}
