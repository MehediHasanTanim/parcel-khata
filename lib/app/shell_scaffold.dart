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
              icon: const Icon(Icons.add_circle_outline),
              selectedIcon: const Icon(Icons.add_circle),
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
