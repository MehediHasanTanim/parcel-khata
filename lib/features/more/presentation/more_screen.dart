import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:parcel_khata/app/debug_menu.dart';
import 'package:parcel_khata/l10n/l10n.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.moreTitle)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.people_outline),
            title: Text(l.customers),
            onTap: () => context.push('/customers'),
          ),
          ListTile(
            leading: const Icon(Icons.inventory_2_outlined),
            title: Text(l.products),
            onTap: () => context.push('/products'),
          ),
          ListTile(
            leading: const Icon(Icons.local_shipping_outlined),
            title: Text(l.couriers),
            onTap: () => context.push('/couriers'),
          ),
          ListTile(
            leading: const Icon(Icons.insights),
            title: Text(l.reportsTitle),
            onTap: () => context.push('/reports'),
          ),
          ListTile(
            leading: const Icon(Icons.assignment_return_outlined),
            title: Text(l.returnsTitle),
            onTap: () => context.push('/returns'),
          ),
          ListTile(
            leading: const Icon(Icons.warning_amber),
            title: Text(l.fixMissingCosts),
            onTap: () => context.push('/orders/cost-missing'),
          ),
          ListTile(
            leading: const Icon(Icons.chat_outlined),
            title: Text(l.messageTemplates),
            onTap: () => context.push('/templates'),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: Text(l.digestSettings),
            onTap: () => context.push('/settings/notifications'),
          ),
          ListTile(
            leading: const Icon(Icons.storage_outlined),
            title: Text(l.dataSection),
            onTap: () => context.push('/settings/data'),
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: Text(l.settings),
            onTap: () => context.push('/settings'),
          ),
          if (DebugMenuScreen.enabled)
            ListTile(
              leading: const Icon(Icons.bug_report_outlined),
              title: Text(l.debugMenu),
              onTap: () => context.push('/debug'),
            ),
        ],
      ),
    );
  }
}
