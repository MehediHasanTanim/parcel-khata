import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:parcel_khata/l10n/l10n.dart';

/// Bottom navigation: Home - Orders - COD - More. "New order" is the
/// extended FAB on Home and Orders (design: S-04, S-06).
class ShellScaffold extends StatelessWidget {
  const ShellScaffold({required this.shell, super.key});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Theme.of(context).colorScheme.onSurface)),
        ),
        child: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
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
                icon: const Icon(Icons.payments_outlined),
                selectedIcon: const Icon(Icons.payments),
                label: l.navCod),
            NavigationDestination(
                icon: const Icon(Icons.more_horiz),
                selectedIcon: const Icon(Icons.more),
                label: l.navMore),
          ],
        ),
      ),
    );
  }
}
