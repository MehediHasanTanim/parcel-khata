import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:parcel_khata/core/db/app_database.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/features/backup/domain/csv.dart';
import 'package:parcel_khata/features/backup/domain/xlsx_reader.dart';
import 'package:parcel_khata/features/cod/application/statement_import_service.dart';
import 'package:parcel_khata/features/cod/domain/payout_reconciler.dart';
import 'package:parcel_khata/features/cod/domain/statement_import.dart' as dom;
import 'package:parcel_khata/features/cod/domain/statement_parser.dart';
import 'package:parcel_khata/features/couriers/application/courier_repository.dart';
import 'package:parcel_khata/features/export/application/pdf_documents.dart' as pdf;
import 'package:parcel_khata/features/export/application/pdf_theme.dart';
import 'package:parcel_khata/features/orders/presentation/order_labels.dart';
import 'package:parcel_khata/features/settings/application/settings_repository.dart';
import 'package:parcel_khata/l10n/l10n.dart';
import 'package:printing/printing.dart';

/// Courier statement import: file -> profile -> review -> confirm.
/// Nothing is written until the final confirm (one transaction).
class StatementImportScreen extends ConsumerStatefulWidget {
  const StatementImportScreen({this.courierId, super.key});

  final String? courierId;

  @override
  ConsumerState<StatementImportScreen> createState() => _StatementImportScreenState();
}

class _StatementImportScreenState extends ConsumerState<StatementImportScreen> {
  String? _courierId;
  String _fileName = '';
  String _hash = '';
  List<List<String>> _table = const [];

  late StatementProfile _profile = kStatementPresets.first;
  String? _profileId;

  StatementParseResult? _parsed;
  List<dom.MatchedRow> _matches = const [];
  final Set<int> _included = {};
  final Set<int> _adjusted = {};
  final _reason = TextEditingController();
  final _reference = TextEditingController();
  dom.StatementOutcome? _filter;
  ShortfallPolicy? _policy;
  bool _allowOver = false;
  StatementImportLog? _already;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _courierId = widget.courierId;
  }

  @override
  void dispose() {
    _reason.dispose();
    _reference.dispose();
    super.dispose();
  }

  StatementImportService get _svc => ref.read(statementImportServiceProvider);

  Future<void> _pick() async {
    final r = await FilePicker.pickFiles();
    if (r.isEmpty || r.first.path == null) return;
    final path = r.first.path!;
    final bytes = await File(path).readAsBytes();
    final rows = path.toLowerCase().endsWith('.xlsx')
        ? XlsxReader.read(bytes)
        : Csv.parse(utf8.decode(bytes, allowMalformed: true));
    if (!mounted) return;
    setState(() {
      _table = rows;
      _hash = StatementImportService.contentHash(bytes);
      _fileName = path.split(Platform.pathSeparator).last;
    });
    await _review();
  }

  Future<void> _review() async {
    final courierId = _courierId;
    if (courierId == null || _table.isEmpty) return;
    setState(() => _busy = true);
    final parsed = StatementParser.parse(_table, _profile);
    final orders = await _svc.loadOrders(courierId);
    final matches = dom.StatementMatcher.match(
      parsed.rows,
      orders,
      tolerance: Money.taka(_profile.toleranceTaka),
    );
    final already = await _svc.findApplied(courierId, _hash);
    if (!mounted) return;
    setState(() {
      _parsed = parsed;
      _matches = matches;
      _already = already;
      _included
        ..clear()
        ..addAll([
          for (var i = 0; i < matches.length; i++)
            if (matches[i].outcome == dom.StatementOutcome.matched) i,
        ]);
      _adjusted.clear();
      _error = null;
      _busy = false;
    });
  }

  List<dom.StatementDecision> get _decisions => [
        for (var i = 0; i < _matches.length; i++)
          if (_included.contains(i))
            dom.StatementDecision(
              _matches[i],
              adjustCollected: _adjusted.contains(i),
              reason: _reason.text,
            ),
      ];

  dom.StatementPlanResult get _planResult =>
      dom.StatementPlanBuilder.build(_decisions, policy: _policy, allowOverpayment: _allowOver);

  Future<void> _apply() async {
    final l = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await _svc.apply(
      courierId: _courierId!,
      decisions: _decisions,
      contentHash: _hash,
      rowCount: _matches.length,
      fileName: _fileName,
      policy: _policy,
      allowOverpayment: _allowOver,
      reference: _reference.text,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.isOk) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.stmtApplied)));
      context.pop();
      return;
    }
    final f = r.failureOrNull;
    setState(() {
      _error = switch (f) {
        StatementApplyFailure(:final error, :final reconcileError) => switch (error) {
            dom.StatementPlanError.reasonRequired => l.stmtErrReason,
            dom.StatementPlanError.ineligibleRow => l.stmtErrIneligible,
            dom.StatementPlanError.nothingSelected => l.stmtErrNothing,
            dom.StatementPlanError.reconcile => switch (reconcileError) {
                ReconcileError.shortfallNeedsPolicy => l.errShortfallPolicy,
                ReconcileError.exceedsOutstanding => l.errExceedsOutstanding,
                _ => l.errAllocationMismatch,
              },
          },
        _ => l.stmtAlreadyApplied,
      };
    });
  }

  Future<void> _disputePdf() async {
    final l = context.l10n;
    final mism = [
      for (final m in _matches)
        if (m.outcome == dom.StatementOutcome.amountMismatch && m.order != null) m,
    ];
    if (mism.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.stmtNoMismatch)));
      return;
    }
    final couriers = ref.read(couriersProvider).value ?? const <Courier>[];
    final name = couriers.where((c) => c.id == _courierId).map((c) => c.name).firstOrNull ?? '';
    final settings = await ref.read(settingsRepositoryProvider).read();
    final bytes = await pdf.PdfDocuments.courierStatement(
      shopName: settings.businessName.isEmpty ? l.appName : settings.businessName,
      courier: name,
      period: _fileName,
      rows: [
        for (final m in mism)
          pdf.StatementRow(
            orderNo: m.order!.orderNo,
            cn: m.row.cnRaw,
            deliveredOn: m.order!.deliveredAt == null ? '' : formatDate(m.order!.deliveredAt!),
            // What the seller recorded vs what the courier's statement says.
            expected: m.order!.collected,
            received: m.row.collected ?? Money.zero,
          ),
      ],
      theme: await loadPdfTheme(),
    );
    await Printing.sharePdf(bytes: bytes, filename: 'statement_dispute_$name.pdf');
  }

  Future<void> _editProfile() async {
    final l = context.l10n;
    final cols = {..._profile.columns};
    final name = TextEditingController(text: _profile.name);
    final tol = TextEditingController(text: '${_profile.toleranceTaka}');
    final ctrls = {
      for (final f in kStatementFields) f: TextEditingController(text: cols[f] ?? ''),
    };
    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.stmtEditMapping),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: name,
                decoration: InputDecoration(labelText: l.stmtProfileName)),
            TextField(
              controller: tol,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l.stmtTolerance),
            ),
            const SizedBox(height: 8),
            Text(l.stmtColumnHint, style: Theme.of(ctx).textTheme.bodySmall),
            for (final f in kStatementFields)
              TextField(controller: ctrls[f], decoration: InputDecoration(labelText: f)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.stmtSaveProfile)),
        ],
      ),
    );
    if (save != true || !mounted) return;
    final edited = StatementProfile(
      name: name.text.trim().isEmpty ? _profile.name : name.text.trim(),
      toleranceTaka: int.tryParse(tol.text.trim()) ?? 0,
      columns: {
        for (final e in ctrls.entries)
          if (e.value.text.trim().isNotEmpty) e.key: e.value.text.trim(),
      },
    );
    final id = await _svc.saveProfile(edited, courierId: _courierId, id: _profileId);
    if (!mounted) return;
    setState(() {
      _profile = edited;
      _profileId = id;
    });
    await _review();
  }

  String _outLabel(AppLocalizations l, dom.StatementOutcome o) => switch (o) {
        dom.StatementOutcome.matched => l.stmtOutMatched,
        dom.StatementOutcome.unknownCn => l.stmtOutUnknown,
        dom.StatementOutcome.duplicateInFile => l.stmtOutDuplicate,
        dom.StatementOutcome.amountMismatch => l.stmtOutMismatch,
        dom.StatementOutcome.alreadySettled => l.stmtOutSettled,
      };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final couriers = ref.watch(couriersProvider).value ?? const <Courier>[];
    final saved = _courierId == null
        ? const <StatementProfileRow>[]
        : (ref.watch(_savedProfilesProvider(_courierId!)).value ??
            const <StatementProfileRow>[]);
    final plan = _matches.isEmpty ? null : _planResult;
    final p = plan?.plan;
    final needsPolicy =
        p != null && p.settlement.error == ReconcileError.shortfallNeedsPolicy;
    final canApply = !_busy &&
        _already == null &&
        p != null &&
        _included.isNotEmpty &&
        (p.settlement.isOk || p.totalReceived.poisha == 0);
    return Scaffold(
      appBar: AppBar(title: Text(l.stmtTitle), actions: [
        if (_matches.any((m) => m.outcome == dom.StatementOutcome.amountMismatch))
          IconButton(
            tooltip: l.stmtDisputePdf,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: _disputePdf,
          ),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        DropdownButtonFormField<String>(
          initialValue: couriers.any((c) => c.id == _courierId) ? _courierId : null,
          decoration: InputDecoration(labelText: l.courier),
          items: [for (final c in couriers) DropdownMenuItem(value: c.id, child: Text(c.name))],
          onChanged: (v) {
            setState(() => _courierId = v);
            _review();
          },
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _profileId ?? 'preset:${_profile.name}',
              isExpanded: true,
              decoration: InputDecoration(labelText: l.stmtProfile),
              items: [
                for (final s in saved)
                  DropdownMenuItem(value: s.id, child: Text(s.profile.name)),
                for (final pr in kStatementPresets)
                  DropdownMenuItem(value: 'preset:${pr.name}', child: Text(pr.name)),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  if (v.startsWith('preset:')) {
                    _profileId = null;
                    _profile = kStatementPresets.firstWhere((x) => 'preset:${x.name}' == v);
                  } else {
                    _profileId = v;
                    _profile = saved.firstWhere((x) => x.id == v).profile;
                  }
                });
                _review();
              },
            ),
          ),
          IconButton(
            tooltip: l.stmtEditMapping,
            icon: const Icon(Icons.tune),
            onPressed: _editProfile,
          ),
        ]),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _courierId == null || _busy ? null : _pick,
          icon: const Icon(Icons.folder_open),
          label: Text(_fileName.isEmpty ? l.stmtPickFile : _fileName),
        ),
        if (_busy) const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
        if (_parsed != null && !_parsed!.hasCnColumn)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(l.stmtNoCn, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        if (_already != null)
          Card(
            margin: const EdgeInsets.only(top: 12),
            child: ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: Text(l.stmtAlreadyApplied),
              subtitle: Text(formatDateTime(_already!.createdAt)),
            ),
          ),
        if (_matches.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            ChoiceChip(
              label: Text('${l.stmtAll} (${_matches.length})'),
              selected: _filter == null,
              onSelected: (_) => setState(() => _filter = null),
            ),
            for (final o in dom.StatementOutcome.values)
              if (_matches.any((m) => m.outcome == o))
                ChoiceChip(
                  label: Text(
                      '${_outLabel(l, o)} (${_matches.where((m) => m.outcome == o).length})'),
                  selected: _filter == o,
                  onSelected: (_) => setState(() => _filter = o),
                ),
          ]),
          const SizedBox(height: 8),
          for (var i = 0; i < _matches.length; i++)
            if (_filter == null || _matches[i].outcome == _filter) _rowTile(l, i),
          if (_adjusted.isNotEmpty)
            TextField(
              controller: _reason,
              decoration: InputDecoration(labelText: l.stmtAdjustReason),
              onChanged: (_) => setState(() {}),
            ),
          const Divider(height: 32),
          if (p != null) ...[
            _kv(l.stmtPayoutTotal, p.totalReceived.format(), bold: true),
            _kv(l.stmtFeesUpdated, '${p.feeUpdates.length}'),
            if (p.totalReceived.poisha == 0 && _included.isNotEmpty)
              Text(l.stmtNothingToPay, style: Theme.of(context).textTheme.bodySmall),
          ],
          if (needsPolicy) ...[
            const SizedBox(height: 8),
            Text(l.shortfallHandling, style: Theme.of(context).textTheme.titleSmall),
            for (final pol in ShortfallPolicy.values)
              RadioListTile<ShortfallPolicy>(
                contentPadding: EdgeInsets.zero,
                value: pol,
                groupValue: _policy,
                title: Text(switch (pol) {
                  ShortfallPolicy.allocate => l.handleAllocate,
                  ShortfallPolicy.dispute => l.handleDispute,
                  ShortfallPolicy.writeOff => l.handleWriteOff,
                }),
                onChanged: (v) => setState(() => _policy = v),
              ),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.allowOverpayment),
            value: _allowOver,
            onChanged: (v) => setState(() => _allowOver = v),
          ),
          TextField(
            controller: _reference,
            decoration: InputDecoration(labelText: l.referenceNo),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          if (_parsed != null && _parsed!.issues.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(l.stmtIssues, style: Theme.of(context).textTheme.titleSmall),
            for (final i in _parsed!.issues.take(10)) Text('#${i.row}: ${i.code}'),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: canApply ? _apply : null,
            child: Text(l.stmtApply),
          ),
        ],
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

  Widget _rowTile(AppLocalizations l, int i) {
    final m = _matches[i];
    final eligible = m.order != null &&
        (m.outcome == dom.StatementOutcome.matched ||
            m.outcome == dom.StatementOutcome.amountMismatch);
    final r = m.row;
    final parts = <String>[
      if (m.order != null) m.order!.orderNo,
      '${l.stmtRecorded}: ${m.order == null ? '—' : m.order!.collected.format()}',
      '${l.stmtStatementSays}: ${r.collected?.format() ?? '—'}',
      if (r.netPayable != null) r.netPayable!.format(),
    ];
    return Card(
      child: Column(children: [
        CheckboxListTile(
          dense: true,
          value: _included.contains(i),
          onChanged: eligible
              ? (v) => setState(() => v == true ? _included.add(i) : _included.remove(i))
              : null,
          title: Text('${r.cnRaw} · ${_outLabel(l, m.outcome)}'),
          subtitle: Text(parts.join(' · ')),
        ),
        if (m.outcome == dom.StatementOutcome.amountMismatch && _included.contains(i))
          SwitchListTile(
            dense: true,
            title: Text(l.stmtAdjust),
            value: _adjusted.contains(i),
            onChanged: (v) => setState(() => v ? _adjusted.add(i) : _adjusted.remove(i)),
          ),
      ]),
    );
  }
}

final _savedProfilesProvider = FutureProvider.autoDispose
    .family<List<StatementProfileRow>, String>(
        (ref, courierId) => ref.watch(statementImportServiceProvider).savedProfiles(courierId));
