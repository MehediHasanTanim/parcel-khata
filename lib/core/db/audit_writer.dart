import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:parcel_khata/core/db/app_database.dart';
import 'package:parcel_khata/core/ids/uuid_v7.dart';
import 'package:parcel_khata/core/time/clock.dart';

/// Writes audit rows. Call inside the same transaction as the mutation.
class AuditWriter {
  AuditWriter(this._db, this._ids, this._clock, this._shopId);

  final AppDatabase _db;
  final UuidV7 _ids;
  final Clock _clock;
  final String _shopId;

  Future<void> write({
    required String entity,
    required String entityId,
    required String action,
    Map<String, Object?> payload = const {},
  }) async {
    final r = await _db
        .customSelect('SELECT user_id FROM sync_state WHERE id = 1')
        .getSingleOrNull();
    await _db.into(_db.auditLog).insert(AuditLogCompanion.insert(
          id: _ids.generate(),
          shopId: _shopId,
          entity: entity,
          entityId: entityId,
          action: action,
          payloadJson: Value(jsonEncode(payload)),
          at: _clock.now(),
          actorUserId: Value(r?.read<String>('user_id') ?? ''),
        ));
  }
}
