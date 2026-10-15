import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:parcel_khata/core/db/providers.dart';
import 'package:parcel_khata/features/backup/application/backup_service.dart';
import 'package:parcel_khata/features/backup/domain/backup_codec.dart';
import 'package:parcel_khata/features/backup/domain/csv_import.dart';
import 'package:parcel_khata/features/export/application/csv_exporter.dart';
import 'package:parcel_khata/features/orders/presentation/order_labels.dart';
import 'package:parcel_khata/features/settings/application/settings_repository.dart';
import 'package:parcel_khata/l10n/l10n.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:share_plus/share_plus.dart';

String backupProblemText(AppLocalizations l, BackupProblem p) => switch (p) {
      BackupProblem.notABackup => l.errBackupNotBackup,
      BackupProblem.corrupted => l.errBackupCorrupted,
      BackupProblem.checksumMismatch => l.errBackupChecksum,
      BackupProblem.newerSchema => l.errBackupNewer,
      BackupProblem.wrongPassphrase => l.errBackupPass,
      BackupProblem.passphraseRequired => l.errBackupNeedPass,
    };

Future<void> shareFilePath(String path, {String? text}) =>
    SharePlus.instance.share(ShareParams(files: [XFile(path)], text: text));

/// Settings > Data: backup, restore, CSV export, import entry points.
class DataScreen extends ConsumerStatefulWidget {
  const DataScreen({super.key});

  @override
  ConsumerState<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends ConsumerState<DataScreen> {
  bool _busy = false;

  Future<String?> _askPassphrase({required String title, bool optional = true}) async {
    final l = context.l10n;
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          obscureText: true,
          decoration: InputDecoration(labelText: l.backupPassphrase),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(l.confirm)),
        ],
      ),
    );
    final v = c.text;
    c.dispose();
    return ok == true ? v : null;
  }

  Future<void> _backup() async {
    final l = context.l10n;
    final pass = await _askPassphrase(title: l.backupNow);
    if (pass == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final f = await ref.read(backupServiceProvider).create(passphrase: pass);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.backupCreated)));
      await shareFilePath(f.path);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final l = context.l10n;
    final picked = await FilePicker.pickFiles();
    if (picked.isEmpty || picked.first.path == null || !mounted) return;
    final file = File(picked.first.path!);
    final svc = ref.read(backupServiceProvider);
    String? pass;
    RestorePreview? preview;
    try {
      try {
        preview = await svc.inspect(file);
      } on BackupFormatException catch (e) {
        if (e.problem != BackupProblem.passphraseRequired) rethrow;
        pass = await _askPassphrase(title: l.restoreBackup, optional: false);
        if (pass == null) return;
        preview = await svc.inspect(file, passphrase: pass);
      }
    } on BackupFormatException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(backupProblemText(l, e.problem))));
      }
      return;
    }
    if (!mounted) return;
    final mode = await showDialog<RestoreMode>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(l.restorePreview),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(formatDateTime(preview!.manifest.createdAt)),
          const SizedBox(height: 8),
          for (final e in preview.manifest.counts.entries) Text('${e.key}: ${e.value}'),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: Text(l.cancel)),
          OutlinedButton(
              onPressed: () => Navigator.pop(d, RestoreMode.merge), child: Text(l.restoreMerge)),
          FilledButton(
              onPressed: () => Navigator.pop(d, RestoreMode.replace),
              child: Text(l.restoreReplace)),
        ],
      ),
    );
    if (mode == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await svc.restore(file, mode: mode, passphrase: pass);
      // Reopen the database so every screen reads the restored data.
      ref.invalidate(databaseProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.restoreDone)));
      }
    } on BackupFormatException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(backupProblemText(l, e.problem))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export(String name, Future<String> Function() build) async {
    setState(() => _busy = true);
    try {
      final text = await build();
      final dir = Directory((await PathProviderPlatform.instance.getTemporaryPath())!);
      final f = File(p.join(dir.path, '$name.csv'));
      await f.writeAsString(text);
      await shareFilePath(f.path);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final exp = ref.read(csvExporterProvider);
    final s = ref.watch(shopSettingsProvider).value;
    final last = s?.lastBackupAtMs == null
        ? l.neverBackedUp
        : formatDateTime(DateTime.fromMillisecondsSinceEpoch(s!.lastBackupAtMs!));
    return Scaffold(
      appBar: AppBar(title: Text(l.dataSection)),
      body: Stack(children: [
        ListView(children: [
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: Text(l.backupNow),
            subtitle: Text('${l.lastBackup}: $last'),
            onTap: _busy ? null : _backup,
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: Text(l.restoreBackup),
            onTap: _busy ? null : _restore,
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(l.exportData, style: Theme.of(context).textTheme.titleSmall),
          ),
          ListTile(
            leading: const Icon(Icons.table_chart_outlined),
            title: Text(l.exportOrders),
            onTap: () => _export('orders', exp.orders),
          ),
          ListTile(
            leading: const Icon(Icons.table_rows_outlined),
            title: Text('${l.exportOrders} – ${l.items}'),
            onTap: () => _export('order_lines', exp.orderLines),
          ),
          ListTile(
            leading: const Icon(Icons.people_outline),
            title: Text(l.exportCustomers),
            onTap: () => _export('customers', exp.customers),
          ),
          ListTile(
            leading: const Icon(Icons.inventory_2_outlined),
            title: Text(l.exportProducts),
            onTap: () => _export('products', exp.products),
          ),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: Text(l.exportPayouts),
            onTap: () => _export('payouts', exp.payouts),
          ),
          ListTile(
            leading: const Icon(Icons.assignment_return_outlined),
            title: Text(l.exportReturns),
            onTap: () => _export('returns', exp.returns),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: Text(l.importCsv),
            onTap: () => context.push('/settings/import'),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(l.downloadTemplate),
            subtitle: Text('${l.importCustomers} / ${l.importOrders}'),
            onTap: () async {
              await _export('customers_template',
                  () async => CsvExporter.template(CsvColumns.customers));
              await _export('orders_template', () async => CsvExporter.template([
                    ...CsvColumns.orders,
                    'item_name',
                    'qty',
                    'unit_price',
                    'unit_cost',
                  ]));
            },
          ),
        ]),
        if (_busy) const Center(child: CircularProgressIndicator()),
      ]),
    );
  }
}
