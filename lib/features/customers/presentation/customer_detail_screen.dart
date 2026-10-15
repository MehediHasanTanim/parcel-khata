import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:parcel_khata/core/db/app_database.dart';
import 'package:parcel_khata/features/customers/application/customer_repository.dart';
import 'package:parcel_khata/l10n/l10n.dart';

final _customerProvider = FutureProvider.family<Customer?, String>(
    (ref, id) => ref.watch(customerRepositoryProvider).getById(id));

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
            icon: const Icon(Icons.edit),
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
                leading: const Icon(Icons.phone),
                title: Text(c.phonePrimary),
                subtitle: Text(l.fieldPhone)),
            if (c.phoneAlt != null)
              ListTile(
                  leading: const Icon(Icons.phone_forwarded),
                  title: Text(c.phoneAlt!),
                  subtitle: Text(l.fieldPhoneAlt)),
            if (c.whatsapp != null)
              ListTile(
                  leading: const Icon(Icons.chat),
                  title: Text(c.whatsapp!),
                  subtitle: Text(l.fieldWhatsapp)),
            if (c.notes != null)
              ListTile(leading: const Icon(Icons.notes), title: Text(c.notes!)),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l.addresses, style: Theme.of(context).textTheme.titleMedium),
            ),
            ...addresses.value?.map((a) => ListTile(
                      leading: Icon(a.isDefault ? Icons.star : Icons.place_outlined),
                      title: Text(a.fullText),
                      subtitle: Text([a.label, a.area, a.district]
                          .whereType<String>()
                          .where((s) => s.isNotEmpty)
                          .join(' · ')),
                    )) ??
                const [],
            const Divider(),
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: Text(l.ordersTitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/customers/$customerId/orders'),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton.icon(
                icon: Icon(c.isArchived ? Icons.unarchive : Icons.archive_outlined),
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
