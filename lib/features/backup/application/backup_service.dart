import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parcel_khata/core/db/app_database.dart';
import 'package:parcel_khata/core/db/providers.dart';
import 'package:parcel_khata/core/time/clock.dart';
import 'package:parcel_khata/core/time/providers.dart';
import 'package:parcel_khata/features/backup/domain/backup_codec.dart';
import 'package:parcel_khata/features/settings/application/settings_repository.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

enum RestoreMode { replace, merge }

class RestorePreview {
  const RestorePreview(this.manifest, {required this.encrypted});
  final BackupManifest manifest;
  final bool encrypted;
}

class RestoreOutcome {
  const RestoreOutcome({required this.mode, required this.counts});
  final RestoreMode mode;
  final Map<String, int> counts;
}

/// Backup & restore (feature spec F14, implementation plan §7 S7-12/13).
///
/// Restore is failure-safe: the file is validated and migrated in a temp
/// database first; the live database is only touched when that succeeded, and
/// a `.pre_restore` copy is kept.
class BackupService {
  BackupService(this._db, this._clock, this._settings, this._closeLive);

  final AppDatabase _db;
  final Clock _clock;
  final SettingsRepository _settings;

  /// Closes the live database so its file can be replaced.
  final Future<void> Function() _closeLive;

  static const _countTables = {
    'orders': 'orders',
    'customers': 'customers',
    'products': 'products',
    'couriers': 'couriers',
    'payouts': 'payouts',
  };

  Future<Directory> _appDir() async =>
      Directory((await PathProviderPlatform.instance.getApplicationDocumentsPath())!);

  Future<Directory> _tempDir() async =>
      Directory((await PathProviderPlatform.instance.getTemporaryPath())!);

  Future<Map<String, int>> _counts(AppDatabase db) async {
    final out = <String, int>{};
    for (final e in _countTables.entries) {
      final r = await db
          .customSelect('SELECT COUNT(*) AS n FROM ${e.value} WHERE deleted_at IS NULL')
          .getSingle();
      out[e.key] = r.read<int>('n');
    }
    return out;
  }

  /// Creates a backup file (optionally encrypted) and records the time.
  Future<File> create({String? passphrase}) async {
    final temp = await _tempDir();
    final snap = File(p.join(temp.path, 'snapshot_${_clock.now().millisecondsSinceEpoch}.sqlite'));
    if (snap.existsSync()) await snap.delete();
    // Consistent point-in-time copy even while the app keeps writing (WAL).
    final escaped = snap.path.replaceAll("'", "''");
    await _db.customStatement("VACUUM INTO '$escaped'");
    final dbBytes = await snap.readAsBytes();
    await snap.delete();

    final attachments = <String, Uint8List>{};
    final attDir = Directory(p.join((await _appDir()).path, 'attachments'));
    if (attDir.existsSync()) {
      for (final f in attDir.listSync(recursive: true).whereType<File>()) {
        final rel = p.relative(f.path, from: (await _appDir()).path).replaceAll(r'\', '/');
        attachments[rel] = await f.readAsBytes();
      }
    }
    var bytes = BackupCodec.pack(
      db: dbBytes,
      attachments: attachments,
      schemaVersion: _db.schemaVersion,
      counts: await _counts(_db),
      createdAt: _clock.now(),
    );
    final encrypted = passphrase != null && passphrase.isNotEmpty;
    if (encrypted) bytes = await BackupCodec.encrypt(bytes, passphrase);
    final d = _clock.now();
    final name = 'parcel_khata_${d.year}${_2(d.month)}${_2(d.day)}_${_2(d.hour)}${_2(d.minute)}'
        '${encrypted ? '.enc' : ''}.pkb';
    final out = File(p.join(temp.path, name));
    await out.writeAsBytes(bytes, flush: true);

    final s = await _settings.read();
    await _settings.save(s.copyWith(lastBackupAtMs: d.millisecondsSinceEpoch));
    return out;
  }

  static String _2(int n) => n.toString().padLeft(2, '0');

  Future<UnpackedBackup> _open(File file, String? passphrase) async {
    var bytes = await file.readAsBytes();
    if (BackupCodec.isEncrypted(bytes)) {
      if (passphrase == null || passphrase.isEmpty) {
        throw const BackupFormatException(BackupProblem.passphraseRequired);
      }
      bytes = await BackupCodec.decrypt(bytes, passphrase);
    }
    return BackupCodec.unpack(bytes, currentSchemaVersion: _db.schemaVersion);
  }

  /// Validates the file and returns what it contains (restore preview).
  Future<RestorePreview> inspect(File file, {String? passphrase}) async {
    final encrypted = BackupCodec.isEncrypted(await file.readAsBytes());
    final u = await _open(file, passphrase);
    return RestorePreview(u.manifest, encrypted: encrypted);
  }

  Future<RestoreOutcome> restore(
    File file, {
    required RestoreMode mode,
    String? passphrase,
  }) async {
    final u = await _open(file, passphrase);
    final temp = await _tempDir();
    final staged = File(p.join(temp.path, 'restore_${_clock.now().millisecondsSinceEpoch}.sqlite'));
    await staged.writeAsBytes(u.db, flush: true);
    try {
      // Opening runs schema migrations for older backups; then verify.
      final probe = AppDatabase(NativeDatabase(staged));
      try {
        final ok = await probe.customSelect('PRAGMA integrity_check').getSingle();
        if (ok.data.values.first != 'ok') {
          throw const BackupFormatException(BackupProblem.corrupted);
        }
        await probe.customSelect('SELECT COUNT(*) FROM shops').get();
      } finally {
        await probe.close();
      }
      final counts = u.manifest.counts;
      final appDir = await _appDir();
      if (mode == RestoreMode.replace) {
        final live = await databaseFile();
        await _closeLive();
        final safety = File('${live.path}.pre_restore');
        if (live.existsSync()) await live.copy(safety.path);
        for (final ext in ['-wal', '-shm']) {
          final f = File('${live.path}$ext');
          if (f.existsSync()) await f.delete();
        }
        try {
          await staged.copy(live.path);
        } on Object {
          if (safety.existsSync()) await safety.copy(live.path);
          rethrow;
        }
      } else {
        await _merge(staged);
      }
      for (final e in u.attachments.entries) {
        final dest = File(p.join(appDir.path, e.key));
        await dest.parent.create(recursive: true);
        await dest.writeAsBytes(e.value);
      }
      return RestoreOutcome(mode: mode, counts: counts);
    } finally {
      if (staged.existsSync()) await staged.delete();
    }
  }

  // Parents before children; value = (child column, parent table) guards.
  static const _mergeOrder = <String, (String, String)?>{
    'shops': null,
    'customers': null,
    'customer_addresses': ('customer_id', 'customers'),
    'products': null,
    'product_variants': ('product_id', 'products'),
    'couriers': null,
    'courier_rate_rules': ('courier_id', 'couriers'),
    'orders': null,
    'order_lines': ('order_id', 'orders'),
    'order_charges': ('order_id', 'orders'),
    'order_status_events': ('order_id', 'orders'),
    'order_edit_log': ('order_id', 'orders'),
    'order_attachments': ('order_id', 'orders'),
    'payouts': ('courier_id', 'couriers'),
    'payout_allocations': ('payout_id', 'payouts'),
    'return_records': ('order_id', 'orders'),
    'return_lines': ('return_id', 'return_records'),
    'saved_views': null,
    'reminders': null,
    'message_templates': null,
    'audit_log': null,
  };

  /// Adds rows the live database does not have (same id = local wins).
  Future<void> _merge(File staged) async {
    final path = staged.path.replaceAll("'", "''");
    await _db.customStatement("ATTACH DATABASE '$path' AS bak");
    try {
      for (final e in _mergeOrder.entries) {
        final t = e.key;
        final main = await _db.customSelect('PRAGMA main.table_info($t)').get();
        final bak = await _db.customSelect('PRAGMA bak.table_info($t)').get();
        final mainCols = [for (final r in main) r.read<String>('name')];
        final bakCols = {for (final r in bak) r.read<String>('name')};
        final cols = mainCols.where(bakCols.contains).toList();
        if (cols.isEmpty) continue;
        final list = cols.map((c) => '"$c"').join(', ');
        final guard = e.value;
        final where = guard == null
            ? ''
            : ' WHERE "${guard.$1}" IN (SELECT id FROM main.${guard.$2})';
        await _db.customStatement(
          'INSERT OR IGNORE INTO main.$t ($list) SELECT $list FROM bak.$t$where',
        );
      }
    } finally {
      await _db.customStatement('DETACH DATABASE bak');
    }
  }
}

final backupServiceProvider = Provider<BackupService>((ref) => BackupService(
      ref.watch(databaseProvider),
      ref.watch(clockProvider),
      ref.watch(settingsRepositoryProvider),
      () async => ref.read(databaseProvider).close(),
    ));
