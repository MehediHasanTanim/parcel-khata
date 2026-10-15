import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_khata/features/backup/domain/backup_codec.dart';

void main() {
  final created = DateTime.utc(2026, 10, 15);
  final db = Uint8List.fromList(List.generate(5000, (i) => i % 251));

  Uint8List pack({int schema = 7, Map<String, Uint8List>? att}) => BackupCodec.pack(
        db: db,
        attachments: att ?? {'attachments/o1/a.jpg': Uint8List.fromList([1, 2, 3])},
        schemaVersion: schema,
        counts: {'orders': 12, 'customers': 4},
        createdAt: created,
      );

  test('pack/unpack round trip keeps db, attachments and manifest', () {
    final u = BackupCodec.unpack(pack(), currentSchemaVersion: 7);
    expect(u.db, db);
    expect(u.attachments.keys, ['attachments/o1/a.jpg']);
    expect(u.manifest.counts['orders'], 12);
    expect(u.manifest.schemaVersion, 7);
    expect(u.manifest.attachmentCount, 1);
    expect(u.manifest.createdAt, created);
  });

  test('older schema is accepted (migrated on restore)', () {
    expect(BackupCodec.unpack(pack(schema: 3), currentSchemaVersion: 7).manifest.schemaVersion, 3);
  });

  test('newer schema is rejected', () {
    expect(
      () => BackupCodec.unpack(pack(schema: 9), currentSchemaVersion: 7),
      throwsA(isA<BackupFormatException>()
          .having((e) => e.problem, 'problem', BackupProblem.newerSchema)),
    );
  });

  test('not a zip / missing parts / checksum mismatch', () {
    expect(
      () => BackupCodec.unpack(Uint8List.fromList([1, 2, 3, 4]), currentSchemaVersion: 7),
      throwsA(isA<BackupFormatException>()
          .having((e) => e.problem, 'problem', BackupProblem.notABackup)),
    );
    final empty = Uint8List.fromList(ZipEncoder().encode(Archive()..addFile(ArchiveFile.bytes('x', [1]))));
    expect(
      () => BackupCodec.unpack(empty, currentSchemaVersion: 7),
      throwsA(isA<BackupFormatException>()),
    );
    // Tamper with the db after packing.
    final a = ZipDecoder().decodeBytes(pack());
    final out = Archive();
    for (final f in a) {
      out.addFile(f.name == 'db.sqlite'
          ? ArchiveFile.bytes('db.sqlite', [...db.sublist(1), 99])
          : ArchiveFile.bytes(f.name, f.content));
    }
    expect(
      () => BackupCodec.unpack(Uint8List.fromList(ZipEncoder().encode(out)), currentSchemaVersion: 7),
      throwsA(isA<BackupFormatException>()
          .having((e) => e.problem, 'problem', BackupProblem.checksumMismatch)),
    );
  });

  test('corrupted manifest', () {
    final out = Archive()
      ..addFile(ArchiveFile.bytes('manifest.json', utf8.encode('{nope')))
      ..addFile(ArchiveFile.bytes('db.sqlite', db));
    expect(
      () => BackupCodec.unpack(Uint8List.fromList(ZipEncoder().encode(out)), currentSchemaVersion: 7),
      throwsA(isA<BackupFormatException>()
          .having((e) => e.problem, 'problem', BackupProblem.corrupted)),
    );
  });

  group('encryption', () {
    test('round trip and detection', () async {
      final zip = pack();
      expect(BackupCodec.isEncrypted(zip), isFalse);
      final enc = await BackupCodec.encrypt(zip, 'correct horse');
      expect(BackupCodec.isEncrypted(enc), isTrue);
      expect(enc.length, greaterThan(zip.length));
      final dec = await BackupCodec.decrypt(enc, 'correct horse');
      expect(dec, zip);
      expect(BackupCodec.unpack(dec, currentSchemaVersion: 7).db, db);
    });

    test('wrong passphrase is a typed error, not garbage', () async {
      final enc = await BackupCodec.encrypt(pack(), 'right');
      await expectLater(
        BackupCodec.decrypt(enc, 'wrong'),
        throwsA(isA<BackupFormatException>()
            .having((e) => e.problem, 'problem', BackupProblem.wrongPassphrase)),
      );
    });

    test('two encryptions of the same data differ (random salt/nonce)', () async {
      final a = await BackupCodec.encrypt(pack(), 'p');
      final b = await BackupCodec.encrypt(pack(), 'p');
      expect(a, isNot(b));
    });

    test('truncated data is corrupted', () async {
      final enc = await BackupCodec.encrypt(pack(), 'p');
      await expectLater(
        BackupCodec.decrypt(Uint8List.sublistView(enc, 0, 30), 'p'),
        throwsA(isA<BackupFormatException>()),
      );
    });
  });
}
