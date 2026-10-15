import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parcel_khata/features/backup/domain/csv.dart';
import 'package:parcel_khata/features/backup/domain/csv_import.dart';
import 'package:parcel_khata/features/export/application/csv_import_service.dart';
import 'package:parcel_khata/l10n/l10n.dart';

enum _Kind { customers, orders }

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
      };

  Future<void> _pick() async {
    final r = await FilePicker.pickFiles();
    if (r.isEmpty || r.first.path == null) return;
    final text = await File(r.first.path!).readAsString();
    final rows = Csv.parse(text);
    setState(() {
      _rows = rows;
      _report = null;
      _map = rows.isEmpty ? {} : autoMapColumns(rows.first, _targets);
    });
  }

  CustomerImportPlan get _customerPlan => CsvImportPlanner.customers(_data, _map);
  OrderImportPlan get _orderPlan => CsvImportPlanner.orders(_data, _map);

  int get _valid => _kind == _Kind.customers ? _customerPlan.rows.length : _orderPlan.rows.length;
  int get _bad => _kind == _Kind.customers ? _customerPlan.issues.length : _orderPlan.issues.length;

  Future<void> _run() async {
    setState(() => _busy = true);
    final svc = ref.read(csvImportServiceProvider);
    final r = _kind == _Kind.customers
        ? await svc.importCustomers(_customerPlan, skipBadRows: _skipBad)
        : await svc.importOrders(_orderPlan, skipBadRows: _skipBad);
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
        SegmentedButton<_Kind>(
          segments: [
            ButtonSegment(value: _Kind.customers, label: Text(l.importCustomers)),
            ButtonSegment(value: _Kind.orders, label: Text(l.importOrders)),
          ],
          selected: {_kind},
          onSelectionChanged: (s) => setState(() {
            _kind = s.first;
            _rows = const [];
            _map = {};
            _report = null;
          }),
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
      ]),
    );
  }
}
