import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:parcel_khata/core/ads/ads_policy.dart';
import 'package:parcel_khata/shared/ad_slot.dart';
import 'package:parcel_khata/shared/ads_providers.dart';
import 'package:parcel_khata/app/debug_menu.dart';
import 'package:parcel_khata/features/sync/application/role_providers.dart';
import 'package:parcel_khata/features/sync/domain/permissions.dart';
import 'package:parcel_khata/l10n/l10n.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.moreTitle)),
      body: Column(children: [
        Expanded(
          child: ListView(
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
          if (ref.watch(canProvider(Capability.viewReports)))
          ListTile(
            leading: const Icon(Icons.insights),
            title: Text(l.reportsTitle),
            onTap: () => context.push('/reports'),
          ),
          if (ref.watch(canProvider(Capability.manageExpenses)))
          ListTile(
            leading: const Icon(Icons.payments_outlined),
            title: Text(l.expensesTitle),
            onTap: () => context.push('/expenses'),
          ),
          if (ref.watch(canProvider(Capability.manageExpenses)))
          ListTile(
            leading: const Icon(Icons.campaign_outlined),
            title: Text(l.campaignsTitle),
            onTap: () => context.push('/campaigns'),
          ),
          if (ref.watch(canProvider(Capability.manageReturns)))
          ListTile(
            leading: const Icon(Icons.assignment_return_outlined),
            title: Text(l.returnsTitle),
            onTap: () => context.push('/returns'),
          ),
          if (ref.watch(canProvider(Capability.viewCostAndProfit)))
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
          if (ref.watch(canProvider(Capability.manageSettings)))
          ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: Text(l.digestSettings),
            onTap: () => context.push('/settings/notifications'),
          ),
          if (ref.watch(canProvider(Capability.manageSettings)))
          ListTile(
            leading: const Icon(Icons.security_outlined),
            title: Text(l.secTitle),
            onTap: () => context.push('/settings/security'),
          ),
          if (ref.watch(canProvider(Capability.manageSettings)))
          ListTile(
            leading: const Icon(Icons.storage_outlined),
            title: Text(l.dataSection),
            onTap: () => context.push('/settings/data'),
          ),
          if (ref.watch(canProvider(Capability.manageSettings)))
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: Text(l.settings),
            onTap: () => context.push('/settings'),
          ),
          if (ref.watch(canProvider(Capability.viewActivity)))
            ListTile(
              leading: const Icon(Icons.history),
              title: Text(l.activityTitle),
              onTap: () => context.push('/settings/activity'),
            ),
          if (DebugMenuScreen.enabled)
            ListTile(
              leading: const Icon(Icons.bug_report_outlined),
              title: Text(l.debugMenu),
              onTap: () => context.push('/debug'),
            ),
          // Required by the consent platform when a privacy form exists.
          if (ref.watch(privacyOptionsRequiredProvider).value ?? false)
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: Text(l.adsPrivacyChoices),
              onTap: () => ref.read(adsServiceProvider).showPrivacyOptions(),
            ),
        ],
      ),
        ),
        const AdSlot(AdPlacement.moreFooter),
      ]),
    );
  }
}
