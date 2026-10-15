import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/features/cod/domain/ledger.dart';
import 'package:parcel_khata/features/cod/domain/payout_reconciler.dart';

ReconcileOrder o(String id, int outstanding, {int day = 1, bool disputed = false}) =>
    ReconcileOrder(
      id: id,
      orderNo: id,
      deliveredAt: DateTime.utc(2026, 10, day),
      outstanding: Money.taka(outstanding),
      isDisputed: disputed,
    );

AllocationLine a(String id, int amt) => AllocationLine(id, Money.taka(amt));

void main() {
  group('autoAllocate', () {
    test('oldest delivered first, capped by outstanding', () {
      final orders = [o('c', 300, day: 3), o('a', 500, day: 1), o('b', 400, day: 2)];
      final r = PayoutReconciler.autoAllocate(orders, const Money.taka(700));
      expect(r.map((x) => x.orderId), ['a', 'b']);
      expect(r[0].amount, const Money.taka(500));
      expect(r[1].amount, const Money.taka(200));
    });

    test('lump sum across 15 orders settles all (scenario 6)', () {
      final orders = [for (var i = 0; i < 15; i++) o('o$i', 100 + i, day: 1 + i)];
      final total = Money.taka(orders.fold(0, (s, x) => s + x.outstanding.poisha ~/ 100));
      final lines = PayoutReconciler.autoAllocate(orders, total);
      expect(lines, hasLength(15));
      final plan = PayoutReconciler.plan(
              orders: orders, allocations: lines, totalReceived: total)
          .plan!;
      final states = {
        for (final x in orders)
          x.id: OrderLedgerState(collected: x.outstanding, deductions: Money.zero),
      };
      final after = PayoutReconciler.apply(states, plan);
      expect(after.values.every((s) => s.outstanding.isZero), isTrue);
    });

    test('extra cash is left unallocated, zero/negative outstanding skipped', () {
      final r = PayoutReconciler.autoAllocate(
          [o('a', 100), o('b', 0), o('c', -50)], const Money.taka(1000));
      expect(r.map((x) => x.orderId), ['a']);
    });
  });

  group('difference', () {
    test('zero, shortfall, surplus', () {
      final orders = [o('a', 500), o('b', 400)];
      expect(PayoutReconciler.difference(orders, const Money.taka(900)), Money.zero);
      expect(PayoutReconciler.difference(orders, const Money.taka(860)), const Money.taka(-40));
      expect(PayoutReconciler.difference(orders, const Money.taka(950)), const Money.taka(50));
    });
  });

  group('plan', () {
    final orders = [o('a', 500), o('b', 400)];

    test('exact payment settles with no policy needed', () {
      final r = PayoutReconciler.plan(
          orders: orders,
          allocations: [a('a', 500), a('b', 400)],
          totalReceived: const Money.taka(900));
      expect(r.isOk, isTrue);
      expect(r.plan!.writeOffs, isEmpty);
      expect(r.plan!.newlyDisputedIds, isEmpty);
    });

    test('shortfall without policy is rejected (F6 AC3)', () {
      final r = PayoutReconciler.plan(
          orders: orders,
          allocations: [a('a', 500), a('b', 360)],
          totalReceived: const Money.taka(860));
      expect(r.error, ReconcileError.shortfallNeedsPolicy);
    });

    test('shortfall: allocate leaves balance outstanding', () {
      final r = PayoutReconciler.plan(
          orders: orders,
          allocations: [a('a', 500), a('b', 360)],
          totalReceived: const Money.taka(860),
          policy: ShortfallPolicy.allocate);
      final p = r.plan!;
      expect(p.writeOffs, isEmpty);
      expect(p.newlyDisputedIds, isEmpty);
    });

    test('shortfall: dispute flags only orders with balance', () {
      final r = PayoutReconciler.plan(
          orders: orders,
          allocations: [a('a', 500), a('b', 360)],
          totalReceived: const Money.taka(860),
          policy: ShortfallPolicy.dispute);
      expect(r.plan!.newlyDisputedIds, {'b'});
    });

    test('already disputed order is not re-flagged', () {
      final r = PayoutReconciler.plan(
          orders: [o('a', 500, disputed: true)],
          allocations: [a('a', 400)],
          totalReceived: const Money.taka(400),
          policy: ShortfallPolicy.dispute);
      expect(r.plan!.newlyDisputedIds, isEmpty);
    });

    test('shortfall: write off records the exact remainder', () {
      final r = PayoutReconciler.plan(
          orders: orders,
          allocations: [a('a', 460), a('b', 400)],
          totalReceived: const Money.taka(860),
          policy: ShortfallPolicy.writeOff);
      expect(r.plan!.writeOffs.single.orderId, 'a');
      expect(r.plan!.writeOffs.single.amount, const Money.taka(40));
    });

    test('allocation must equal cash received', () {
      expect(
          PayoutReconciler.plan(
                  orders: orders,
                  allocations: [a('a', 500)],
                  totalReceived: const Money.taka(900),
                  policy: ShortfallPolicy.allocate)
              .error,
          ReconcileError.allocationMismatch);
      expect(
          PayoutReconciler.plan(
                  orders: orders,
                  allocations: [a('a', 500), a('b', 500)],
                  totalReceived: const Money.taka(900))
              .error,
          ReconcileError.allocationMismatch);
    });

    test('over outstanding needs explicit overpayment', () {
      final lines = [a('a', 600)];
      final bad = PayoutReconciler.plan(
          orders: [o('a', 500)],
          allocations: lines,
          totalReceived: const Money.taka(600));
      expect(bad.error, ReconcileError.exceedsOutstanding);
      final ok = PayoutReconciler.plan(
          orders: [o('a', 500)],
          allocations: lines,
          totalReceived: const Money.taka(600),
          allowOverpayment: true);
      expect(ok.plan!.overpaymentIds, {'a'});
    });

    test('input validation', () {
      expect(PayoutReconciler.plan(orders: const [], allocations: const [], totalReceived: const Money.taka(1)).error,
          ReconcileError.noOrders);
      expect(PayoutReconciler.plan(orders: orders, allocations: const [], totalReceived: Money.zero).error,
          ReconcileError.totalNotPositive);
      expect(
          PayoutReconciler.plan(
                  orders: orders,
                  allocations: [a('zzz', 10)],
                  totalReceived: const Money.taka(10))
              .error,
          ReconcileError.unknownOrder);
      expect(
          PayoutReconciler.plan(
                  orders: orders,
                  allocations: [const AllocationLine('a', Money(-100))],
                  totalReceived: const Money.taka(10))
              .error,
          ReconcileError.negativeAmount);
    });

    test('partial settlement across two payouts reaches zero', () {
      var states = {
        'a': const OrderLedgerState(collected: Money.taka(1000), deductions: Money.taka(100)),
      };
      final p1 = PayoutReconciler.plan(
        orders: [o('a', 900)],
        allocations: [a('a', 500)],
        totalReceived: const Money.taka(500),
        policy: ShortfallPolicy.allocate,
      ).plan!;
      states = PayoutReconciler.apply(states, p1);
      expect(states['a']!.outstanding, const Money.taka(400));
      final p2 = PayoutReconciler.plan(
        orders: [ReconcileOrder(id: 'a', deliveredAt: null, outstanding: states['a']!.outstanding)],
        allocations: [a('a', 400)],
        totalReceived: const Money.taka(400),
      ).plan!;
      states = PayoutReconciler.apply(states, p2);
      expect(states['a']!.outstanding, Money.zero);
    });

    test('reverse restores exact prior state (scenario 9)', () {
      final before = {
        'a': const OrderLedgerState(collected: Money.taka(1000), deductions: Money.taka(100)),
        'b': const OrderLedgerState(collected: Money.taka(500), deductions: Money.taka(60)),
      };
      final plan = PayoutReconciler.plan(
        orders: [o('a', 900), o('b', 440)],
        allocations: [a('a', 900), a('b', 400)],
        totalReceived: const Money.taka(1300),
        policy: ShortfallPolicy.dispute,
      ).plan!;
      final applied = PayoutReconciler.apply(before, plan);
      expect(applied['b']!.isDisputed, isTrue);
      expect(PayoutReconciler.reverse(applied, plan), before);
    });
  });
}
