import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:parcel_khata/features/orders/application/order_repository.dart';
import 'package:parcel_khata/features/orders/presentation/orders_screen.dart';
import 'package:parcel_khata/l10n/l10n.dart';
import 'package:parcel_khata/shared/empty_state.dart';

final _draftsProvider = StreamProvider<List<OrderListItem>>((ref) async* {
  final repo = ref.watch(orderRepositoryProvider);
  const f = OrderFilter(onlyDrafts: true);
  yield await repo.fetchPage(filter: f, limit: 200);
  await for (final _ in repo.changes) {
    yield await repo.fetchPage(filter: f, limit: 200);
  }
});

class DraftsScreen extends ConsumerWidget {
  const DraftsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final drafts = ref.watch(_draftsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.drafts)),
      body: drafts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (rows) => rows.isEmpty
            ? EmptyState(icon: Icons.edit_note, title: l.emptyDefaultTitle)
            : ListView.separated(
                itemCount: rows.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) => OrderTile(
                  item: rows[i],
                  onTap: () => context.push('/orders/${rows[i].order.id}/edit'),
                  trailing: IconButton(
                    tooltip: l.remove,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () =>
                        unawaited(ref.read(orderRepositoryProvider).softDelete(rows[i].order.id)),
                  ),
                ),
              ),
      ),
    );
  }
}
