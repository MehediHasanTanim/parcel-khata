import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:parcel_khata/features/customers/application/customer_repository.dart';
import 'package:parcel_khata/features/customers/presentation/risk_widgets.dart';
import 'package:parcel_khata/l10n/l10n.dart';
import 'package:parcel_khata/shared/empty_state.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final customers = ref.watch(customerSearchProvider(_query));
    return Scaffold(
      appBar: AppBar(title: Text(l.customers)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/customers/new'),
        icon: const Icon(Icons.person_add),
        label: Text(l.customerNew),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: l.searchCustomers,
            ),
            // Debounce is unnecessary: queries are local and indexed.
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Expanded(
          child: customers.when(
            data: (rows) => rows.isEmpty
                ? EmptyState(
                    icon: Icons.people_outline,
                    title: _query.isEmpty ? l.emptyDefaultTitle : l.noResults)
                : ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final c = rows[i];
                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(c.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.phonePrimary),
                            RiskBadgesInline(customerId: c.id),
                          ],
                        ),
                        trailing: c.isArchived ? Text(l.archivedBadge) : null,
                        onTap: () => context.push('/customers/${c.id}'),
                      );
                    },
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
          ),
        ),
      ]),
    );
  }
}
