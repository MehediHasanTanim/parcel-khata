import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parcel_khata/core/db/app_database.dart';
import 'package:parcel_khata/core/db/providers.dart';
import 'package:parcel_khata/features/reminders/application/digest_service.dart';
import 'package:parcel_khata/features/security/application/secret_store.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// "Erase all data": database, attachments, secrets and scheduled
/// notifications (implementation plan §10).
class EraseService {
  EraseService(this._closeDb, this._secrets, this._digest);

  final Future<void> Function() _closeDb;
  final SecretStore _secrets;
  final DigestNotifier _digest;

  Future<void> eraseAll() async {
    await _digest.cancel();
    await _closeDb();
    final live = await databaseFile();
    for (final suffix in ['', '-wal', '-shm', '.pre_restore']) {
      final f = File('${live.path}$suffix');
      if (f.existsSync()) await f.delete();
    }
    final docs = (await PathProviderPlatform.instance.getApplicationDocumentsPath())!;
    final att = Directory(p.join(docs, 'attachments'));
    if (att.existsSync()) await att.delete(recursive: true);
    final tmp = await PathProviderPlatform.instance.getTemporaryPath();
    if (tmp != null) {
      final t = Directory(tmp);
      if (t.existsSync()) {
        for (final e in t.listSync()) {
          final name = p.basename(e.path);
          if (name.endsWith('.pkb') || name.endsWith('.csv') || name.startsWith('restore_')) {
            await e.delete(recursive: true);
          }
        }
      }
    }
    await _secrets.deleteAll();
  }
}

final eraseServiceProvider = Provider<EraseService>((ref) => EraseService(
      () async => ref.read(databaseProvider).close(),
      ref.read(secretStoreProvider),
      ref.read(digestNotifierProvider),
    ));
