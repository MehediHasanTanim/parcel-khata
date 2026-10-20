import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/features/profit/application/profit_queries.dart';
import 'package:parcel_khata/l10n/l10n.dart';
import 'package:parcel_khata/shared/empty_state.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

class MissingCostsScreen extends ConsumerStatefulWidget {
  const MissingCostsScreen({super.key});

  @override
  ConsumerState<MissingCostsScreen> createState() => _MissingCostsScreenState();
}

class _MissingCostsScreenState extends ConsumerState<MissingCostsScreen> {
  late Future<List<MissingCostLine>> _future;
  bool _alsoCatalog = true;

  @override
  void initState() {
    super.initState();
    _future = ref.read(profitQueriesProvider).missingCosts();
  }

  void _reload() => setState(() => _future = ref.read(profitQueriesProvider).missingCosts());

  Future<void> _enter(MissingCostLine m) async {
    final l = context.l10n;
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('${m.line.nameSnapshot} · ${m.order.orderNo}'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: l.unitCost, prefixText: '৳ '),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(l.save)),
        ],
      ),
    );
    final cost = Money.tryParse(c.text);
    c.dispose();
    if (ok != true || cost == null || cost.isNegative) return;
    await ref
        .read(profitQueriesProvider)
        .setLineCost(m.line.id, cost, updateCatalog: _alsoCatalog);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.fixMissingCosts)),
      body: FutureBuilder<List<MissingCostLine>>(
        future: _future,
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snap.data ?? const [];
          if (rows.isEmpty) {
            return EmptyState(icon: LucideIcons300.circleCheck, title: l.noMissingCosts);
          }
          return Column(children: [
            SwitchListTile(
              title: Text(l.alsoUpdateCatalog),
              value: _alsoCatalog,
              onChanged: (v) => setState(() => _alsoCatalog = v),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: rows.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final m = rows[i];
                  return ListTile(
                    title: Text(m.line.nameSnapshot),
                    subtitle: Text('${m.order.orderNo} · ${m.line.qty} × '
                        '${Money(m.line.unitSellPrice).format()}'),
                    trailing: FilledButton.tonal(
                      onPressed: () => _enter(m),
                      child: Text(l.unitCost),
                    ),
                    onTap: () => context.push('/orders/${m.order.id}'),
                  );
                },
              ),
            ),
          ]);
        },
      ),
    );
  }
}
