import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/features/orders/application/order_repository.dart';
import 'package:parcel_khata/features/profit/application/profit_input_builder.dart';
import 'package:parcel_khata/features/profit/domain/profit_calculator.dart';
import 'package:parcel_khata/features/returns/application/return_service.dart';
import 'package:parcel_khata/l10n/l10n.dart';
import 'package:parcel_khata/shared/status_chip.dart';

String profitStateLabel(AppLocalizations l, ProfitState s) => switch (s) {
      ProfitState.provisional => l.stateProvisional,
      ProfitState.finalised => l.stateFinal,
      ProfitState.incomplete => l.stateIncomplete,
    };

StatusTone profitStateTone(ProfitState s) => switch (s) {
      ProfitState.provisional => StatusTone.warning,
      ProfitState.finalised => StatusTone.success,
      ProfitState.incomplete => StatusTone.neutral,
    };

IconData profitStateIcon(ProfitState s) => switch (s) {
      ProfitState.provisional => Icons.hourglass_empty,
      ProfitState.finalised => Icons.verified_outlined,
      ProfitState.incomplete => Icons.help_outline,
    };

String _costLabel(AppLocalizations l, CostKind k) => switch (k) {
      CostKind.cogs => l.costCogs,
      CostKind.goodsLoss => l.costGoodsLoss,
      CostKind.deliveryFee => l.chargeDeliveryFee,
      CostKind.codFee => l.chargeCodFee,
      CostKind.returnFee => l.chargeReturnFee,
      CostKind.packaging => l.chargePackaging,
      CostKind.writeOff => l.writtenOffAmount,
      CostKind.other => l.chargeOther,
    };

/// Itemized profit with Provisional / Final / Incomplete state (spec F8).
class ProfitPanel extends ConsumerWidget {
  const ProfitPanel({required this.detail, super.key});

  final OrderDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final t = Theme.of(context);
    return FutureBuilder<ReturnView?>(
      future: ref.read(returnServiceProvider).forOrder(detail.order.id),
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) return const SizedBox.shrink();
        final view = snap.data;
        final r = ProfitCalculator.compute(ProfitInputBuilder.build(
          order: detail.order,
          lines: detail.lines,
          charges: detail.charges,
          returnLines: view?.lines ?? const [],
          hasReturnRecord: view != null,
        ));
        Widget row(String k, String v, {bool bold = false, Color? color, bool expected = false}) =>
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Expanded(
                  child: Text(expected ? '$k (${l.expected})' : k,
                      style: bold ? t.textTheme.titleSmall : null),
                ),
                Text(v,
                    style: (bold ? t.textTheme.titleMedium : null)?.copyWith(color: color)),
              ]),
            );
        final help = switch (r.state) {
          ProfitState.provisional => l.helpProvisional,
          ProfitState.finalised => l.helpFinal,
          ProfitState.incomplete =>
            '${l.helpIncomplete} ${l.missingCostFor}: ${r.missingCostLines.join(', ')}',
        };
        final neg = r.net.isNegative;
        return Card(
          margin: const EdgeInsets.only(bottom: 20),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(l.profitTitle, style: t.textTheme.titleMedium)),
                StatusChip(
                  label: profitStateLabel(l, r.state),
                  icon: profitStateIcon(r.state),
                  tone: profitStateTone(r.state),
                ),
              ]),
              const SizedBox(height: 4),
              Text(help, style: t.textTheme.bodySmall),
              const SizedBox(height: 8),
              row(l.profitRevenue, r.revenue.format()),
              row(l.profitDelivery, r.deliveryCharge.format()),
              row(l.profitGross, r.grossCollected.format(), bold: true),
              const Divider(),
              for (final c in r.costs)
                row('− ${_costLabel(l, c.kind)}', c.amount.format(), expected: c.isExpected),
              const Divider(),
              row(
                l.profitNet,
                r.state == ProfitState.incomplete ? '—' : r.net.format(),
                bold: true,
                color: r.state == ProfitState.incomplete
                    ? null
                    : (neg ? t.colorScheme.error : null),
              ),
              if (r.marginBp != null && r.state != ProfitState.incomplete)
                row(l.marginLabel, '${(r.marginBp! / 100).toStringAsFixed(1)}%'),
              if (r.usesExpectedCosts && r.state != ProfitState.incomplete)
                Text(l.expectedFeesNote, style: t.textTheme.bodySmall),
            ]),
          ),
        );
      },
    );
  }
}

/// Compact chip for list rows: green/red amount, grey when incomplete.
class ProfitChip extends StatelessWidget {
  const ProfitChip({required this.profit, required this.stateDb, super.key});

  final int? profit;
  final String? stateDb;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (profit == null || stateDb == null) return const SizedBox.shrink();
    if (stateDb == ProfitState.incomplete.dbValue) {
      return StatusChip(
          label: l.stateIncomplete, icon: Icons.help_outline, tone: StatusTone.neutral);
    }
    final provisional = stateDb == ProfitState.provisional.dbValue;
    final loss = profit! < 0;
    return StatusChip(
      label: '${Money(profit!).format()}${provisional ? ' *' : ''}',
      icon: loss ? Icons.trending_down : Icons.trending_up,
      tone: loss ? StatusTone.danger : StatusTone.success,
    );
  }
}
