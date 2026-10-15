import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parcel_khata/core/db/app_database.dart';
import 'package:parcel_khata/core/db/providers.dart';
import 'package:parcel_khata/core/ids/uuid_v7.dart';
import 'package:parcel_khata/core/providers.dart';
import 'package:parcel_khata/core/time/clock.dart';
import 'package:parcel_khata/core/time/providers.dart';
import 'package:parcel_khata/features/templates/domain/message_templates.dart';

class TemplateRepository {
  TemplateRepository(this._db, this._ids, this._clock, this._shopId);

  final AppDatabase _db;
  final UuidV7 _ids;
  final Clock _clock;
  final String _shopId;

  /// The seller's edited text, or the built-in default for [lang].
  Future<String> body(TemplateKind kind, String lang) async {
    final row = await _row(kind, lang);
    return row?.body ?? MessageTemplates.defaultBody(kind, lang);
  }

  Future<bool> isCustomized(TemplateKind kind, String lang) async =>
      await _row(kind, lang) != null;

  Future<void> save(TemplateKind kind, String lang, String body) async {
    final now = _clock.now();
    final existing = await _row(kind, lang);
    if (existing == null) {
      await _db.into(_db.messageTemplateRows).insert(MessageTemplateRowsCompanion.insert(
            id: _ids.generate(),
            shopId: _shopId,
            createdAt: now,
            updatedAt: now,
            kind: kind.dbValue,
            lang: lang,
            body: body,
          ));
    } else {
      await (_db.update(_db.messageTemplateRows)..where((t) => t.id.equals(existing.id)))
          .write(MessageTemplateRowsCompanion(body: Value(body), updatedAt: Value(now)));
    }
  }

  /// Back to the built-in text.
  Future<void> reset(TemplateKind kind, String lang) async {
    await (_db.delete(_db.messageTemplateRows)
          ..where((t) =>
              t.shopId.equals(_shopId) & t.kind.equals(kind.dbValue) & t.lang.equals(lang)))
        .go();
  }

  Future<MessageTemplateRow?> _row(TemplateKind kind, String lang) =>
      (_db.select(_db.messageTemplateRows)
            ..where((t) =>
                t.shopId.equals(_shopId) &
                t.kind.equals(kind.dbValue) &
                t.lang.equals(lang) &
                t.deletedAt.isNull()))
          .getSingleOrNull();
}

final templateRepositoryProvider = Provider<TemplateRepository>((ref) => TemplateRepository(
      ref.watch(databaseProvider),
      ref.watch(uuidProvider),
      ref.watch(clockProvider),
      ref.watch(shopIdProvider),
    ));
