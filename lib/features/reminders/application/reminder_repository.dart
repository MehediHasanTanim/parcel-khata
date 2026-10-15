import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parcel_khata/core/db/app_database.dart';
import 'package:parcel_khata/core/db/providers.dart';
import 'package:parcel_khata/core/ids/uuid_v7.dart';
import 'package:parcel_khata/core/providers.dart';
import 'package:parcel_khata/core/time/clock.dart';
import 'package:parcel_khata/core/time/providers.dart';
import 'package:parcel_khata/features/reminders/domain/needs_attention.dart';

/// Snooze / dismiss state for queue items (feature spec F11).
class ReminderRepository {
  ReminderRepository(this._db, this._ids, this._clock, this._shopId);

  final AppDatabase _db;
  final UuidV7 _ids;
  final Clock _clock;
  final String _shopId;

  Stream<Map<String, ReminderState>> watchStates() {
    return (_db.select(_db.reminders)
          ..where((r) => r.shopId.equals(_shopId) & r.deletedAt.isNull()))
        .watch()
        .map(_toMap);
  }

  Future<Map<String, ReminderState>> states() async => _toMap(
        await (_db.select(_db.reminders)
              ..where((r) => r.shopId.equals(_shopId) & r.deletedAt.isNull()))
            .get(),
      );

  Map<String, ReminderState> _toMap(List<Reminder> rows) => {
        for (final r in rows)
          r.key: ReminderState(
            snoozedUntil: r.snoozedUntil,
            dismissed: r.dismissedAt != null,
          ),
      };

  /// Hides the item for [days] days; it comes back on that date.
  Future<void> snooze(AttentionItem item, int days) =>
      _upsert(item, snoozedUntil: _clock.now().add(Duration(days: days)));

  Future<void> dismiss(AttentionItem item, String reason) =>
      _upsert(item, dismissedAt: _clock.now(), reason: reason);

  /// Brings every snoozed/dismissed item back (used by tests and settings).
  Future<void> clearAll() async {
    await (_db.delete(_db.reminders)..where((r) => r.shopId.equals(_shopId))).go();
  }

  Future<void> _upsert(
    AttentionItem item, {
    DateTime? snoozedUntil,
    DateTime? dismissedAt,
    String? reason,
  }) async {
    final now = _clock.now();
    final existing = await (_db.select(_db.reminders)
          ..where((r) => r.shopId.equals(_shopId) & r.key.equals(item.key) & r.deletedAt.isNull()))
        .getSingleOrNull();
    if (existing == null) {
      await _db.into(_db.reminders).insert(RemindersCompanion.insert(
            id: _ids.generate(),
            shopId: _shopId,
            createdAt: now,
            updatedAt: now,
            key: item.key,
            kind: item.kind.name,
            orderId: Value(item.order?.orderId),
            snoozedUntil: Value(snoozedUntil),
            dismissedAt: Value(dismissedAt),
            dismissReason: Value(reason),
          ));
    } else {
      await (_db.update(_db.reminders)..where((r) => r.id.equals(existing.id))).write(
        RemindersCompanion(
          snoozedUntil: Value(snoozedUntil),
          dismissedAt: Value(dismissedAt),
          dismissReason: Value(reason),
          updatedAt: Value(now),
        ),
      );
    }
  }
}

final reminderRepositoryProvider = Provider<ReminderRepository>((ref) => ReminderRepository(
      ref.watch(databaseProvider),
      ref.watch(uuidProvider),
      ref.watch(clockProvider),
      ref.watch(shopIdProvider),
    ));
