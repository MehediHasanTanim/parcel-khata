import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/features/expenses/domain/ad_allocator.dart';
import 'package:parcel_khata/features/expenses/domain/business_pnl.dart';
import 'package:parcel_khata/features/orders/domain/order_enums.dart';

CampaignOrder co(String id, {int weight = 0, OrderStatus status = OrderStatus.delivered, List<String> tags = const ['eid'], DateTime? date}) =>
    CampaignOrder(
      id: id,
      orderDate: date ?? DateTime(2026, 10, 5),
      status: status,
      tags: tags,
      weight: weight,
    );

int sum(Map<String, Money> m) => m.values.fold(0, (s, v) => s + v.poisha);

void main() {
  group('AdAllocator.allocate', () {
    test('by count: equal shares, remainder to the lowest ids', () {
      final r = AdAllocator.allocate(
          const Money(1000), [co('c'), co('a'), co('b')], AllocationMode.byCount);
      // 1000 / 3 = 333 rem 1
      expect(r['a']!.poisha, 334);
      expect(r['b']!.poisha, 333);
      expect(r['c']!.poisha, 333);
      expect(sum(r), 1000);
    });

    test('by revenue: proportional, largest remainder, exact total', () {
      final r = AdAllocator.allocate(
        const Money(1000),
        [co('a', weight: 100), co('b', weight: 200), co('c', weight: 700)],
        AllocationMode.byRevenue,
      );
      expect(r['a']!.poisha, 100);
      expect(r['b']!.poisha, 200);
      expect(r['c']!.poisha, 700);
    });

    test('by revenue with awkward remainders still sums exactly', () {
      final r = AdAllocator.allocate(
        const Money(10000),
        [co('a', weight: 333), co('b', weight: 333), co('c', weight: 334)],
        AllocationMode.byRevenue,
      );
      expect(sum(r), 10000);
      expect(r.values.every((m) => m.poisha >= 3330 && m.poisha <= 3340), isTrue);
    });

    test('by revenue falls back to count when every weight is zero', () {
      final r = AdAllocator.allocate(
          const Money(100), [co('a'), co('b')], AllocationMode.byRevenue);
      expect(r['a']!.poisha, 50);
      expect(r['b']!.poisha, 50);
    });

    test('no orders or no spend -> nothing', () {
      expect(AdAllocator.allocate(const Money(100), [], AllocationMode.byCount), isEmpty);
      expect(AdAllocator.allocate(Money.zero, [co('a')], AllocationMode.byCount), isEmpty);
    });

    test('tiny spend: poisha spread one by one, never negative', () {
      final r = AdAllocator.allocate(
          const Money(2), [co('a'), co('b'), co('c')], AllocationMode.byCount);
      expect(sum(r), 2);
      expect(r.values.every((m) => m.poisha >= 0), isTrue);
    });

    test('is deterministic regardless of input order', () {
      final a = AdAllocator.allocate(
          const Money(777), [co('x', weight: 5), co('y', weight: 7), co('z', weight: 11)], AllocationMode.byRevenue);
      final b = AdAllocator.allocate(
          const Money(777), [co('z', weight: 11), co('x', weight: 5), co('y', weight: 7)], AllocationMode.byRevenue);
      expect({for (final e in a.entries) e.key: e.value.poisha},
          {for (final e in b.entries) e.key: e.value.poisha});
    });

    test('property: shares always sum to spend (2000 random cases)', () {
      for (var seed = 0; seed < 2000; seed++) {
        final rnd = Random(seed);
        final n = 1 + rnd.nextInt(40);
        final orders = [
          for (var i = 0; i < n; i++)
            co('o${i.toString().padLeft(3, '0')}', weight: rnd.nextInt(5) == 0 ? 0 : rnd.nextInt(500000)),
        ];
        final spend = Money(rnd.nextInt(5000000) + 1);
        for (final mode in AllocationMode.values) {
          final r = AdAllocator.allocate(spend, orders, mode);
          expect(sum(r), spend.poisha, reason: 'seed $seed $mode');
          expect(r.length, n);
          expect(r.values.every((m) => !m.isNegative), isTrue);
        }
      }
    });

    test('property: by count shares differ by at most one poisha', () {
      for (var seed = 0; seed < 300; seed++) {
        final rnd = Random(seed + 9000);
        final n = 1 + rnd.nextInt(30);
        final r = AdAllocator.allocate(
          Money(rnd.nextInt(100000) + 1),
          [for (var i = 0; i < n; i++) co('o$i')],
          AllocationMode.byCount,
        );
        final v = r.values.map((m) => m.poisha).toList();
        expect(v.reduce(max) - v.reduce(min), lessThanOrEqualTo(1));
      }
    });

    test('property: re-allocating gives the identical result (idempotent)', () {
      final orders = [for (var i = 0; i < 17; i++) co('o$i', weight: 1000 + i * 37)];
      final once = AdAllocator.allocate(const Money(123457), orders, AllocationMode.byRevenue);
      final twice = AdAllocator.allocate(const Money(123457), orders, AllocationMode.byRevenue);
      expect({for (final e in once.entries) e.key: e.value.poisha},
          {for (final e in twice.entries) e.key: e.value.poisha});
    });
  });

  group('AdAllocator.eligible', () {
    final start = DateTime(2026, 10, 1);
    final end = DateTime(2026, 10, 11); // exclusive
    CampaignWindow w() => CampaignWindow(
          tag: 'eid',
          start: start,
          endExclusive: end,
          spend: const Money(1000),
          mode: AllocationMode.byCount,
        );

    test('requires the tag and the date window', () {
      final r = AdAllocator.eligible(w(), [
        co('in'),
        co('wrongtag', tags: const ['other']),
        co('before', date: DateTime(2026, 9, 30, 23, 59)),
        co('onStart', date: start),
        co('atEndExclusive', date: end),
        co('lastInstant', date: DateTime(2026, 10, 10, 23, 59)),
      ]);
      expect(r.map((o) => o.id), ['in', 'lastInstant', 'onStart']);
    });

    test('cancelled and draft orders do not absorb cost', () {
      final r = AdAllocator.eligible(w(), [
        co('x', status: OrderStatus.cancelled),
        co('y', status: OrderStatus.draft),
        co('z', status: OrderStatus.returned),
      ]);
      expect(r.map((o) => o.id), ['z']);
    });
  });

  group('BusinessPnlCalculator', () {
    OrderPnlRow row(String id, {int rev = 1000, int cogs = 600, int fees = 70, int loss = 0, int wo = 0, int pack = 10, int ads = 0, int other = 0, bool counted = true}) {
      final net = rev - cogs - fees - loss - wo - pack - ads - other;
      return OrderPnlRow(
        orderId: id,
        revenue: Money(rev),
        cogs: Money(cogs),
        courierFees: Money(fees),
        goodsLoss: Money(loss),
        writeOff: Money(wo),
        packaging: Money(pack),
        ads: Money(ads),
        other: Money(other),
        net: Money(net),
        counted: counted,
      );
    }

    test('business profit = order profit - unallocated expenses', () {
      final p = BusinessPnlCalculator.compute(
        [row('a'), row('b', ads: 50)],
        [
          const ExpenseRow(amount: Money(300), category: ExpenseCategory.rent),
          const ExpenseRow(amount: Money(100), category: ExpenseCategory.salary),
        ],
      );
      expect(p.orderProfit.poisha, (1000 - 600 - 70 - 10) + (1000 - 600 - 70 - 10 - 50));
      expect(p.unallocatedExpenses.poisha, 400);
      expect(p.businessProfit, p.orderProfit - p.unallocatedExpenses);
      expect(p.ads.poisha, 50);
    });

    test('revenue minus costs reconciles to order profit', () {
      final p = BusinessPnlCalculator.compute(
        [row('a', loss: 40, wo: 5, other: 3), row('b', ads: 20)],
        const [],
      );
      expect(p.revenue - p.costsTotal, p.orderProfit);
    });

    test('allocated campaign spend is not subtracted twice', () {
      final p = BusinessPnlCalculator.compute(
        [row('a', ads: 100)],
        [
          const ExpenseRow(
              amount: Money(100), category: ExpenseCategory.ads, allocatedToOrders: true),
          const ExpenseRow(amount: Money(40), category: ExpenseCategory.misc),
        ],
      );
      expect(p.unallocatedExpenses.poisha, 40);
      expect(p.expensesByCategory.containsKey(ExpenseCategory.ads), isFalse);
      expect(p.businessProfit.poisha, p.orderProfit.poisha - 40);
    });

    test('incomplete orders are counted separately and not summed', () {
      final p = BusinessPnlCalculator.compute(
        [row('a'), row('b', counted: false)],
        const [],
      );
      expect(p.orderCount, 1);
      expect(p.incompleteCount, 1);
      expect(p.orderProfit.poisha, 320);
    });

    test('unallocated ads spend (campaign not applied yet) is a business cost', () {
      final p = BusinessPnlCalculator.compute(
        [row('a')],
        [const ExpenseRow(amount: Money(500), category: ExpenseCategory.ads)],
      );
      expect(p.expensesByCategory[ExpenseCategory.ads]!.poisha, 500);
      expect(p.businessProfit.poisha, 320 - 500);
    });
  });
}
