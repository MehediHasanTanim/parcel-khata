import 'dart:typed_data';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_khata/core/db/app_database.dart';
import 'package:parcel_khata/core/db/audit_writer.dart';
import 'package:parcel_khata/core/ids/uuid_v7.dart';
import 'package:parcel_khata/core/time/clock.dart';
import 'package:parcel_khata/features/backup/application/backup_service.dart';
import 'package:parcel_khata/features/backup/application/drive_backup.dart';
import 'package:parcel_khata/features/backup/domain/backup_codec.dart';
import 'package:parcel_khata/features/customers/application/customer_repository.dart';
import 'package:parcel_khata/features/security/application/secret_store.dart';
import 'package:parcel_khata/features/settings/application/settings_repository.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePaths extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _FakePaths(this.dir);
  final Directory dir;

  @override
  Future<String?> getApplicationDocumentsPath() async => dir.path;

  @override
  Future<String?> getTemporaryPath() async => p.join(dir.path, 'tmp');
}

class _FakeDrive implements DriveClient {
  final Map<String, List<int>> files = {};
  final List<String> order = [];
  Object? failWith;
  bool signedIn = false;
  int _n = 0;

  @override
  Future<String> signIn() async {
    signedIn = true;
    return 'a@b.c';
  }

  @override
  Future<void> signOut() async => signedIn = false;

  @override
  Future<DriveFileRef> upload(File file, {required String name}) async {
    if (failWith != null) throw failWith!;
    final id = 'id${_n++}';
    files[id] = await file.readAsBytes();
    order.insert(0, id);
    return DriveFileRef(id: id, name: name);
  }

  @override
  Future<List<DriveFileRef>> list() async => [
        for (final id in order) DriveFileRef(id: id, name: '$id.pkb'),
      ];

  @override
  Future<File> download(DriveFileRef ref, Directory into) async {
    final f = File(p.join(into.path, ref.name));
    await f.writeAsBytes(files[ref.id]!);
    return f;
  }

  @override
  Future<void> delete(DriveFileRef ref) async {
    files.remove(ref.id);
    order.remove(ref.id);
  }
}

void main() {
  late Directory dir;
  late AppDatabase db;
  late FakeClock clock;
  late SettingsRepository settings;
  late BackupService backup;
  late _FakeDrive drive;
  late MemorySecretStore secrets;
  late DriveBackupService svc;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('pk_drive');
    await Directory(p.join(dir.path, 'tmp')).create();
    PathProviderPlatform.instance = _FakePaths(dir);
    db = AppDatabase.memory();
    clock = FakeClock(DateTime(2026, 10, 15, 12));
    final ids = UuidV7(clock: clock);
    settings = SettingsRepository(db, clock, 's');
    await settings.ensureShop();
    backup = BackupService(db, clock, settings, () async {});
    drive = _FakeDrive();
    secrets = MemorySecretStore();
    svc = DriveBackupService(backup, drive, settings, secrets, clock);
    await CustomerRepository(db, ids, clock, AuditWriter(db, ids, clock, 's'), 's')
        .create(const CustomerInput(name: 'Rahim', phone: '01712345678'));
  });

  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  test('enable needs a passphrase, signs in and stores it only in the secret store',
      () async {
    await expectLater(svc.enable(passphrase: '  '), throwsA(isA<DriveException>()));
    await svc.enable(passphrase: 'correct horse');
    expect(drive.signedIn, isTrue);
    expect(await secrets.read(DriveBackupService.passphraseKey), 'correct horse');
    final s = await settings.read();
    expect(s.driveEnabled, isTrue);
    expect(s.encode(), isNot(contains('correct horse')));
  });

  test('backup uploads an encrypted .pkb that a second device can restore', () async {
    await svc.enable(passphrase: 'pw-123');
    final r = await svc.backupNow();
    expect(r.isOk, isTrue);
    expect(drive.files, hasLength(1));
    expect(BackupCodec.isEncrypted(Uint8List.fromList(drive.files.values.single)), isTrue);
    final s = await settings.read();
    expect(s.driveLastSuccessMs, clock.now().millisecondsSinceEpoch);
    expect(s.lastBackupAtMs, clock.now().millisecondsSinceEpoch);
    expect(s.driveLastError, isNull);

    // "Second device": fresh database, same restore flow.
    final other = AppDatabase.memory();
    final otherSettings = SettingsRepository(other, clock, 's');
    await otherSettings.ensureShop();
    final otherBackup = BackupService(other, clock, otherSettings, () async {});
    final file = await svc.fetch((await svc.backups()).single);
    await expectLater(otherBackup.inspect(file), throwsA(isA<BackupFormatException>()));
    final preview = await otherBackup.inspect(file, passphrase: 'pw-123');
    expect(preview.encrypted, isTrue);
    expect(preview.manifest.counts['customers'], 1);
    final out = await otherBackup.restore(file, mode: RestoreMode.merge, passphrase: 'pw-123');
    expect(out.counts['customers'], 1);
    final n = await other
        .customSelect('SELECT COUNT(*) n FROM customers WHERE deleted_at IS NULL')
        .getSingle();
    expect(n.read<int>('n'), 1);
    await other.close();
  });

  test('a failed upload keeps the last-backup time so the reminder still fires',
      () async {
    await svc.enable(passphrase: 'pw');
    drive.failWith = const DriveException(DriveProblem.network);
    final r = await svc.backupNow();
    expect(r.isOk, isFalse);
    expect(r.problem, DriveProblem.network);
    final s = await settings.read();
    expect(s.lastBackupAtMs, isNull);
    expect(s.driveLastError, 'network');
    expect(s.driveLastSuccessMs, isNull);
    // No stray temp file left behind.
    final leftovers = Directory(p.join(dir.path, 'tmp'))
        .listSync()
        .where((f) => f.path.endsWith('.pkb'));
    expect(leftovers, isEmpty);
  });

  test('a failure after an earlier backup preserves that earlier time', () async {
    await svc.enable(passphrase: 'pw');
    await svc.backupNow();
    final first = (await settings.read()).lastBackupAtMs!;
    clock = FakeClock(DateTime(2026, 10, 22, 12));
    svc = DriveBackupService(
        BackupService(db, clock, settings, () async {}), drive, settings, secrets, clock);
    drive.failWith = Exception('boom');
    final r = await svc.backupNow();
    expect(r.problem, DriveProblem.other);
    expect((await settings.read()).lastBackupAtMs, first);
  });

  test('missing passphrase is reported, nothing uploaded', () async {
    final r = await svc.backupNow();
    expect(r.problem, DriveProblem.passphraseMissing);
    expect(drive.files, isEmpty);
  });

  test('only the latest five backups are kept', () async {
    await svc.enable(passphrase: 'pw');
    for (var i = 0; i < 7; i++) {
      clock = FakeClock(DateTime(2026, 10, 15 + i, 12));
      svc = DriveBackupService(
          BackupService(db, clock, settings, () async {}), drive, settings, secrets, clock);
      expect((await svc.backupNow()).isOk, isTrue);
    }
    expect(drive.files, hasLength(DriveBackupService.keepLatest));
  });

  test('disable removes the stored passphrase and signs out', () async {
    await svc.enable(passphrase: 'pw');
    await svc.disable();
    expect(await secrets.read(DriveBackupService.passphraseKey), isNull);
    expect(drive.signedIn, isFalse);
    expect((await settings.read()).driveEnabled, isFalse);
  });

  test('merge restore brings expenses, campaigns and import history along', () async {
    await db.customStatement(
        "INSERT INTO campaigns (id, shop_id, created_at, updated_at, name, tag, start_date, end_date, spend) "
        "VALUES ('cm1','s',0,0,'Eid','eid',0,86400,100000)");
    await db.customStatement(
        "INSERT INTO expenses (id, shop_id, created_at, updated_at, date, category, amount) "
        "VALUES ('e1','s',0,0,0,'rent',500000)");
    await db.customStatement(
        "INSERT INTO import_batches (id, shop_id, created_at, updated_at, kind) VALUES ('b1','s',0,0,'products')");
    final file = await backup.create();
    final other = AppDatabase.memory();
    final otherSettings = SettingsRepository(other, clock, 's');
    await otherSettings.ensureShop();
    await BackupService(other, clock, otherSettings, () async {})
        .restore(file, mode: RestoreMode.merge);
    Future<int> n(String t) async => (await other.customSelect('SELECT COUNT(*) n FROM $t').getSingle())
        .read<int>('n');
    expect(await n('campaigns'), 1);
    expect(await n('expenses'), 1);
    expect(await n('import_batches'), 1);
    await other.close();
  });
}
