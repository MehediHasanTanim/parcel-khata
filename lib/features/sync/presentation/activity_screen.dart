import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parcel_khata/core/db/providers.dart';
import 'package:parcel_khata/features/orders/presentation/order_labels.dart';
import 'package:parcel_khata/l10n/l10n.dart';

class _Entry {
  const _Entry(this.at, this.actor, this.entity, this.action, this.money);
  final DateTime at;
  final String actor;
  final String entity;
  final String action;
  final bool money;
}

/// Entities / actions whose audit rows affect money.
bool _isMoney(String entity, String action) =>
    const {'payout', 'return', 'expense', 'campaign'}.contains(entity) ||
    action.contains('collected') ||
    action.contains('actual_charge') ||
    action.contains('writeoff') ||
    action == 'reverse';

final _entriesProvider = FutureProvider.autoDispose<List<_Entry>>((ref) async {
  final db = ref.watch(databaseProvider);
  final rows = await db
      .customSelect('SELECT entity, action, at, actor_user_id FROM audit_log ORDER BY at DESC LIMIT 500')
      .get();
  return [
    for (final r in rows)
      _Entry(
        DateTime.fromMillisecondsSinceEpoch(r.read<int>('at') * 1000),
        r.read<String>('actor_user_id'),
        r.read<String>('entity'),
        r.read<String>('action'),
        _isMoney(r.read<String>('entity'), r.read<String>('action')),
      ),
  ];
});

/// Owner screen: who did what, with filters. Entries come from the audit log
/// written by every mutation (each carries the signing-in user's id; empty =
/// the local owner). When sync is on, the server's own log is authoritative
/// (`SyncEngine.fetchActivity`).
class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  String? _actor;
  bool _moneyOnly = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final async = ref.watch(_entriesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.activityTitle)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (all) {
          final actors = {for (final e in all) e.actor}.toList()..sort();
          final rows = [
            for (final e in all)
              if ((_actor == null || e.actor == _actor) && (!_moneyOnly || e.money)) e,
          ];
          return Column(children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(spacing: 8, runSpacing: 4, children: [
                ChoiceChip(
                  label: Text(l.activityAllActors),
                  selected: _actor == null,
                  onSelected: (_) => setState(() => _actor = null),
                ),
                for (final a in actors)
                  ChoiceChip(
                    label: Text(a.isEmpty ? l.activityYou : a),
                    selected: _actor == a,
                    onSelected: (_) => setState(() => _actor = a),
                  ),
                FilterChip(
                  label: Text(l.activityMoneyOnly),
                  selected: _moneyOnly,
                  onSelected: (v) => setState(() => _moneyOnly = v),
                ),
              ]),
            ),
            Expanded(
              child: rows.isEmpty
                  ? Center(child: Text(l.activityNone))
                  : ListView.separated(
                      itemCount: rows.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final e = rows[i];
                        return ListTile(
                          dense: true,
                          leading: Icon(e.money ? Icons.payments_outlined : Icons.edit_note),
                          title: Text('${e.entity} · ${e.action}'),
                          subtitle: Text(
                              '${e.actor.isEmpty ? l.activityYou : e.actor} · ${formatDateTime(e.at)}'),
                          trailing: e.money ? Chip(label: Text(l.activityMoney)) : null,
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
