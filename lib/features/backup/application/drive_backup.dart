import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:parcel_khata/core/time/clock.dart';
import 'package:parcel_khata/core/time/providers.dart';
import 'package:parcel_khata/features/backup/application/backup_service.dart';
import 'package:parcel_khata/features/security/application/secret_store.dart';
import 'package:parcel_khata/features/settings/application/settings_repository.dart';
import 'package:parcel_khata/features/settings/domain/shop_settings.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class DriveFileRef {
  const DriveFileRef({required this.id, required this.name, this.modified, this.size});
  final String id;
  final String name;
  final DateTime? modified;
  final int? size;
}

/// Failure categories surfaced to the UI (never raw exceptions).
enum DriveProblem { notSignedIn, passphraseMissing, network, other }

class DriveException implements Exception {
  const DriveException(this.problem, [this.detail = '']);
  final DriveProblem problem;
  final String detail;

  @override
  String toString() => 'DriveException(${problem.name}) $detail';
}

/// Minimal Drive surface so the service is testable without Google.
abstract class DriveClient {
  /// Interactive sign-in + `drive.appdata` consent. Returns the account email.
  Future<String> signIn();
  Future<void> signOut();
  Future<DriveFileRef> upload(File file, {required String name});
  Future<List<DriveFileRef>> list();
  Future<File> download(DriveFileRef ref, Directory into);
  Future<void> delete(DriveFileRef ref);
}

/// Real client: Google Sign-In scoped to `drive.appdata` only, which can see
/// nothing but this app's own hidden folder.
class GoogleDriveClient implements DriveClient {
  static const scope = 'https://www.googleapis.com/auth/drive.appdata';
  static bool _initialised = false;

  Future<drive.DriveApi> _api({bool interactive = false}) async {
    final gs = GoogleSignIn.instance;
    if (!_initialised) {
      await gs.initialize();
      _initialised = true;
    }
    var account = await gs.attemptLightweightAuthentication();
    if (account == null) {
      if (!interactive) throw const DriveException(DriveProblem.notSignedIn);
      account = await gs.authenticate(scopeHint: const [scope]);
    }
    final client = account.authorizationClient;
    var authz = await client.authorizationForScopes(const [scope]);
    if (authz == null) {
      if (!interactive) throw const DriveException(DriveProblem.notSignedIn);
      authz = await client.authorizeScopes(const [scope]);
    }
    return drive.DriveApi(authz.authClient(scopes: const [scope]));
  }

  Never _wrap(Object e) {
    if (e is DriveException) throw e;
    if (e is SocketException) throw DriveException(DriveProblem.network, '$e');
    throw DriveException(DriveProblem.other, '$e');
  }

  @override
  Future<String> signIn() async {
    try {
      await _api(interactive: true);
      final a = await GoogleSignIn.instance.attemptLightweightAuthentication();
      return a?.email ?? '';
    } on Object catch (e) {
      _wrap(e);
    }
  }

  @override
  Future<void> signOut() => GoogleSignIn.instance.signOut();

  @override
  Future<DriveFileRef> upload(File file, {required String name}) async {
    try {
      final api = await _api();
      final meta = drive.File()
        ..name = name
        ..parents = ['appDataFolder'];
      final created = await api.files.create(
        meta,
        uploadMedia: drive.Media(file.openRead(), await file.length()),
        $fields: 'id,name,modifiedTime,size',
      );
      return _ref(created);
    } on Object catch (e) {
      _wrap(e);
    }
  }

  static DriveFileRef _ref(drive.File f) => DriveFileRef(
        id: f.id ?? '',
        name: f.name ?? '',
        modified: f.modifiedTime,
        size: int.tryParse(f.size ?? ''),
      );

  @override
  Future<List<DriveFileRef>> list() async {
    try {
      final api = await _api();
      final res = await api.files.list(
        spaces: 'appDataFolder',
        orderBy: 'modifiedTime desc',
        pageSize: 50,
        $fields: 'files(id,name,modifiedTime,size)',
      );
      return [for (final f in res.files ?? const <drive.File>[]) _ref(f)];
    } on Object catch (e) {
      _wrap(e);
    }
  }

  @override
  Future<File> download(DriveFileRef ref, Directory into) async {
    try {
      final api = await _api();
      final media = await api.files.get(
        ref.id,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;
      final out = File(p.join(into.path, ref.name));
      final sink = out.openWrite();
      await media.stream.pipe(sink);
      return out;
    } on Object catch (e) {
      _wrap(e);
    }
  }

  @override
  Future<void> delete(DriveFileRef ref) async {
    try {
      await (await _api()).files.delete(ref.id);
    } on Object catch (e) {
      _wrap(e);
    }
  }
}

class DriveBackupOutcome {
  const DriveBackupOutcome.ok(this.fileName)
      : problem = null,
        detail = '';
  const DriveBackupOutcome.failed(this.problem, [this.detail = '']) : fileName = null;

  final String? fileName;
  final DriveProblem? problem;
  final String detail;

  bool get isOk => problem == null;
}

/// Upload / list / fetch of the existing encrypted `.pkb`. Restore itself
/// goes through the same [BackupService] preview/merge/replace path.
class DriveBackupService {
  DriveBackupService(this._backup, this._client, this._settings, this._secrets, this._clock);

  final BackupService _backup;
  final DriveClient _client;
  final SettingsRepository _settings;
  final SecretStore _secrets;
  final Clock _clock;

  static const passphraseKey = 'drive_backup_passphrase';
  static const keepLatest = 5;

  /// Turns Drive backup on. A passphrase is required: the file is encrypted
  /// before it ever leaves the device.
  Future<void> enable({required String passphrase}) async {
    if (passphrase.trim().isEmpty) {
      throw const DriveException(DriveProblem.passphraseMissing);
    }
    await _client.signIn();
    await _secrets.write(passphraseKey, passphrase);
    final s = await _settings.read();
    await _settings.save(s.copyWith(driveEnabled: true, clearDriveError: true));
  }

  Future<void> disable() async {
    await _secrets.delete(passphraseKey);
    final s = await _settings.read();
    await _settings.save(s.copyWith(driveEnabled: false, clearDriveError: true));
    try {
      await _client.signOut();
    } on Object {
      // Signing out is best effort.
    }
  }

  /// Uploads a fresh encrypted backup. On failure the "last backup" time is
  /// left untouched so the normal backup reminder keeps firing.
  Future<DriveBackupOutcome> backupNow() async {
    final before = await _settings.read();
    final pass = await _secrets.read(passphraseKey);
    if (pass == null || pass.isEmpty) {
      return _fail(before, const DriveException(DriveProblem.passphraseMissing));
    }
    File? file;
    try {
      file = await _backup.create(passphrase: pass);
      final ref = await _client.upload(file, name: p.basename(file.path));
      final s = await _settings.read();
      await _settings.save(s.copyWith(
        driveLastSuccessMs: _clock.now().millisecondsSinceEpoch,
        clearDriveError: true,
      ));
      await _prune();
      return DriveBackupOutcome.ok(ref.name);
    } on DriveException catch (e) {
      return _fail(before, e);
    } on Object catch (e) {
      return _fail(before, DriveException(DriveProblem.other, '$e'));
    } finally {
      if (file != null && file.existsSync()) await file.delete();
    }
  }

  Future<DriveBackupOutcome> _fail(ShopSettings before, DriveException e) async {
    // BackupService.create stamps lastBackupAt; a failed upload is not a backup.
    final s = await _settings.read();
    await _settings.save(before.lastBackupAtMs == null
        ? s.copyWith(clearLastBackup: true, driveLastError: e.problem.name)
        : s.copyWith(
            lastBackupAtMs: before.lastBackupAtMs,
            driveLastError: e.problem.name,
          ));
    return DriveBackupOutcome.failed(e.problem, e.detail);
  }

  Future<void> _prune() async {
    try {
      final all = await _client.list();
      for (final old in all.skip(keepLatest)) {
        await _client.delete(old);
      }
    } on Object {
      // Pruning is best effort; the upload already succeeded.
    }
  }

  Future<List<DriveFileRef>> backups() => _client.list();

  /// Downloads a Drive backup to a temp file for the normal restore flow.
  Future<File> fetch(DriveFileRef ref) async {
    final dir = Directory((await PathProviderPlatform.instance.getTemporaryPath())!);
    await dir.create(recursive: true);
    return _client.download(ref, dir);
  }
}

final driveClientProvider = Provider<DriveClient>((ref) => GoogleDriveClient());

final driveBackupServiceProvider = Provider<DriveBackupService>((ref) => DriveBackupService(
      ref.watch(backupServiceProvider),
      ref.watch(driveClientProvider),
      ref.watch(settingsRepositoryProvider),
      ref.watch(secretStoreProvider),
      ref.watch(clockProvider),
    ));
