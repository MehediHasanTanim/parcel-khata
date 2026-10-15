import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parcel_khata/core/db/app_database.dart';
import 'package:parcel_khata/core/db/providers.dart';
import 'package:parcel_khata/core/ids/uuid_v7.dart';
import 'package:parcel_khata/core/providers.dart';
import 'package:parcel_khata/core/time/clock.dart';
import 'package:parcel_khata/core/time/providers.dart';
import 'package:parcel_khata/features/orders/domain/order_filter.dart';

class SavedViewItem {
  const SavedViewItem({
    required this.id,
    required this.name,
    required this.filter,
    required this.sort,
    required this.isDefault,
  });

  final String id;
  final String name;
  final OrderFilter filter;
  final OrderSort sort;

  /// Shipped with the app: cannot be renamed or deleted.
  final bool isDefault;
}

class SavedViewRepository {
  SavedViewRepository(this._db, this._ids, this._clock, this._shopId);

  final AppDatabase _db;
  final UuidV7 _ids;
  final Clock _clock;
  final String _shopId;

  /// Defaults first (names are localized in the UI via [defaultNameKey]),
  /// then the user's own views.
  Stream<List<SavedViewItem>> watch() {
    return (_db.select(_db.savedViews)
          ..where((v) => v.shopId.equals(_shopId) & v.deletedAt.isNull())
          ..orderBy([(v) => OrderingTerm.asc(v.createdAt)]))
        .watch()
        .map((rows) => [
              for (final e in DefaultViews.filters.entries)
                SavedViewItem(
                  id: e.key,
                  name: e.key,
                  filter: e.value,
                  sort: OrderSort.newest,
                  isDefault: true,
                ),
              for (final r in rows)
                SavedViewItem(
                  id: r.id,
                  name: r.name,
                  filter: OrderFilter.decode(r.filterJson),
                  sort: OrderSort.values.firstWhere(
                    (s) => s.name == r.sort,
                    orElse: () => OrderSort.newest,
                  ),
                  isDefault: false,
                ),
            ]);
  }

  Future<String> create(String name, OrderFilter filter, OrderSort sort) async {
    final now = _clock.now();
    final id = _ids.generate();
    await _db.into(_db.savedViews).insert(SavedViewsCompanion.insert(
          id: id,
          shopId: _shopId,
          createdAt: now,
          updatedAt: now,
          name: name.trim(),
          filterJson: Value(filter.encode()),
          sort: Value(sort.name),
        ));
    return id;
  }

  Future<void> rename(String id, String name) =>
      (_db.update(_db.savedViews)..where((v) => v.id.equals(id))).write(
        SavedViewsCompanion(name: Value(name.trim()), updatedAt: Value(_clock.now())),
      );

  Future<void> delete(String id) =>
      (_db.update(_db.savedViews)..where((v) => v.id.equals(id))).write(
        SavedViewsCompanion(deletedAt: Value(_clock.now()), updatedAt: Value(_clock.now())),
      );
}

final savedViewRepositoryProvider = Provider<SavedViewRepository>((ref) => SavedViewRepository(
      ref.watch(databaseProvider),
      ref.watch(uuidProvider),
      ref.watch(clockProvider),
      ref.watch(shopIdProvider),
    ));

final savedViewsProvider = StreamProvider<List<SavedViewItem>>(
    (ref) => ref.watch(savedViewRepositoryProvider).watch());
