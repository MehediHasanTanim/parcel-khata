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
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

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
          _GroupHeader(l.moreGroupPeople),
          ListTile(
            leading: const Icon(LucideIcons300.users),
            title: Text(l.customers),
            onTap: () => context.push('/customers'),
          ),
          ListTile(
            leading: const Icon(LucideIcons300.package),
            title: Text(l.products),
            onTap: () => context.push('/products'),
          ),
          ListTile(
            leading: const Icon(LucideIcons300.truck),
            title: Text(l.couriers),
            onTap: () => context.push('/couriers'),
          ),
          _GroupHeader(l.moreGroupMoney),
          if (ref.watch(canProvider(Capability.viewReports)))
          ListTile(
            leading: const Icon(LucideIcons300.chartLine),
            title: Text(l.reportsTitle),
            onTap: () => context.push('/reports'),
          ),
          if (ref.watch(canProvider(Capability.manageExpenses)))
          ListTile(
            leading: const Icon(LucideIcons300.banknote),
            title: Text(l.expensesTitle),
            onTap: () => context.push('/expenses'),
          ),
          if (ref.watch(canProvider(Capability.manageExpenses)))
          ListTile(
            leading: const Icon(LucideIcons300.megaphone),
            title: Text(l.campaignsTitle),
            onTap: () => context.push('/campaigns'),
          ),
          if (ref.watch(canProvider(Capability.manageReturns)))
          ListTile(
            leading: const Icon(LucideIcons300.undo2),
            title: Text(l.returnsTitle),
            onTap: () => context.push('/returns'),
          ),
          if (ref.watch(canProvider(Capability.viewCostAndProfit)))
          ListTile(
            leading: const Icon(LucideIcons300.triangleAlert),
            title: Text(l.fixMissingCosts),
            onTap: () => context.push('/orders/cost-missing'),
          ),
          _GroupHeader(l.moreGroupComms),
          ListTile(
            leading: const Icon(LucideIcons300.messageSquare),
            title: Text(l.messageTemplates),
            onTap: () => context.push('/templates'),
          ),
          if (ref.watch(canProvider(Capability.manageSettings)))
          ListTile(
            leading: const Icon(LucideIcons300.bellRing),
            title: Text(l.digestSettings),
            onTap: () => context.push('/settings/notifications'),
          ),
          _GroupHeader(l.moreGroupSystem),
          if (ref.watch(canProvider(Capability.manageSettings)))
          ListTile(
            leading: const Icon(LucideIcons300.shield),
            title: Text(l.secTitle),
            onTap: () => context.push('/settings/security'),
          ),
          if (ref.watch(canProvider(Capability.manageSettings)))
          ListTile(
            leading: const Icon(LucideIcons300.database),
            title: Text(l.dataSection),
            onTap: () => context.push('/settings/data'),
          ),
          if (ref.watch(canProvider(Capability.manageSettings)))
          ListTile(
            leading: const Icon(LucideIcons300.settings),
            title: Text(l.settings),
            onTap: () => context.push('/settings'),
          ),
          if (ref.watch(canProvider(Capability.viewActivity)))
            ListTile(
              leading: const Icon(LucideIcons300.history),
              title: Text(l.activityTitle),
              onTap: () => context.push('/settings/activity'),
            ),
          if (DebugMenuScreen.enabled)
            ListTile(
              leading: const Icon(LucideIcons300.bug),
              title: Text(l.debugMenu),
              onTap: () => context.push('/debug'),
            ),
          // Required by the consent platform when a privacy form exists.
          if (ref.watch(privacyOptionsRequiredProvider).value ?? false)
            ListTile(
              leading: const Icon(LucideIcons300.shieldCheck),
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

class _GroupHeader extends StatelessWidget {
  const _GroupHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title,
          style: t.textTheme.labelMedium
              ?.copyWith(color: t.colorScheme.onSurface.withValues(alpha: 0.65))),
    );
  }
}
