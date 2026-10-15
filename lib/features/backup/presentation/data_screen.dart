import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:parcel_khata/core/db/providers.dart';
import 'package:parcel_khata/features/backup/application/backup_service.dart';
import 'package:parcel_khata/features/backup/application/drive_backup.dart';
import 'package:parcel_khata/features/backup/application/drive_scheduler.dart';
import 'package:parcel_khata/features/backup/domain/backup_codec.dart';
import 'package:parcel_khata/features/backup/domain/csv_import.dart';
import 'package:parcel_khata/features/export/application/csv_exporter.dart';
import 'package:parcel_khata/features/orders/presentation/order_labels.dart';
import 'package:parcel_khata/features/settings/application/settings_repository.dart';
import 'package:parcel_khata/features/settings/domain/shop_settings.dart';
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
    final picked = await FilePicker.pickFiles();
    if (picked.isEmpty || picked.first.path == null || !mounted) return;
    await _restoreFile(File(picked.first.path!));
  }

  /// Shared by "pick a file" and "restore from Drive": same preview, same
  /// merge/replace choice, same failure-safe restore.
  Future<void> _restoreFile(File file) async {
    final l = context.l10n;
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

  String _driveError(AppLocalizations l, String code) => switch (code) {
        'notSignedIn' => l.driveErrNotSignedIn,
        'passphraseMissing' => l.driveErrPassphrase,
        'network' => l.driveErrNetwork,
        _ => l.driveErrOther,
      };

  Future<void> _driveToggle(bool on) async {
    final l = context.l10n;
    final svc = ref.read(driveBackupServiceProvider);
    setState(() => _busy = true);
    try {
      if (on) {
        final pass = await _askPassphrase(title: l.driveTitle, optional: false);
        if (pass == null || pass.isEmpty) return;
        await svc.enable(passphrase: pass);
        await DriveScheduler.schedule();
      } else {
        await svc.disable();
        await DriveScheduler.cancel();
      }
    } on DriveException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_driveError(l, e.problem.name))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _driveBackupNow() async {
    final l = context.l10n;
    setState(() => _busy = true);
    final r = await ref.read(driveBackupServiceProvider).backupNow();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(r.isOk ? l.driveUploaded : _driveError(l, r.problem!.name))));
  }

  Future<void> _driveRestore() async {
    final l = context.l10n;
    final svc = ref.read(driveBackupServiceProvider);
    setState(() => _busy = true);
    List<DriveFileRef> refs;
    try {
      refs = await svc.backups();
    } on DriveException catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_driveError(l, e.problem.name))));
      }
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (refs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.driveNoBackups)));
      return;
    }
    final pick = await showModalBottomSheet<DriveFileRef>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          for (final r in refs)
            ListTile(
              leading: const Icon(Icons.cloud_download_outlined),
              title: Text(r.name),
              subtitle: r.modified == null ? null : Text(formatDateTime(r.modified!.toLocal())),
              onTap: () => Navigator.pop(ctx, r),
            ),
        ]),
      ),
    );
    if (pick == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final file = await svc.fetch(pick);
      if (!mounted) return;
      setState(() => _busy = false);
      await _restoreFile(file);
    } on DriveException catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_driveError(l, e.problem.name))));
      }
    }
  }

  List<Widget> _driveSection(AppLocalizations l, ShopSettings? s) {
    final on = s?.driveEnabled ?? false;
    return [
      SwitchListTile(
        secondary: const Icon(Icons.cloud_outlined),
        title: Text(l.driveTitle),
        subtitle: Text(on ? l.driveSchedule : l.driveSubtitle),
        value: on,
        onChanged: _busy ? null : _driveToggle,
      ),
      if (on) ...[
        if (s?.driveLastSuccessMs != null)
          ListTile(
            dense: true,
            title: Text(l.driveLastSuccess),
            subtitle: Text(formatDateTime(
                DateTime.fromMillisecondsSinceEpoch(s!.driveLastSuccessMs!))),
          ),
        if (s?.driveLastError != null)
          ListTile(
            dense: true,
            leading: Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
            title: Text(_driveError(l, s!.driveLastError!)),
          ),
        ListTile(
          leading: const Icon(Icons.cloud_upload_outlined),
          title: Text(l.driveBackupNow),
          onTap: _busy ? null : _driveBackupNow,
        ),
      ],
      ListTile(
        leading: const Icon(Icons.cloud_download_outlined),
        title: Text(l.driveRestore),
        onTap: _busy ? null : _driveRestore,
      ),
    ];
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
          ..._driveSection(l, s),
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
