import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';
import 'package:parcel_khata/app/theme.dart';
import 'package:parcel_khata/features/sync/application/sync_engine.dart';
import 'package:parcel_khata/features/sync/application/sync_status_provider.dart';
import 'package:parcel_khata/l10n/l10n.dart';

/// Label, icon and colour for a sync phase (never colour alone).
({String label, IconData icon, Color color}) syncPresentation(
    BuildContext context, SyncStatus s) {
  final l = context.l10n;
  final c = Theme.of(context).extension<StatusColors>()!;
  return switch (s.phase) {
    SyncPhase.synced => (label: l.syncStateSynced, icon: LucideIcons300.check, color: c.success),
    SyncPhase.pending => (
        label: l.syncStatePending(s.pending),
        icon: LucideIcons300.circleDot,
        color: c.warning
      ),
    SyncPhase.error => (label: l.syncStateError, icon: LucideIcons300.circleAlert, color: c.danger),
    SyncPhase.revoked => (
        label: l.syncStateRevoked,
        icon: LucideIcons300.lock,
        color: c.danger
      ),
    SyncPhase.disabled => (label: l.syncOffTitle, icon: LucideIcons300.cloudOff, color: c.neutral),
  };
}

/// App-bar pill that opens the sync status screen. Hidden while sync is off
/// (local-only use), so single-device sellers never see it.
class SyncPill extends ConsumerWidget {
  const SyncPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(syncStatusProvider).value;
    if (s == null || s.phase == SyncPhase.disabled) return const SizedBox.shrink();
    final p = syncPresentation(context, s);
    // At large text sizes only the icon fits next to the bell.
    final compact = MediaQuery.textScalerOf(context).scale(1) > 1.5;
    return Semantics(
      button: true,
      label: p.label,
      child: InkWell(
        onTap: () => context.push('/settings/sync'),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: p.color.withValues(alpha: 0.12),
                border: Border.all(
                  color: p.color,
                  style: s.phase == SyncPhase.pending ? BorderStyle.solid : BorderStyle.solid,
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(p.icon, size: 14, color: p.color),
                if (!compact) ...[
                  const SizedBox(width: 4),
                  Text(p.label,
                      style: TextStyle(color: p.color, fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
