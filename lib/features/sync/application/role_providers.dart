import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parcel_khata/core/db/providers.dart';
import 'package:parcel_khata/core/providers.dart';
import 'package:parcel_khata/core/time/providers.dart';
import 'package:parcel_khata/features/sync/application/sync_engine.dart';
import 'package:parcel_khata/features/sync/domain/permissions.dart';

final syncEngineProvider = Provider<SyncEngine>((ref) => SyncEngine(
      db: ref.watch(databaseProvider),
      clock: ref.watch(clockProvider),
      ids: ref.watch(uuidProvider),
      shopId: ref.watch(shopIdProvider),
    ));

/// The signed-in role. Without an account (the default) this is always the
/// owner: roles are inert for local-only use. Invalidate after joining a
/// shop or being revoked.
final currentRoleProvider = FutureProvider<Role>((ref) async {
  final wire = await ref.watch(syncEngineProvider).currentRole();
  return Role.fromWire(wire) ?? Role.owner;
});

/// Client-side gating (UX only; the server enforces). Defaults to allowed
/// while the role loads so local-only users never see a flicker.
final canProvider = Provider.family<bool, Capability>((ref, action) {
  final role = ref.watch(currentRoleProvider).value ?? Role.owner;
  return can(role, action);
});
