import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

/// iOS has no `allowBackup="false"`: files in the app container are included
/// in iCloud/iTunes backups unless each file is flagged
/// `NSURLIsExcludedFromBackupKey`. The database and attachments hold
/// customers' personal data, so they are excluded; the only cloud copy is
/// the encrypted `.pkb` the user chooses to export.
abstract final class BackupExclusion {
  static const _channel = MethodChannel('parcel_khata/platform');

  /// Flags the database triplet and the attachments folder. Safe to call
  /// repeatedly (WAL/SHM files appear after the database is first opened).
  /// No-op off iOS. Returns the paths that were flagged.
  static Future<List<String>> apply({
    required String databasePath,
    required String attachmentsDir,
    bool? isIOS,
  }) async {
    if (!(isIOS ?? Platform.isIOS)) return const [];
    final flagged = <String>[];
    final targets = [
      databasePath,
      '$databasePath-wal',
      '$databasePath-shm',
      attachmentsDir,
    ];
    for (final path in targets) {
      final isDir = path == attachmentsDir;
      if (isDir) {
        await Directory(path).create(recursive: true);
      } else if (!File(path).existsSync()) {
        continue;
      }
      try {
        await _channel.invokeMethod<void>('excludeFromBackup', {'path': path});
        flagged.add(path);
      } on MissingPluginException {
        // Native side not present (tests, other platforms).
      } on PlatformException {
        // Best effort: a failure must never block the app.
      }
    }
    return flagged;
  }

  static String attachmentsIn(String documentsDir) => p.join(documentsDir, 'attachments');
}
