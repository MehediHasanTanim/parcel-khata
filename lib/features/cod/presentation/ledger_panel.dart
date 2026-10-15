import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parcel_khata/core/db/app_database.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/features/cod/application/cod_queries.dart';
import 'package:parcel_khata/features/cod/application/payout_service.dart';
import 'package:parcel_khata/features/cod/domain/ledger.dart';
import 'package:parcel_khata/features/orders/domain/order_enums.dart';
import 'package:parcel_khata/features/orders/presentation/order_labels.dart';
import 'package:parcel_khata/l10n/l10n.dart';
import 'package:parcel_khata/shared/status_chip.dart';

final _settledProvider = FutureProvider.family<Money, String>((ref, orderId) {
  ref.watch(codRevisionProvider);
  return ref.watch(ledgerWriterProvider).settledFor(orderId);
});

/// Per-order COD ledger: expected, collected, itemized deductions, net,
/// received and outstanding (feature spec F6 §6.1).
class LedgerPanel extends ConsumerWidget {
  const LedgerPanel({required this.order, required this.charges, super.key});

  final Order order;
  final List<OrderCharge> charges;

  static const _deductionTypes = ['delivery_fee', 'cod_fee', 'return_fee', 'other'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final cod = CodStatus.fromDb(order.codStatus);
    if (cod == CodStatus.notApplicable) return const SizedBox.shrink();
    final status = OrderStatus.fromDb(order.status);
    final settled = ref.watch(_settledProvider(order.id)).value ?? Money.zero;
    final collected = order.codCollected == null ? null : Money(order.codCollected!);
    final hadReturn = status == OrderStatus.deliveryFailed ||
        status == OrderStatus.returnInTransit ||
        status == OrderStatus.returned;
    // An expected return fee stays hidden until something is returned.
    final live = charges
        .where((c) =>
            c.deletedAt == null &&
            (c.type != 'return_fee' || c.actualAmount != null || hadReturn))
        .toList();
    final state = collected == null
        ? null
        : LedgerCalculator.state(
            collected: collected,
            charges: [
              for (final c in live)
                ChargeAmount(
                  type: c.type,
                  expected: Money(c.expectedAmount),
                  actual: c.actualAmount == null ? null : Money(c.actualAmount!),
                ),
            ],
            settled: settled,
            isDisputed: order.isDisputed,
          );
    final service = ref.read(payoutServiceProvider);

    Widget row(String k, String v, {bool bold = false, Widget? trailing}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Expanded(
              child: Text(k,
                  style: bold ? Theme.of(context).textTheme.titleSmall : null),
            ),
            Text(v, style: bold ? Theme.of(context).textTheme.titleSmall : null),
            if (trailing != null) trailing,
          ]),
        );

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(l.ledgerTitle, style: Theme.of(context).textTheme.titleMedium),
            ),
            StatusChip(
                label: codLabel(l, cod),
                icon: Icons.payments_outlined,
                tone: codTone(cod)),
          ]),
          const SizedBox(height: 8),
          row(l.expectedCod, Money(order.codExpected).format()),
          if (state == null)
            Text(l.codPending, style: Theme.of(context).textTheme.bodySmall)
          else ...[
            row(
              l.collectedAmount,
              state.collected.format(),
              trailing: status == OrderStatus.delivered
                  ? IconButton(
                      tooltip: l.recordCollected,
                      icon: const Icon(Icons.edit, size: 18),
                      onPressed: () => _editCollected(context, ref, state.collected),
                    )
                  : null,
            ),
            for (final type in _deductionTypes)
              if (live.any((c) => c.type == type))
                () {
                  final c = live.firstWhere((c) => c.type == type);
                  final eff = Money(c.actualAmount ?? c.expectedAmount);
                  return row(
                    '− ${chargeLabel(l, type)}${c.actualAmount == null ? ' (${l.expected})' : ''}',
                    eff.format(),
                    trailing: IconButton(
                      tooltip: l.enterActual,
                      icon: const Icon(Icons.edit, size: 18),
                      onPressed: () => _editActual(context, service, type, eff),
                    ),
                  );
                }(),
            const Divider(),
            row(l.netReceivable, state.netReceivable.format(), bold: true),
            row(l.settledAmount, state.settled.format()),
            if (!state.writtenOff.isZero) row(l.writtenOffAmount, state.writtenOff.format()),
            row(l.outstandingLabel, state.outstanding.format(), bold: true),
            if (state.outstanding.poisha > 0)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _dispute(context, service, !order.isDisputed),
                  icon: Icon(order.isDisputed ? Icons.check : Icons.flag_outlined),
                  label: Text(order.isDisputed ? l.resolveDispute : l.markDispute),
                ),
              ),
          ],
        ]),
      ),
    );
  }

  Future<String?> _text(BuildContext context, String title, {String? hint}) async {
    final c = TextEditingController();
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(title),
        content: TextField(controller: c, decoration: InputDecoration(labelText: hint)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(l.confirm)),
        ],
      ),
    );
    final v = c.text;
    c.dispose();
    return ok == true ? v : null;
  }

  Future<void> _editCollected(BuildContext context, WidgetRef ref, Money current) async {
    final l = context.l10n;
    final amount = TextEditingController(text: current.format(symbol: false));
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(l.recordCollected),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: l.collectedAmount, prefixText: '৳ '),
          ),
          const SizedBox(height: 12),
          TextField(controller: reason, decoration: InputDecoration(labelText: l.collectedReason)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(l.confirm)),
        ],
      ),
    );
    final m = Money.tryParse(amount.text);
    final why = reason.text;
    amount.dispose();
    reason.dispose();
    if (ok != true || m == null || !context.mounted) return;
    final r = await ref.read(payoutServiceProvider).recordCollectedAmount(order.id, m, why);
    if (!context.mounted) return;
    final f = r.failureOrNull;
    if (f != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(f.message == 'reason_required' ? l.collectedReason : f.message)));
    }
  }

  Future<void> _editActual(
      BuildContext context, PayoutService service, String type, Money current) async {
    final l = context.l10n;
    final c = TextEditingController(text: current.format(symbol: false));
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('${l.enterActual}: ${chargeLabel(l, type)}'),
        content: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(prefixText: '৳ '),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(l.confirm)),
        ],
      ),
    );
    final m = Money.tryParse(c.text);
    c.dispose();
    if (ok != true || m == null) return;
    await service.setActualCharge(order.id, type, m);
  }

  Future<void> _dispute(BuildContext context, PayoutService service, bool dispute) async {
    final l = context.l10n;
    final note = await _text(context, dispute ? l.markDispute : l.resolveDispute,
        hint: l.disputeNote);
    if (note == null) return;
    await (dispute
        ? service.markDisputed(order.id, note)
        : service.resolveDispute(order.id, note));
  }
}
