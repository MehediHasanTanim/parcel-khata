import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/features/orders/application/order_repository.dart';
import 'package:parcel_khata/features/orders/presentation/order_labels.dart';
import 'package:parcel_khata/features/returns/application/return_queries.dart';
import 'package:parcel_khata/l10n/l10n.dart';
import 'package:parcel_khata/shared/empty_state.dart';
import 'package:parcel_khata/shared/status_chip.dart';

final _returnRowsProvider = FutureProvider<List<ReturnRow>>((ref) async {
  // Re-run whenever orders change.
  ref.watch(_orderChangeProvider);
  return ref
      .watch(returnQueriesProvider)
      .list(thresholdDays: ref.watch(returnThresholdProvider));
});

final _orderChangeProvider = StreamProvider<int>((ref) async* {
  var n = 0;
  yield n;
  await for (final _ in ref.watch(orderRepositoryProvider).changes) {
    yield ++n;
  }
});

class ReturnsScreen extends ConsumerStatefulWidget {
  const ReturnsScreen({super.key});

  @override
  ConsumerState<ReturnsScreen> createState() => _ReturnsScreenState();
}

class _ReturnsScreenState extends ConsumerState<ReturnsScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final rows = ref.watch(_returnRowsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.returnsTitle)),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SegmentedButton<int>(
            segments: [
              ButtonSegment(value: 0, label: Text(l.tabInTransit)),
              ButtonSegment(value: 1, label: Text(l.tabNotReceived)),
              ButtonSegment(value: 2, label: Text(l.tabReceived)),
            ],
            selected: {_tab},
            onSelectionChanged: (s) => setState(() => _tab = s.first),
          ),
        ),
        Expanded(
          child: rows.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (all) {
              final shown = all.where((r) => switch (_tab) {
                    0 => !r.received,
                    1 => r.overdue,
                    _ => r.received,
                  }).toList();
              if (shown.isEmpty) {
                return EmptyState(icon: Icons.assignment_return_outlined, title: l.emptyDefaultTitle);
              }
              final loss = shown.fold(0, (s, r) => s + r.loss.poisha);
              return ListView(children: [
                if (_tab == 2 && loss > 0)
                  ListTile(
                    title: Text(l.lossAmountLabel),
                    trailing: Text(Money(loss).format()),
                  ),
                for (final r in shown)
                  ListTile(
                    title: Text(r.order.orderNo),
                    subtitle: Wrap(spacing: 6, children: [
                      Text(r.received
                          ? '${l.receivedBackOn}: ${formatDate(r.record!.receivedBackAt!)}'
                          : l.daysInTransitN(r.daysInTransit)),
                      if (r.overdue)
                        StatusChip(
                            label: l.tabNotReceived,
                            icon: Icons.schedule,
                            tone: StatusTone.danger),
                    ]),
                    trailing: r.received && r.loss.poisha > 0 ? Text(r.loss.format()) : null,
                    onTap: () => context.push('/orders/${r.order.id}'),
                  ),
              ]);
            },
          ),
        ),
      ]),
    );
  }
}
