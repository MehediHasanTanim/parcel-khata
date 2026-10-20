import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:parcel_khata/l10n/l10n.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';
import 'package:lucide_icons_flutter/lucide_icons_600.dart';

/// Bottom navigation: Home - Orders - (+) New order - COD - More.
class ShellScaffold extends StatelessWidget {
  const ShellScaffold({required this.shell, super.key});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final accent = scheme.primary;
    final onAccent = scheme.onPrimary;
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        // Destinations: 0 Home, 1 Orders, 2 (+) New order, 3 COD, 4 More.
        // The center action opens the form; it is not a branch.
        selectedIndex: shell.currentIndex < 2 ? shell.currentIndex : shell.currentIndex + 1,
        onDestinationSelected: (i) {
          if (i == 2) {
            unawaited(context.push('/orders/new'));
            return;
          }
          final branch = i < 2 ? i : i - 1;
          shell.goBranch(branch, initialLocation: branch == shell.currentIndex);
        },
        destinations: [
          NavigationDestination(
              icon: const Icon(LucideIcons300.house),
              selectedIcon: const Icon(LucideIcons300.house),
              label: l.navHome),
          NavigationDestination(
              icon: const Icon(LucideIcons300.receiptText),
              selectedIcon: const Icon(LucideIcons300.receiptText),
              label: l.navOrders),
          NavigationDestination(
              icon: _NewOrderGlyph(color: accent, onColor: onAccent),
              selectedIcon: _NewOrderGlyph(color: accent, onColor: onAccent),
              label: l.navNewOrder),
          NavigationDestination(
              icon: const Icon(LucideIcons300.banknote),
              selectedIcon: const Icon(LucideIcons300.banknote),
              label: l.navCod),
          NavigationDestination(
              icon: const Icon(LucideIcons300.ellipsis),
              selectedIcon: const Icon(LucideIcons300.ellipsis),
              label: l.navMore),
        ],
      ),
    );
  }
}

/// The centre action: an accent square, per the design's bottom bar.
class _NewOrderGlyph extends StatelessWidget {
  const _NewOrderGlyph({required this.color, required this.onColor});

  final Color color;
  final Color onColor;

  @override
  Widget build(BuildContext context) => Container(
        width: 40,
        height: 32,
        color: color,
        child: Icon(LucideIcons600.plus, color: onColor, size: 24),
      );
}
