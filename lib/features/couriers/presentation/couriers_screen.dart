import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:parcel_khata/features/couriers/application/courier_repository.dart';
import 'package:parcel_khata/l10n/l10n.dart';
import 'package:parcel_khata/shared/empty_state.dart';

class CouriersScreen extends ConsumerWidget {
  const CouriersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final couriers = ref.watch(couriersProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.couriers)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/couriers/new'),
        icon: const Icon(Icons.add),
        label: Text(l.courierNew),
      ),
      body: couriers.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (rows) => rows.isEmpty
            ? EmptyState(icon: Icons.local_shipping_outlined, title: l.emptyDefaultTitle)
            : ListView.separated(
                itemCount: rows.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final c = rows[i];
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.local_shipping)),
                    title: Text(c.name),
                    subtitle: Text(c.phone ?? ''),
                    trailing: c.isActive ? null : Text(l.archivedBadge),
                    onTap: () => context.push('/couriers/${c.id}/edit'),
                  );
                },
              ),
      ),
    );
  }
}
