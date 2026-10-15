import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parcel_khata/features/sync/application/role_providers.dart';
import 'package:parcel_khata/features/sync/domain/permissions.dart';
import 'package:parcel_khata/l10n/l10n.dart';

/// Shows [child] only when the signed-in role may perform [action]; otherwise
/// a plain "not available for your role" page (or [fallback]). UX only: the
/// server rejects the same writes and never sends the data.
class PermissionGate extends ConsumerWidget {
  const PermissionGate({required this.action, required this.child, this.fallback, super.key});

  final Capability action;
  final Widget child;
  final Widget? fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(canProvider(action))) return child;
    return fallback ??
        Scaffold(
          appBar: AppBar(),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.lock_outline, size: 48),
                const SizedBox(height: 12),
                Text(context.l10n.notAllowedForRole, textAlign: TextAlign.center),
              ]),
            ),
          ),
        );
  }
}

/// Inline version for widgets inside a page.
class Can extends ConsumerWidget {
  const Can(this.action, {required this.child, this.otherwise = const SizedBox.shrink(), super.key});

  final Capability action;
  final Widget child;
  final Widget otherwise;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(canProvider(action)) ? child : otherwise;
}
