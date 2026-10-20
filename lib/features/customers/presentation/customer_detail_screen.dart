import 'package:flutter/material.dart';
import 'package:parcel_khata/shared/blueprint.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:parcel_khata/core/db/app_database.dart';
import 'package:parcel_khata/features/customers/application/customer_repository.dart';
import 'package:parcel_khata/features/orders/presentation/order_labels.dart';
import 'package:parcel_khata/features/profit/application/profit_queries.dart';
import 'package:parcel_khata/features/customers/presentation/risk_widgets.dart';
import 'package:parcel_khata/l10n/l10n.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

final _customerProvider = FutureProvider.family<Customer?, String>(
    (ref, id) => ref.watch(customerRepositoryProvider).getById(id));

final _statsProvider = FutureProvider.family<CustomerStats, String>(
    (ref, id) => ref.watch(profitQueriesProvider).customerStats(id));

final _addressesProvider = StreamProvider.family<List<CustomerAddress>, String>(
    (ref, id) => ref.watch(customerRepositoryProvider).watchAddresses(id));

class CustomerDetailScreen extends ConsumerWidget {
  const CustomerDetailScreen({required this.customerId, super.key});

  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final customer = ref.watch(_customerProvider(customerId));
    final addresses = ref.watch(_addressesProvider(customerId));
    return Scaffold(
      appBar: AppBar(
        title: Text(customer.value?.name ?? l.customers),
        actions: [
          IconButton(
            tooltip: l.edit,
            icon: const Icon(LucideIcons300.pencil),
            onPressed: () async {
              await context.push('/customers/$customerId/edit');
              ref.invalidate(_customerProvider(customerId));
            },
          ),
        ],
      ),
      body: customer.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (c) {
          if (c == null) return const SizedBox.shrink();
          return ListView(children: [
            ListTile(
                leading: const Icon(LucideIcons300.phone),
                title: Text(c.phonePrimary),
                subtitle: Text(l.fieldPhone)),
            if (c.phoneAlt != null)
              ListTile(
                  leading: const Icon(LucideIcons300.phoneForwarded),
                  title: Text(c.phoneAlt!),
                  subtitle: Text(l.fieldPhoneAlt)),
            if (c.whatsapp != null)
              ListTile(
                  leading: const Icon(LucideIcons300.messageSquare),
                  title: Text(c.whatsapp!),
                  subtitle: Text(l.fieldWhatsapp)),
            if (c.notes != null)
              ListTile(leading: const Icon(LucideIcons300.textAlignStart), title: Text(c.notes!)),
            RiskSection(
              customer: c,
              onChanged: () => ref.invalidate(_customerProvider(customerId)),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l.addresses, style: Theme.of(context).textTheme.titleMedium),
            ),
            ...addresses.value?.map((a) => ListTile(
                      leading: Icon(a.isDefault ? LucideIcons300.star : LucideIcons300.mapPin),
                      title: Text(a.fullText),
                      subtitle: Text([a.label, a.area, a.district]
                          .whereType<String>()
                          .where((s) => s.isNotEmpty)
                          .join(' · ')),
                    )) ??
                const [],
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _StatsCard(stats: ref.watch(_statsProvider(customerId)).value),
            ),
            ListTile(
              leading: const Icon(LucideIcons300.receiptText),
              title: Text(l.ordersTitle),
              trailing: const Icon(LucideIcons300.chevronRight),
              onTap: () => context.push('/customers/$customerId/orders'),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton.icon(
                icon: Icon(c.isArchived ? LucideIcons300.archiveRestore : LucideIcons300.archive),
                label: Text(c.isArchived ? l.unarchive : l.archive),
                onPressed: () async {
                  final repo = ref.read(customerRepositoryProvider);
                  c.isArchived ? await repo.unarchive(c.id) : await repo.archive(c.id);
                  ref.invalidate(_customerProvider(customerId));
                },
              ),
            ),
          ]);
        },
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats});

  final CustomerStats? stats;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = stats;
    if (s == null) return const SizedBox.shrink();
    Widget cell(String k, String v) => Expanded(
          child: Column(children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(v,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20)),
            ),
            Text(k, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
          ]),
        );
    return Blueprint(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.customerSummary, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(children: [
            cell(l.ordersTotal, '${s.orders}'),
            cell(l.deliveredPct, '${s.deliveredPct.round()}%'),
            cell(l.returnedPct, '${s.returnedPct.round()}%'),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            cell(l.lifetimeRevenue, s.revenue.format()),
            cell(l.lifetimeProfit, s.profit.format()),
            cell(l.lastOrderOn, s.lastOrderAt == null ? '—' : formatDate(s.lastOrderAt!)),
          ]),
        ]),
      ),
    );
  }
}
