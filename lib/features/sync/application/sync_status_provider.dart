import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parcel_khata/features/sync/application/role_providers.dart';
import 'package:parcel_khata/features/sync/application/sync_engine.dart';

/// Current sync state. Refreshed by invalidating (screen open, pull to refresh);
/// no timers, so tests settle.
final syncStatusProvider = FutureProvider.autoDispose<SyncStatus>(
    (ref) => ref.watch(syncEngineProvider).status());

final syncConflictsProvider = FutureProvider.autoDispose<List<Map<String, Object?>>>(
    (ref) => ref.watch(syncEngineProvider).conflicts());
