import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parcel_khata/core/db/app_database.dart';
import 'package:parcel_khata/core/db/providers.dart';
import 'package:parcel_khata/core/providers.dart';
import 'package:parcel_khata/core/time/clock.dart';
import 'package:parcel_khata/core/time/providers.dart';
import 'package:parcel_khata/features/settings/domain/shop_settings.dart';

class SettingsRepository {
  SettingsRepository(this._db, this._clock, this._shopId);

  final AppDatabase _db;
  final Clock _clock;
  final String _shopId;

  /// Creates the single shop row if missing.
  Future<void> ensureShop() async {
    final existing = await (_db.select(_db.shops)
          ..where((s) => s.id.equals(_shopId)))
        .getSingleOrNull();
    if (existing != null) return;
    final now = _clock.now();
    await _db.into(_db.shops).insert(ShopsCompanion.insert(
          id: _shopId,
          shopId: _shopId,
          createdAt: now,
          updatedAt: now,
          settingsJson: Value(const ShopSettings().encode()),
        ));
  }

  Stream<ShopSettings> watch() {
    return (_db.select(_db.shops)..where((s) => s.id.equals(_shopId)))
        .watchSingleOrNull()
        .map((r) => ShopSettings.decode(r?.settingsJson));
  }

  Future<ShopSettings> read() async {
    final r = await (_db.select(_db.shops)..where((s) => s.id.equals(_shopId)))
        .getSingleOrNull();
    return ShopSettings.decode(r?.settingsJson);
  }

  Future<void> save(ShopSettings settings) async {
    await ensureShop();
    await (_db.update(_db.shops)..where((s) => s.id.equals(_shopId))).write(
      ShopsCompanion(
        name: Value(settings.businessName),
        phone: Value(settings.businessPhone.isEmpty ? null : settings.businessPhone),
        settingsJson: Value(settings.encode()),
        updatedAt: Value(_clock.now()),
      ),
    );
  }
}

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) =>
    SettingsRepository(ref.watch(databaseProvider), ref.watch(clockProvider),
        ref.watch(shopIdProvider)));

final shopSettingsProvider = StreamProvider<ShopSettings>(
    (ref) => ref.watch(settingsRepositoryProvider).watch());
