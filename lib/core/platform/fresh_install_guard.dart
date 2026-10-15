import 'dart:io';

import 'package:path/path.dart' as p;

/// iOS Keychain items survive uninstall/reinstall, while the app container
/// (database, preferences) does not. Without this guard a reinstalled app
/// would find an old PIN hash and lock the user out of an empty database.
///
/// A marker file lives in the app container: no marker = fresh install, so
/// stale secrets are cleared once. Android's Keystore data is removed with
/// the app, making this a harmless no-op there.
class FreshInstallGuard {
  FreshInstallGuard({required this.directory, required this.clearSecrets, this.markerName = '.pk_installed'});

  final Directory directory;
  final Future<void> Function() clearSecrets;
  final String markerName;
  Future<void>? _done;

  /// Runs at most once per guard instance.
  Future<void> ensure() => _done ??= _run();

  Future<void> _run() async {
    final marker = File(p.join(directory.path, markerName));
    if (marker.existsSync()) return;
    await clearSecrets();
    await directory.create(recursive: true);
    await marker.writeAsString('1', flush: true);
  }
}
