import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parcel_khata/features/backup/domain/csv.dart';
import 'package:parcel_khata/core/db/app_database.dart';
import 'package:parcel_khata/features/backup/domain/csv_import.dart';
import 'package:parcel_khata/features/backup/domain/xlsx_reader.dart';
import 'package:parcel_khata/features/export/application/csv_import_service.dart';
import 'package:parcel_khata/l10n/l10n.dart';

enum _Kind { customers, orders, products, openingBalance }

final _batchesProvider = StreamProvider.autoDispose<List<ImportBatch>>(
    (ref) => ref.watch(csvImportServiceProvider).watchBatches());

/// CSV import: pick file -> match columns -> validation preview -> import.
class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  _Kind _kind = _Kind.customers;
  List<List<String>> _rows = const [];
  Map<String, int> _map = {};
  bool _skipBad = false;
  ImportReport? _report;
  bool _busy = false;
  String _fileName = '';
  String _signature = '';
  bool _usedSaved = false;

  String get _kindKey => switch (_kind) {
        _Kind.customers => 'customers',
        _Kind.orders => 'orders',
        _Kind.products => 'products',
        _Kind.openingBalance => 'opening_balance',
      };

  List<String> get _headers => _rows.isEmpty ? const [] : _rows.first;
  List<List<String>> get _data => _rows.length < 2 ? const [] : _rows.sublist(1);

  List<String> get _targets => switch (_kind) {
        _Kind.customers => CsvColumns.customers,
        _Kind.orders => [
            ...CsvColumns.orders,
            'item_name',
            'qty',
            'unit_price',
            'unit_cost',
          ],
        _Kind.products => CsvColumns.products,
        _Kind.openingBalance => CsvColumns.openingBalance,
      };

  Future<void> _pick() async {
    final r = await FilePicker.pickFiles();
    if (r.isEmpty || r.first.path == null) return;
    final path = r.first.path!;
    final List<List<String>> rows;
    if (path.toLowerCase().endsWith('.xlsx')) {
      rows = XlsxReader.read(await File(path).readAsBytes());
    } else {
      rows = Csv.parse(utf8.decode(await File(path).readAsBytes(), allowMalformed: true));
    }
    final sig = rows.isEmpty ? '' : ImportSignature.of(rows.first);
    final saved = rows.isEmpty
        ? null
        : await ref.read(csvImportServiceProvider).loadMapping(sig, _kindKey);
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _report = null;
      _fileName = path.split(Platform.pathSeparator).last;
      _signature = sig;
      _usedSaved = saved != null;
      _map = rows.isEmpty ? {} : (saved ?? autoMapColumns(rows.first, _targets));
    });
  }

  CustomerImportPlan get _customerPlan => CsvImportPlanner.customers(_data, _map);
  OrderImportPlan get _orderPlan => CsvImportPlanner.orders(_data, _map);

  ProductImportPlan get _productPlan => CsvImportPlanner.products(_data, _map);
  OpeningBalancePlan get _balancePlan => CsvImportPlanner.openingBalances(_data, _map);

  int get _valid => switch (_kind) {
        _Kind.customers => _customerPlan.rows.length,
        _Kind.orders => _orderPlan.rows.length,
        _Kind.products => _productPlan.rows.length,
        _Kind.openingBalance => _balancePlan.rows.length,
      };
  int get _bad => switch (_kind) {
        _Kind.customers => _customerPlan.issues.length,
        _Kind.orders => _orderPlan.issues.length,
        _Kind.products => _productPlan.issues.length,
        _Kind.openingBalance => _balancePlan.issues.length,
      };

  Future<void> _run() async {
    setState(() => _busy = true);
    final svc = ref.read(csvImportServiceProvider);
    final r = switch (_kind) {
      _Kind.customers => await svc.importCustomers(_customerPlan,
          skipBadRows: _skipBad, fileName: _fileName),
      _Kind.orders =>
        await svc.importOrders(_orderPlan, skipBadRows: _skipBad, fileName: _fileName),
      _Kind.products => await svc.importProducts(_productPlan,
          skipBadRows: _skipBad, fileName: _fileName),
      _Kind.openingBalance => await svc.importOpeningBalances(_balancePlan,
          skipBadRows: _skipBad, fileName: _fileName),
    };
    if (r.applied && _signature.isNotEmpty) {
      await svc.saveMapping(_signature, _kindKey, _map);
    }
    if (mounted) {
      setState(() {
        _report = r;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.importCsv)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Wrap(spacing: 8, children: [
          for (final k in _Kind.values)
            ChoiceChip(
              label: Text(switch (k) {
                _Kind.customers => l.importCustomers,
                _Kind.orders => l.importOrders,
                _Kind.products => l.importProducts,
                _Kind.openingBalance => l.importOpeningBalance,
              }),
              selected: _kind == k,
              onSelected: (_) => setState(() {
                _kind = k;
                _rows = const [];
                _map = {};
                _report = null;
              }),
            ),
        ]),
        if (_kind == _Kind.openingBalance)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(l.importOpeningHint, style: Theme.of(context).textTheme.bodySmall),
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _pick,
          icon: const Icon(Icons.folder_open),
          label: Text(l.pickFile),
        ),
        if (_rows.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(l.mapColumns, style: Theme.of(context).textTheme.titleSmall),
          if (_usedSaved) Text(l.importSavedMapping, style: Theme.of(context).textTheme.bodySmall),
          for (final t in _targets)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: DropdownButtonFormField<int?>(
                initialValue: _map[t],
                decoration: InputDecoration(labelText: t, isDense: true),
                items: [
                  DropdownMenuItem<int?>(child: Text(l.notMapped)),
                  for (var i = 0; i < _headers.length; i++)
                    DropdownMenuItem<int?>(value: i, child: Text(_headers[i])),
                ],
                onChanged: (v) => setState(() {
                  v == null ? _map.remove(t) : _map[t] = v;
                  _report = null;
                }),
              ),
            ),
          const SizedBox(height: 16),
          Text(l.importPreview, style: Theme.of(context).textTheme.titleSmall),
          Text(l.importValid(_valid)),
          if (_bad > 0)
            Text(l.importErrors(_bad), style: TextStyle(color: Theme.of(context).colorScheme.error)),
          if (_kind == _Kind.customers && _customerPlan.duplicatesInFile.isNotEmpty)
            Text(l.importDuplicates(_customerPlan.duplicatesInFile.length)),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_skipBad ? l.importSkipBad : l.importAllOrNothing),
            value: _skipBad,
            onChanged: (v) => setState(() => _skipBad = v),
          ),
          FilledButton(
            onPressed: _busy || _valid == 0 ? null : _run,
            child: Text(l.importRun),
          ),
        ],
        if (_report != null) ...[
          const SizedBox(height: 16),
          if (_report!.applied)
            Text(l.importDone(_report!.imported), style: Theme.of(context).textTheme.titleMedium)
          else
            Text(l.importErrors(_report!.issues.length)),
          if (_report!.skippedExisting > 0) Text(l.importDuplicates(_report!.skippedExisting)),
          for (final i in _report!.issues.take(20)) Text('#${i.row}: ${i.message}'),
        ],
        const Divider(height: 32),
        Text(l.importHistory, style: Theme.of(context).textTheme.titleMedium),
        _History(onChanged: () => setState(() {})),
      ]),
    );
  }
}

class _History extends ConsumerWidget {
  const _History({required this.onChanged});

  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final batches = ref.watch(_batchesProvider).value ?? const <ImportBatch>[];
    if (batches.isEmpty) return Padding(padding: const EdgeInsets.all(8), child: Text(l.importNone));
    return Column(children: [
      for (final b in batches)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(b.fileName.isEmpty ? b.kind : b.fileName),
          subtitle: Text('${b.kind} · ${l.importBatchCount(b.createdCount)} · '
              '${b.createdAt.toLocal().toString().substring(0, 16)}'),
          trailing: b.status == 'undone'
              ? Text(l.importUndone)
              : TextButton(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        content: Text(l.importUndoConfirm),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(l.cancel)),
                          FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text(l.importUndo)),
                        ],
                      ),
                    );
                    if (ok != true) return;
                    final r = await ref.read(csvImportServiceProvider).undo(b.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(l.importUndoResult(r.removed, r.kept))));
                    }
                    onChanged();
                  },
                  child: Text(l.importUndo),
                ),
        ),
    ]);
  }
}
