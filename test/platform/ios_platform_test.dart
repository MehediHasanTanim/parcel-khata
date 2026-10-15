import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_khata/core/platform/backup_exclusion.dart';
import 'package:parcel_khata/core/platform/fresh_install_guard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BackupExclusion (iOS)', () {
    late Directory dir;
    final calls = <String>[];

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('pk_ios');
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('parcel_khata/platform'), (c) async {
        if (c.method == 'excludeFromBackup') {
          calls.add((c.arguments as Map)['path'] as String);
        }
        return null;
      });
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('parcel_khata/platform'), null);
      await dir.delete(recursive: true);
    });

    test('flags the database, its WAL/SHM when present, and the attachments folder', () async {
      final db = File('${dir.path}/parcel_khata.sqlite')..writeAsStringSync('x');
      File('${db.path}-wal').writeAsStringSync('x');
      final att = '${dir.path}/attachments';
      final flagged = await BackupExclusion.apply(
          databasePath: db.path, attachmentsDir: att, isIOS: true);
      expect(flagged, [db.path, '${db.path}-wal', att]);
      expect(calls, flagged);
      expect(Directory(att).existsSync(), isTrue);
    });

    test('is a no-op off iOS', () async {
      final flagged = await BackupExclusion.apply(
          databasePath: '${dir.path}/x.sqlite', attachmentsDir: '${dir.path}/a', isIOS: false);
      expect(flagged, isEmpty);
      expect(calls, isEmpty);
    });

    test('a missing native handler never throws', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('parcel_khata/platform'), null);
      final db = File('${dir.path}/p.sqlite')..writeAsStringSync('x');
      await expectLater(
          BackupExclusion.apply(
              databasePath: db.path, attachmentsDir: '${dir.path}/a', isIOS: true),
          completes);
    });
  });

  group('FreshInstallGuard (Keychain survives uninstall)', () {
    test('clears leftover secrets once, then leaves them alone', () async {
      final dir = await Directory.systemTemp.createTemp('pk_fresh');
      addTearDown(() => dir.delete(recursive: true));
      var cleared = 0;
      final g1 = FreshInstallGuard(directory: dir, clearSecrets: () async => cleared++);
      await g1.ensure();
      await g1.ensure();
      expect(cleared, 1);
      // Same container later (app relaunch): secrets are kept.
      final g2 = FreshInstallGuard(directory: dir, clearSecrets: () async => cleared++);
      await g2.ensure();
      expect(cleared, 1);
      // Reinstall: the container (and marker) is gone, the Keychain is not.
      File('${dir.path}/.pk_installed').deleteSync();
      final g3 = FreshInstallGuard(directory: dir, clearSecrets: () async => cleared++);
      await g3.ensure();
      expect(cleared, 2);
    });
  });
}
