import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';
import 'package:meta/meta.dart';

enum BackupProblem {
  notABackup,
  corrupted,
  checksumMismatch,
  newerSchema,
  wrongPassphrase,
  passphraseRequired,
}

class BackupFormatException implements Exception {
  const BackupFormatException(this.problem);
  final BackupProblem problem;
  @override
  String toString() => 'BackupFormatException($problem)';
}

@immutable
class BackupManifest {
  const BackupManifest({
    required this.schemaVersion,
    required this.createdAt,
    required this.counts,
    required this.dbSha256,
    required this.attachmentCount,
    this.formatVersion = 1,
  });

  final int formatVersion;
  final int schemaVersion;
  final DateTime createdAt;

  /// e.g. {orders: 120, customers: 40, ...} shown in the restore preview.
  final Map<String, int> counts;
  final String dbSha256;
  final int attachmentCount;

  Map<String, Object?> toJson() => {
        'app': 'parcel_khata',
        'formatVersion': formatVersion,
        'schemaVersion': schemaVersion,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'counts': counts,
        'dbSha256': dbSha256,
        'attachmentCount': attachmentCount,
      };

  factory BackupManifest.fromJson(Map<String, dynamic> j) => BackupManifest(
        formatVersion: j['formatVersion'] as int? ?? 1,
        schemaVersion: j['schemaVersion'] as int,
        createdAt: DateTime.parse(j['createdAt'] as String),
        counts: {
          for (final e in (j['counts'] as Map<String, dynamic>).entries)
            e.key: e.value as int,
        },
        dbSha256: j['dbSha256'] as String,
        attachmentCount: j['attachmentCount'] as int? ?? 0,
      );
}

class UnpackedBackup {
  const UnpackedBackup(this.manifest, this.db, this.attachments);
  final BackupManifest manifest;
  final Uint8List db;

  /// Relative path (e.g. `attachments/<order>/<file>.jpg`) -> bytes.
  final Map<String, Uint8List> attachments;
}

/// Backup container: a zip of `manifest.json`, `db.sqlite` and attachments,
/// optionally wrapped in AES-256-GCM with a PBKDF2 passphrase key.
abstract final class BackupCodec {
  static const _magic = [0x50, 0x4B, 0x42, 0x4B, 0x31]; // "PKBK1"
  static const _kdfIterations = 120000;

  static String sha256Hex(List<int> bytes) => crypto.sha256.convert(bytes).toString();

  static Uint8List pack({
    required Uint8List db,
    required Map<String, Uint8List> attachments,
    required int schemaVersion,
    required Map<String, int> counts,
    required DateTime createdAt,
  }) {
    final manifest = BackupManifest(
      schemaVersion: schemaVersion,
      createdAt: createdAt,
      counts: counts,
      dbSha256: sha256Hex(db),
      attachmentCount: attachments.length,
    );
    final a = Archive()
      ..addFile(ArchiveFile.bytes('manifest.json', utf8.encode(jsonEncode(manifest.toJson()))))
      ..addFile(ArchiveFile.bytes('db.sqlite', db));
    for (final e in attachments.entries) {
      a.addFile(ArchiveFile.bytes(e.key, e.value));
    }
    return Uint8List.fromList(ZipEncoder().encode(a));
  }

  /// Validates structure, schema compatibility and checksum.
  static UnpackedBackup unpack(Uint8List zip, {required int currentSchemaVersion}) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(zip);
    } on Object {
      throw const BackupFormatException(BackupProblem.notABackup);
    }
    ArchiveFile? find(String name) {
      for (final f in archive) {
        if (f.name == name) return f;
      }
      return null;
    }

    final m = find('manifest.json');
    final d = find('db.sqlite');
    if (m == null || d == null) throw const BackupFormatException(BackupProblem.notABackup);
    final BackupManifest manifest;
    try {
      manifest = BackupManifest.fromJson(
        jsonDecode(utf8.decode(m.content)) as Map<String, dynamic>,
      );
    } on Object {
      throw const BackupFormatException(BackupProblem.corrupted);
    }
    if (manifest.schemaVersion > currentSchemaVersion) {
      throw const BackupFormatException(BackupProblem.newerSchema);
    }
    final db = Uint8List.fromList(d.content);
    if (sha256Hex(db) != manifest.dbSha256) {
      throw const BackupFormatException(BackupProblem.checksumMismatch);
    }
    final attachments = <String, Uint8List>{};
    for (final f in archive) {
      if (f.isFile && f.name.startsWith('attachments/')) {
        attachments[f.name] = Uint8List.fromList(f.content);
      }
    }
    return UnpackedBackup(manifest, db, attachments);
  }

  static bool isEncrypted(Uint8List data) {
    if (data.length < _magic.length) return false;
    for (var i = 0; i < _magic.length; i++) {
      if (data[i] != _magic[i]) return false;
    }
    return true;
  }

  static Future<SecretKey> _key(String passphrase, List<int> salt) {
    final kdf = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _kdfIterations,
      bits: 256,
    );
    return kdf.deriveKeyFromPassword(password: passphrase, nonce: salt);
  }

  static Future<Uint8List> encrypt(Uint8List data, String passphrase, {Random? random}) async {
    final rnd = random ?? Random.secure();
    final salt = List<int>.generate(16, (_) => rnd.nextInt(256));
    final algo = AesGcm.with256bits();
    final box = await algo.encrypt(
      data,
      secretKey: await _key(passphrase, salt),
      nonce: algo.newNonce(),
    );
    return Uint8List.fromList([..._magic, ...salt, ...box.concatenation()]);
  }

  static Future<Uint8List> decrypt(Uint8List data, String passphrase) async {
    if (!isEncrypted(data)) throw const BackupFormatException(BackupProblem.notABackup);
    const head = 5 + 16;
    if (data.length < head + 12 + 16) {
      throw const BackupFormatException(BackupProblem.corrupted);
    }
    final salt = data.sublist(5, head);
    final algo = AesGcm.with256bits();
    try {
      final box = SecretBox.fromConcatenation(
        data.sublist(head),
        nonceLength: 12,
        macLength: 16,
      );
      final clear = await algo.decrypt(box, secretKey: await _key(passphrase, salt));
      return Uint8List.fromList(clear);
    } on SecretBoxAuthenticationError {
      throw const BackupFormatException(BackupProblem.wrongPassphrase);
    }
  }
}
