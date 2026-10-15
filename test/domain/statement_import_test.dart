import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/features/cod/domain/ledger.dart';
import 'package:parcel_khata/features/cod/domain/payout_reconciler.dart';
import 'package:parcel_khata/features/cod/domain/statement_import.dart';

StatementOrder order(
  String id,
  String cn, {
  int collected = 1000,
  int deliveryFee = 60,
  int settled = 0,
  bool hasReturn = false,
  List<ChargeAmount>? charges,
}) =>
    StatementOrder(
      id: id,
      orderNo: 'ORD-$id',
      cn: cn,
      collected: Money.taka(collected),
      settled: Money.taka(settled),
      hasReturn: hasReturn,
      deliveredAt: DateTime(2026, 9, int.tryParse(id) ?? 1),
      charges: charges ??
          [ChargeAmount(type: 'delivery_fee', expected: Money.taka(deliveryFee))],
    );

StatementRow row(
  int n,
  String cn, {
  int? collected,
  int? delivery,
  int? cod,
  int? net,
}) =>
    StatementRow(
      row: n,
      cnRaw: cn,
      collected: collected == null ? null : Money.taka(collected),
      deliveryFee: delivery == null ? null : Money.taka(delivery),
      codFee: cod == null ? null : Money.taka(cod),
      netPayable: net == null ? null : Money.taka(net),
    );

void main() {
  group('cnKey', () {
    test('ignores case, punctuation, labels and leading zeros', () {
      expect(StatementMatcher.cnKey('DT-250812ABC'), 'dt250812abc');
      expect(StatementMatcher.cnKey(' CN: 0012345 '), '12345');
      expect(StatementMatcher.cnKey('12345'), '12345');
      expect(StatementMatcher.cnKey('০০১২'), '12');
      expect(StatementMatcher.cnKey('007A'), '007a'); // not all digits: keep
    });
  });

  group('StatementMatcher', () {
    final orders = [
      order('1', 'DT100'),
      order('2', '0123'),
      order('3', 'DT300', settled: 940), // outstanding 0
      order('4', 'DT400'),
    ];

    test('classifies every outcome', () {
      final m = StatementMatcher.match([
        row(1, 'dt100', collected: 1000),
        row(2, '123', collected: 1000), // leading zero dropped by the portal
        row(3, 'DT300', collected: 1000),
        row(4, 'DT400', collected: 800),
        row(5, 'ZZZ'),
        row(6, 'DT100'), // duplicate of row 1
        row(7, '  '),
      ], orders);
      expect(m.map((r) => r.outcome), [
        StatementOutcome.matched,
        StatementOutcome.matched,
        StatementOutcome.alreadySettled,
        StatementOutcome.amountMismatch,
        StatementOutcome.unknownCn,
        StatementOutcome.duplicateInFile,
        StatementOutcome.unknownCn,
      ]);
      expect(m[3].difference, const Money.taka(-200));
      expect(m[0].order!.id, '1');
    });

    test('tolerance boundary is inclusive', () {
      final rows = [row(1, 'DT100', collected: 1003)];
      final tight = StatementMatcher.match(rows, orders, tolerance: const Money.taka(2));
      expect(tight.single.outcome, StatementOutcome.amountMismatch);
      final loose = StatementMatcher.match(rows, orders, tolerance: const Money.taka(3));
      expect(loose.single.outcome, StatementOutcome.matched);
    });

    test('missing collected column still matches by CN', () {
      final m = StatementMatcher.match([row(1, 'DT100')], orders);
      expect(m.single.outcome, StatementOutcome.matched);
      expect(m.single.difference, isNull);
    });

    test('ambiguous CN is not guessed', () {
      final amb = [order('1', 'AB1'), order('2', 'ab-1')];
      final m = StatementMatcher.match([row(1, 'AB1')], amb);
      expect(m.single.outcome, StatementOutcome.unknownCn);
    });

    test('duplicate: the first occurrence is still evaluated', () {
      final m = StatementMatcher.match([row(1, 'DT100'), row(2, 'dt100')], orders);
      expect(m.first.outcome, StatementOutcome.matched);
      expect(m.last.outcome, StatementOutcome.duplicateInFile);
    });

    test('expected return fee is ignored for settlement state without a return', () {
      final o = order('9', 'RR9', charges: [
        const ChargeAmount(type: 'delivery_fee', expected: Money.taka(60)),
        const ChargeAmount(type: 'return_fee', expected: Money.taka(100)),
      ]);
      expect(o.outstanding, const Money.taka(940));
      expect(order('9', 'RR9', hasReturn: true, charges: o.charges).outstanding,
          const Money.taka(840));
    });
  });

  group('StatementPlanBuilder', () {
    MatchedRow matched(StatementRow r, StatementOrder o) =>
        StatementMatcher.match([r], [o]).single;

    test('actual fees change what is outstanding and the allocation', () {
      final o = order('1', 'A1'); // expected fee 60 -> outstanding 940
      final m = matched(row(1, 'A1', collected: 1000, delivery: 80, cod: 10, net: 910), o);
      final r = StatementPlanBuilder.build([StatementDecision(m)]);
      final p = r.plan!;
      expect(p.feeUpdates.map((f) => f.type), ['delivery_fee', 'cod_fee']);
      // After fees: 1000 - 80 - 10 = 910 outstanding; statement pays 910.
      expect(p.allocations.single.amount, const Money.taka(910));
      expect(p.settlement.isOk, isTrue);
      expect(p.totalReceived, const Money.taka(910));
    });

    test('never allocates more than outstanding without the overpayment flag', () {
      final o = order('1', 'A1');
      final m = matched(row(1, 'A1', collected: 1000, net: 1200), o);
      final capped = StatementPlanBuilder.build([StatementDecision(m)]).plan!;
      expect(capped.allocations.single.amount, const Money.taka(940));
      final over = StatementPlanBuilder.build([StatementDecision(m)], allowOverpayment: true)
          .plan!;
      expect(over.allocations.single.amount, const Money.taka(1200));
      expect(over.settlement.plan!.overpaymentIds, {'1'});
    });

    test('shortfall needs a policy, then the reconciler accepts it', () {
      final o = order('1', 'A1');
      final m = matched(row(1, 'A1', collected: 1000, net: 800), o);
      final noPolicy = StatementPlanBuilder.build([StatementDecision(m)]).plan!;
      expect(noPolicy.settlement.error, ReconcileError.shortfallNeedsPolicy);
      final p = StatementPlanBuilder.build([StatementDecision(m)],
              policy: ShortfallPolicy.dispute)
          .plan!;
      expect(p.settlement.plan!.newlyDisputedIds, {'1'});
    });

    test('collected adjustment needs a reason and changes outstanding', () {
      final o = order('1', 'A1');
      final m = StatementMatcher.match([row(1, 'A1', collected: 800, net: 740)], [o]).single;
      expect(m.outcome, StatementOutcome.amountMismatch);
      final bad = StatementPlanBuilder.build(
          [StatementDecision(m, adjustCollected: true)]);
      expect(bad.error, StatementPlanError.reasonRequired);
      final ok = StatementPlanBuilder.build(
          [StatementDecision(m, adjustCollected: true, reason: 'customer paid less')]).plan!;
      expect(ok.adjustments.single.amount, const Money.taka(800));
      // 800 - 60 expected delivery fee = 740
      expect(ok.allocations.single.amount, const Money.taka(740));
      expect(ok.settlement.isOk, isTrue);
    });

    test('mismatch row without adjustment pays against recorded collection', () {
      final o = order('1', 'A1');
      final m = StatementMatcher.match([row(1, 'A1', collected: 800, net: 740)], [o]).single;
      final p = StatementPlanBuilder.build([StatementDecision(m)],
              policy: ShortfallPolicy.allocate)
          .plan!;
      expect(p.allocations.single.amount, const Money.taka(740));
      expect(p.adjustments, isEmpty);
    });

    test('unknown / duplicate / settled rows cannot be applied', () {
      final o = order('1', 'A1', settled: 940);
      final settled = StatementMatcher.match([row(1, 'A1')], [o]).single;
      expect(StatementPlanBuilder.build([StatementDecision(settled)]).error,
          StatementPlanError.ineligibleRow);
      final unknown = StatementMatcher.match([row(1, 'X')], [o]).single;
      expect(StatementPlanBuilder.build([StatementDecision(unknown)]).error,
          StatementPlanError.ineligibleRow);
    });

    test('excluded rows are ignored and an empty selection is refused', () {
      final o = order('1', 'A1');
      final m = matched(row(1, 'A1', collected: 1000), o);
      expect(StatementPlanBuilder.build([StatementDecision(m, include: false)]).error,
          StatementPlanError.nothingSelected);
    });

    test('property: allocations never exceed post-update outstanding', () {
      final rnd = Random(7);
      for (var i = 0; i < 1500; i++) {
        final n = 1 + rnd.nextInt(5);
        final orders = [
          for (var k = 0; k < n; k++)
            order('${k + 1}', 'C${k + 1}',
                collected: 100 + rnd.nextInt(3000),
                deliveryFee: rnd.nextInt(150),
                settled: rnd.nextInt(60)),
        ];
        final rows = [
          for (var k = 0; k < n; k++)
            row(k + 1, 'C${k + 1}',
                collected: rnd.nextBool() ? null : 100 + rnd.nextInt(3000),
                delivery: rnd.nextBool() ? null : rnd.nextInt(200),
                cod: rnd.nextBool() ? null : rnd.nextInt(50),
                net: rnd.nextBool() ? null : rnd.nextInt(4000)),
        ];
        final matches = StatementMatcher.match(rows, orders, tolerance: const Money.taka(100000));
        final decisions = [
          for (final m in matches)
            if (m.outcome == StatementOutcome.matched) StatementDecision(m),
        ];
        if (decisions.isEmpty) continue;
        final r = StatementPlanBuilder.build(decisions, policy: ShortfallPolicy.allocate);
        final p = r.plan!;
        final byOrder = {for (final o in orders) o.id: o};
        for (final a in p.allocations) {
          final d = decisions.firstWhere((x) => x.matched.order!.id == a.orderId);
          final o = byOrder[a.orderId]!;
          var charges = [...o.charges];
          for (final f in p.feeUpdates.where((f) => f.orderId == o.id)) {
            charges = [
              for (final c in charges)
                if (c.type == f.type)
                  ChargeAmount(type: c.type, expected: c.expected, actual: f.amount)
                else
                  c,
              if (!charges.any((c) => c.type == f.type))
                ChargeAmount(type: f.type, expected: Money.zero, actual: f.amount),
            ];
          }
          final out = o.ledger(chargesOverride: charges).outstanding;
          expect(a.amount.poisha <= max(out.poisha, 0), isTrue,
              reason: 'order ${o.id}: ${a.amount} > $out (${d.matched.row.netPayable})');
          expect(a.amount.poisha > 0, isTrue);
        }
        // Whenever the reconciler accepts the plan, the sum matches the total.
        if (p.settlement.isOk) {
          expect(p.settlement.plan!.totalApplied, p.totalReceived);
        }
      }
    });
  });
}
