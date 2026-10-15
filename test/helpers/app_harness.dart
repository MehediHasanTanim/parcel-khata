import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_khata/core/db/app_database.dart';
import 'package:parcel_khata/core/db/providers.dart';
import 'package:parcel_khata/features/reminders/application/digest_service.dart';
import 'package:parcel_khata/features/security/application/secret_store.dart';
import 'package:parcel_khata/features/settings/application/settings_repository.dart';
import 'package:parcel_khata/features/settings/domain/shop_settings.dart';

/// Notifications plugin is not available in widget tests.
class FakeDigestNotifier implements DigestNotifier {
  @override
  Future<void> cancel() async {}
  @override
  Future<void> init() async {}
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> schedule({required DateTime at, required String title, required String body}) async {}
}

/// In-memory app with onboarding done, ready for widget tests.
Future<ProviderContainer> bootTestApp({bool onboardingDone = true}) async {
  // Each test owns its own in-memory database on purpose.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final c = ProviderContainer(overrides: [
    databaseProvider.overrideWith((ref) {
      final db = AppDatabase.memory();
      ref.onDispose(db.close);
      return db;
    }),
    secretStoreProvider.overrideWithValue(MemorySecretStore()),
    digestNotifierProvider.overrideWithValue(FakeDigestNotifier()),
  ]);
  final repo = c.read(settingsRepositoryProvider);
  await repo.ensureShop();
  await repo.save(ShopSettings(onboardingDone: onboardingDone));
  return c;
}

/// Unmount, dispose and let drift's zero-duration cleanup timers run so the
/// test framework sees no pending timers.
Future<void> shutDown(WidgetTester t, ProviderContainer c) async {
  await t.pumpWidget(const SizedBox());
  c.dispose();
  await t.pump(Duration.zero);
  await t.pump(const Duration(milliseconds: 1));
}
