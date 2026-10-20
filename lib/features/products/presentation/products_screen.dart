import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/features/products/application/product_repository.dart';
import 'package:parcel_khata/l10n/l10n.dart';
import 'package:parcel_khata/shared/empty_state.dart';
import 'package:parcel_khata/shared/status_chip.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final products = ref.watch(productsProvider(_q));
    return Scaffold(
      appBar: AppBar(title: Text(l.products)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/products/new'),
        icon: const Icon(LucideIcons300.plus),
        label: Text(l.productNew),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: InputDecoration(
                prefixIcon: const Icon(LucideIcons300.search), hintText: l.searchProducts),
            onChanged: (v) => setState(() => _q = v),
          ),
        ),
        Expanded(
          child: products.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (rows) => rows.isEmpty
                ? EmptyState(
                    icon: LucideIcons300.package,
                    title: _q.isEmpty ? l.emptyDefaultTitle : l.noResults)
                : ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final p = rows[i];
                      return ListTile(
                        title: Text(p.name),
                        subtitle: Text(Money(p.defaultSellPrice).format()),
                        trailing: p.defaultCostPrice == null
                            ? StatusChip(
                                label: l.costMissing,
                                icon: LucideIcons300.triangleAlert,
                                tone: StatusTone.warning)
                            : (p.isActive ? null : Text(l.archivedBadge)),
                        onTap: () => context.push('/products/${p.id}/edit'),
                      );
                    },
                  ),
          ),
        ),
      ]),
    );
  }
}
