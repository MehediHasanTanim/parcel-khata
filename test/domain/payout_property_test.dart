import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/features/cod/domain/ledger.dart';
import 'package:parcel_khata/features/cod/domain/payout_reconciler.dart';

/// Property tests for the reconciliation invariants (implementation plan
/// §5.6.1). Fixed seeds keep failures reproducible.
void main() {
  const cases = 1500;

  ({Map<String, OrderLedgerState> states, Map<String, String> courierOf, Map<String, DateTime?> delivered})
      world(Random rnd) {
    final n = 1 + rnd.nextInt(12);
    final states = <String, OrderLedgerState>{};
    final courierOf = <String, String>{};
    final delivered = <String, DateTime?>{};
    for (var i = 0; i < n; i++) {
      final collected = Money(rnd.nextInt(500000) + 10000);
      final ded = Money(rnd.nextInt(30000));
      var st = OrderLedgerState(collected: collected, deductions: ded);
      // Some orders are already partly settled.
      if (rnd.nextInt(4) == 0 && st.outstanding.poisha > 100) {
        st = st.copyWith(settled: Money(rnd.nextInt(st.outstanding.poisha)));
      }
      states['o$i'] = st;
      courierOf['o$i'] = 'c${rnd.nextInt(3)}';
      delivered['o$i'] =
          rnd.nextInt(10) == 0 ? null : DateTime.utc(2026, 9, 1 + rnd.nextInt(28));
    }
    return (states: states, courierOf: courierOf, delivered: delivered);
  }

  List<ReconcileOrder> pending(String courier, Map<String, OrderLedgerState> st,
      Map<String, String> courierOf, Map<String, DateTime?> delivered) {
    return [
      for (final e in st.entries)
        if (courierOf[e.key] == courier && e.value.outstanding.poisha > 0)
          ReconcileOrder(
            id: e.key,
            deliveredAt: delivered[e.key],
            outstanding: e.value.outstanding,
            isDisputed: e.value.isDisputed,
          ),
    ];
  }

  Money pendingTotal(String courier, Map<String, OrderLedgerState> st,
          Map<String, String> courierOf) =>
      st.entries
          .where((e) => courierOf[e.key] == courier)
          .fold(Money.zero, (s, e) => s + e.value.outstanding);

  test('random payouts keep every invariant ($cases cases)', () {
    for (var seed = 0; seed < cases; seed++) {
      final rnd = Random(seed);
      final w = world(rnd);
      final courier = 'c${rnd.nextInt(3)}';
      final orders = pending(courier, w.states, w.courierOf, w.delivered);
      if (orders.isEmpty) continue;

      final expected = PayoutReconciler.expectedTotal(orders);
      // received in [10%, 130%] of expected
      final received = Money((expected.poisha * (10 + rnd.nextInt(121)) / 100).round().clamp(1, 1 << 40));
      final lines = PayoutReconciler.autoAllocate(orders, received);
      final allocated = lines.fold(Money.zero, (s, l) => s + l.amount);

      // Cash beyond all outstanding cannot be placed without overpayment.
      final surplus = received - allocated;
      final policy = ShortfallPolicy.values[rnd.nextInt(3)];
      final allowOver = surplus.poisha > 0;
      var requested = lines;
      if (allowOver) {
        // Put the surplus on the last order as an explicit overpayment.
        final last = lines.last;
        requested = [
          ...lines.sublist(0, lines.length - 1),
          AllocationLine(last.orderId, last.amount + surplus),
        ];
      }
      final result = PayoutReconciler.plan(
        orders: orders,
        allocations: requested,
        totalReceived: received,
        policy: policy,
        allowOverpayment: allowOver,
      );
      expect(result.isOk, isTrue, reason: 'seed $seed: ${result.error}');
      final plan = result.plan!;

      // INV 1: all cash accounted for.
      expect(plan.totalApplied, received, reason: 'seed $seed cash');

      final before = Map<String, OrderLedgerState>.of(w.states);
      final after = PayoutReconciler.apply(w.states, plan);

      // INV 2: no order is over-settled unless flagged as overpayment.
      for (final a in plan.allocations) {
        final st = after[a.orderId]!;
        if (!plan.overpaymentIds.contains(a.orderId)) {
          expect(st.outstanding.poisha, greaterThanOrEqualTo(0),
              reason: 'seed $seed over-settled ${a.orderId}');
        }
      }

      // INV 3: write-off clears every selected order's balance.
      if (policy == ShortfallPolicy.writeOff) {
        for (final o in orders) {
          expect(after[o.id]!.outstanding.poisha, lessThanOrEqualTo(0),
              reason: 'seed $seed writeoff ${o.id}');
        }
      }
      // INV 4: dispute flags exactly the orders still owed.
      if (policy == ShortfallPolicy.dispute) {
        for (final o in orders) {
          final owed = after[o.id]!.outstanding.poisha > 0;
          expect(after[o.id]!.isDisputed, owed || o.isDisputed,
              reason: 'seed $seed dispute ${o.id}');
        }
      }
      // INV 5: orders not in the payout are untouched.
      for (final e in before.entries) {
        if (!orders.any((o) => o.id == e.key)) {
          expect(after[e.key], e.value, reason: 'seed $seed untouched ${e.key}');
        }
      }
      // INV 6: courier pending total moves by exactly cash + write-offs.
      final wo = plan.writeOffs.fold(Money.zero, (s, l) => s + l.amount);
      expect(
        pendingTotal(courier, after, w.courierOf),
        pendingTotal(courier, before, w.courierOf) - received - wo,
        reason: 'seed $seed pending total',
      );
      // INV 7: reversal round trip restores the exact state.
      expect(PayoutReconciler.reverse(after, plan), before, reason: 'seed $seed reverse');
    }
  });

  test('sum of per-order outstanding equals the courier pending total', () {
    for (var seed = 0; seed < 300; seed++) {
      final w = world(Random(seed + 10000));
      for (final c in ['c0', 'c1', 'c2']) {
        final viaOrders = w.states.entries
            .where((e) => w.courierOf[e.key] == c)
            .map((e) => e.value.netReceivable - e.value.settled - e.value.writtenOff)
            .fold(Money.zero, (s, m) => s + m);
        expect(pendingTotal(c, w.states, w.courierOf), viaOrders);
      }
    }
  });

  test('auto-allocation never exceeds outstanding or received', () {
    for (var seed = 0; seed < 500; seed++) {
      final rnd = Random(seed + 20000);
      final w = world(rnd);
      final orders = pending('c0', w.states, w.courierOf, w.delivered);
      final total = Money(rnd.nextInt(2000000) + 1);
      final lines = PayoutReconciler.autoAllocate(orders, total);
      final sum = lines.fold(Money.zero, (s, l) => s + l.amount);
      expect(sum <= total, isTrue);
      for (final l in lines) {
        final o = orders.firstWhere((x) => x.id == l.orderId);
        expect(l.amount <= o.outstanding, isTrue);
      }
      // Greedy: unless everything is covered, all cash is used.
      if (sum < total) {
        expect(sum, PayoutReconciler.expectedTotal(orders));
      }
    }
  });

  test('two sequential payouts then reversing both returns to start', () {
    for (var seed = 0; seed < 300; seed++) {
      final rnd = Random(seed + 30000);
      final w = world(rnd);
      final start = Map<String, OrderLedgerState>.of(w.states);
      var cur = start;
      final plans = <SettlementPlan>[];
      for (var k = 0; k < 2; k++) {
        final orders = pending('c0', cur, w.courierOf, w.delivered);
        if (orders.isEmpty) break;
        final total = Money(max(1, PayoutReconciler.expectedTotal(orders).poisha ~/ 2));
        final lines = PayoutReconciler.autoAllocate(orders, total);
        final r = PayoutReconciler.plan(
          orders: orders,
          allocations: lines,
          totalReceived: total,
          policy: ShortfallPolicy.dispute,
        );
        expect(r.isOk, isTrue);
        plans.add(r.plan!);
        cur = PayoutReconciler.apply(cur, r.plan!);
      }
      for (final p in plans.reversed) {
        cur = PayoutReconciler.reverse(cur, p);
      }
      expect(cur, start, reason: 'seed $seed');
    }
  });
}
