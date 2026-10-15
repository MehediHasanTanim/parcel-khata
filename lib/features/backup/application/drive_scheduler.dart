import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:parcel_khata/core/db/app_database.dart';
import 'package:parcel_khata/core/providers.dart';
import 'package:parcel_khata/core/time/clock.dart';
import 'package:parcel_khata/features/backup/application/backup_service.dart';
import 'package:parcel_khata/features/backup/application/drive_backup.dart';
import 'package:parcel_khata/features/security/application/secret_store.dart';
import 'package:parcel_khata/features/settings/application/settings_repository.dart';
import 'package:workmanager/workmanager.dart';

const _uniqueName = 'parcel_khata.drive_backup';
const _taskName = 'driveBackup';

/// Weekly, unmetered network + charging (Android WorkManager).
abstract final class DriveScheduler {
  static bool get supported => Platform.isAndroid;

  static Future<void> init() async {
    if (!supported) return;
    await Workmanager().initialize(driveCallbackDispatcher);
  }

  static Future<void> schedule() async {
    if (!supported) return;
    await Workmanager().registerPeriodicTask(
      _uniqueName,
      _taskName,
      frequency: const Duration(days: 7),
      constraints: Constraints(
        networkType: NetworkType.unmetered,
        requiresCharging: true,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    );
  }

  static Future<void> cancel() async {
    if (!supported) return;
    await Workmanager().cancelByUniqueName(_uniqueName);
  }
}

/// Runs in a background isolate: opens its own database, backs up, closes.
/// Returning true on a handled failure avoids WorkManager retry storms; the
/// failure is stored in settings and the backup reminder surfaces it.
@pragma('vm:entry-point')
void driveCallbackDispatcher() {
  Workmanager().executeTask((task, input) async {
    if (task != _taskName) return true;
    WidgetsFlutterBinding.ensureInitialized();
    final db = openAppDatabase();
    try {
      const clock = SystemClock();
      final settings = SettingsRepository(db, clock, kDefaultShopId);
      final s = await settings.read();
      if (!s.driveEnabled) return true;
      final backup = BackupService(db, clock, settings, () async {});
      final svc = DriveBackupService(
          backup, GoogleDriveClient(), settings, SecureSecretStore(), clock);
      await svc.backupNow();
      return true;
    } on Object {
      return true;
    } finally {
      await db.close();
    }
  });
}
