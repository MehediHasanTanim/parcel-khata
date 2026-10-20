import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:parcel_khata/l10n/l10n.dart';

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
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home),
              label: l.navHome),
          NavigationDestination(
              icon: const Icon(Icons.receipt_long_outlined),
              selectedIcon: const Icon(Icons.receipt_long),
              label: l.navOrders),
          NavigationDestination(
              icon: _NewOrderGlyph(color: accent, onColor: onAccent),
              selectedIcon: _NewOrderGlyph(color: accent, onColor: onAccent),
              label: l.navNewOrder),
          NavigationDestination(
              icon: const Icon(Icons.payments_outlined),
              selectedIcon: const Icon(Icons.payments),
              label: l.navCod),
          NavigationDestination(
              icon: const Icon(Icons.more_horiz),
              selectedIcon: const Icon(Icons.more),
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
        child: Icon(Icons.add, color: onColor, size: 24),
      );
}
