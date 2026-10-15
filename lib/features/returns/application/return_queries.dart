import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parcel_khata/core/db/app_database.dart';
import 'package:parcel_khata/core/db/providers.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/core/providers.dart';
import 'package:parcel_khata/core/time/clock.dart';
import 'package:parcel_khata/core/time/providers.dart';
import 'package:parcel_khata/features/orders/domain/order_enums.dart';
import 'package:parcel_khata/features/settings/application/settings_repository.dart';

class ReturnRow {
  const ReturnRow({
    required this.order,
    required this.record,
    required this.daysInTransit,
    required this.overdue,
  });

  final Order order;
  final ReturnRecord? record;
  final int daysInTransit;

  /// Still not received after the configured threshold.
  final bool overdue;

  bool get received => record?.receivedBackAt != null;
  Money get loss => Money(record?.lossAmount ?? 0);
}

class ReturnQueries {
  ReturnQueries(this._db, this._clock, this._shopId);

  final AppDatabase _db;
  final Clock _clock;
  final String _shopId;

  Future<List<ReturnRow>> list({required int thresholdDays}) async {
    final o = _db.orders;
    final q = _db.select(o).join([
      leftOuterJoin(_db.returnRecords,
          _db.returnRecords.orderId.equalsExp(o.id) & _db.returnRecords.deletedAt.isNull()),
    ])
      ..where(o.shopId.equals(_shopId) &
          o.deletedAt.isNull() &
          (o.status.isIn([
                OrderStatus.deliveryFailed.dbValue,
                OrderStatus.returnInTransit.dbValue,
              ]) |
              _db.returnRecords.id.isNotNull()))
      ..orderBy([OrderingTerm.desc(o.updatedAt)]);
    final now = _clock.now();
    return [
      for (final r in await q.get())
        () {
          final order = r.readTable(o);
          final rec = r.readTableOrNull(_db.returnRecords);
          final since = rec?.initiatedAt ?? order.updatedAt;
          final days = now.difference(since).inDays;
          final received = rec?.receivedBackAt != null;
          return ReturnRow(
            order: order,
            record: rec,
            daysInTransit: days,
            overdue: !received && days >= thresholdDays,
          );
        }(),
    ];
  }
}

final returnQueriesProvider = Provider<ReturnQueries>((ref) => ReturnQueries(
      ref.watch(databaseProvider),
      ref.watch(clockProvider),
      ref.watch(shopIdProvider),
    ));

final returnThresholdProvider = Provider<int>(
    (ref) => ref.watch(shopSettingsProvider).value?.returnInTransitDays ?? 7);
