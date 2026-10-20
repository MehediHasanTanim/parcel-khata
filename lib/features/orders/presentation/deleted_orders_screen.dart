import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parcel_khata/core/result/result.dart';
import 'package:parcel_khata/features/orders/application/order_repository.dart';
import 'package:parcel_khata/features/orders/presentation/order_labels.dart';
import 'package:parcel_khata/features/orders/presentation/orders_screen.dart';
import 'package:parcel_khata/l10n/l10n.dart';
import 'package:parcel_khata/shared/empty_state.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

final _deletedProvider = StreamProvider<List<OrderListItem>>(
    (ref) => ref.watch(orderRepositoryProvider).watchRecentlyDeleted());

class DeletedOrdersScreen extends ConsumerWidget {
  const DeletedOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final rows = ref.watch(_deletedProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.recentlyDeleted)),
      body: rows.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (items) => items.isEmpty
            ? EmptyState(icon: LucideIcons300.trash2, title: l.emptyDefaultTitle)
            : ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final it = items[i];
                  return OrderTile(
                    item: it,
                    onTap: () {},
                    trailing: TextButton(
                      onPressed: () async {
                        final m = ScaffoldMessenger.of(context);
                        final r = await ref.read(orderRepositoryProvider).restore(it.order.id);
                        final msg = r.when(
                          ok: (_) => l.restored,
                          err: (f) => f is ConflictFailure ? l.errCnTaken : f.message,
                        );
                        m.showSnackBar(SnackBar(content: Text(msg)));
                      },
                      child: Text(l.restore),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

// Keeps the formatter import used for the deleted-on subtitle in the future.
String deletedOnLabel(DateTime d) => formatDateTime(d);
