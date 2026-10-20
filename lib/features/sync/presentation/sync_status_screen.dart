import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';
import 'package:parcel_khata/features/orders/presentation/order_labels.dart';
import 'package:parcel_khata/features/sync/application/role_providers.dart';
import 'package:parcel_khata/features/sync/application/sync_engine.dart';
import 'package:parcel_khata/features/sync/application/sync_status_provider.dart';
import 'package:parcel_khata/l10n/l10n.dart';
import 'package:parcel_khata/shared/blueprint.dart';
import 'package:parcel_khata/shared/sync_pill.dart';

/// S-49: state, last sync, pending count and the conflict list.
class SyncStatusScreen extends ConsumerWidget {
  const SyncStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final status = ref.watch(syncStatusProvider);
    final conflicts = ref.watch(syncConflictsProvider).value ?? const [];
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.syncTitle)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(syncStatusProvider)
            ..invalidate(syncConflictsProvider);
        },
        child: ListView(padding: const EdgeInsets.all(16), children: [
          status.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('$e'),
            data: (s) => s.phase == SyncPhase.disabled
                ? _off(context, l)
                : _on(context, ref, s, conflicts),
          ),
          const SizedBox(height: 16),
          Text(l.syncOfflineNote, style: t.textTheme.bodySmall),
        ]),
      ),
    );
  }

  Widget _off(BuildContext context, AppLocalizations l) => Blueprint(
        allCorners: true,
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Icon(LucideIcons300.cloudOff, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.syncOffTitle, style: Theme.of(context).textTheme.titleMedium),
              Text(l.syncOffBody),
            ]),
          ),
        ]),
      );

  Widget _on(BuildContext context, WidgetRef ref, SyncStatus s,
      List<Map<String, Object?>> conflicts) {
    final l = context.l10n;
    final t = Theme.of(context);
    final p = syncPresentation(context, s);
    Widget kv(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Flexible(child: Text(k)),
            const SizedBox(width: 8),
            Text(v, style: t.textTheme.titleMedium),
          ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: p.color.withValues(alpha: 0.12),
          border: Border.all(color: p.color),
        ),
        child: Row(children: [
          Icon(p.icon, color: p.color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(p.label,
                style: TextStyle(color: p.color, fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      kv(l.syncLastSync, s.lastSyncAt == null ? l.syncNever : formatDateTime(s.lastSyncAt!)),
      kv(l.syncPendingChanges, '${s.pending}'),
      const SizedBox(height: 12),
      Text(l.syncConflictsTitle, style: t.textTheme.titleMedium),
      const SizedBox(height: 8),
      if (conflicts.isEmpty)
        Text(l.syncNoConflicts)
      else
        for (final c in conflicts)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text('${c['kind']}'),
              subtitle: Text('${c['tbl']} · ${c['detail']}'),
              trailing: TextButton(
                onPressed: () async {
                  await ref.read(syncEngineProvider).resolveConflict(c['id']! as String);
                  ref
                    ..invalidate(syncConflictsProvider)
                    ..invalidate(syncStatusProvider);
                },
                child: Text(l.syncMarkResolved),
              ),
            ),
          ),
    ]);
  }
}
