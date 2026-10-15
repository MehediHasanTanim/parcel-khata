import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_khata/features/customers/domain/customer_risk.dart';

void main() {
  final now = DateTime(2026, 6, 30);
  const scorer = CustomerRiskScorer();
  var n = 0;
  RiskOrderFact o(RiskOutcome out,
          {int daysAgo = 10, bool cod = true, String? reason}) =>
      RiskOrderFact(
          orderId: 'o${n++}',
          orderDate: now.subtract(Duration(days: daysAgo)),
          outcome: out,
          isCod: cod,
          reason: reason);
  Set<RiskBadgeKind> kinds(List<RiskBadge> b) => b.map((x) => x.kind).toSet();
  List<RiskBadge> run(List<RiskOrderFact> f,
          {RiskThresholds t = const RiskThresholds(), bool block = false}) =>
      scorer.score(orders: f, now: now, thresholds: t, isBlocklisted: block);

  setUp(() => n = 0);

  test('no orders => new customer only', () {
    expect(kinds(run([])), {RiskBadgeKind.newCustomer});
  });

  test('in-flight orders alone are still new', () {
    expect(kinds(run([o(RiskOutcome.other)])), {RiskBadgeKind.newCustomer});
  });

  group('min-orders boundary', () {
    test('2 delivered (min 3) => no reliable, not new', () {
      expect(kinds(run([o(RiskOutcome.delivered), o(RiskOutcome.delivered)])), isEmpty);
    });
    test('3 delivered => reliable with the orders behind it', () {
      final b = run([for (var i = 0; i < 3; i++) o(RiskOutcome.delivered)]);
      expect(kinds(b), {RiskBadgeKind.reliable});
      expect(b.single.orderIds, hasLength(3));
    });
    test('1 of 2 returned: 50% but below min orders => no rate badge', () {
      final b = run([o(RiskOutcome.delivered), o(RiskOutcome.returned, reason: 'wrong_address')]);
      expect(kinds(b), isEmpty);
    });
  });

  group('rate threshold boundary (40%)', () {
    test('2 of 5 = 40% => high return rate', () {
      final b = run([
        for (var i = 0; i < 3; i++) o(RiskOutcome.delivered, daysAgo: 100 + i),
        o(RiskOutcome.returned, daysAgo: 300, reason: 'wrong_address'),
        o(RiskOutcome.returned, daysAgo: 301, reason: 'wrong_address'),
      ]);
      expect(kinds(b), contains(RiskBadgeKind.highReturnRate));
      expect(b.firstWhere((x) => x.kind == RiskBadgeKind.highReturnRate).orderIds, hasLength(2));
      expect(kinds(b), isNot(contains(RiskBadgeKind.reliable)));
    });
    test('2 of 6 = 33% => below threshold', () {
      final b = run([
        for (var i = 0; i < 4; i++) o(RiskOutcome.delivered),
        o(RiskOutcome.returned, reason: 'wrong_address'),
        o(RiskOutcome.returned, reason: 'wrong_address'),
      ]);
      expect(kinds(b), isNot(contains(RiskBadgeKind.highReturnRate)));
    });
    test('threshold is configurable', () {
      final f = [
        o(RiskOutcome.delivered),
        o(RiskOutcome.delivered),
        o(RiskOutcome.delivered),
        o(RiskOutcome.returned, daysAgo: 200, reason: 'wrong_address'),
      ];
      expect(kinds(run(f)), isNot(contains(RiskBadgeKind.highReturnRate)));
      expect(
          kinds(run(f, t: const RiskThresholds(returnRatePercent: 25))),
          contains(RiskBadgeKind.highReturnRate));
    });
  });

  group('refusal recency', () {
    test('refused last COD at exactly 90 days => badge', () {
      final b = run([o(RiskOutcome.returned, daysAgo: 90, reason: 'customer_refused')]);
      expect(kinds(b), contains(RiskBadgeKind.refusedLastCod));
    });
    test('91 days => expired', () {
      final b = run([o(RiskOutcome.returned, daysAgo: 91, reason: 'customer_refused')]);
      expect(kinds(b), isNot(contains(RiskBadgeKind.refusedLastCod)));
    });
    test('a later successful delivery clears it', () {
      final b = run([
        o(RiskOutcome.returned, daysAgo: 30, reason: 'customer_refused'),
        o(RiskOutcome.delivered, daysAgo: 5),
      ]);
      expect(kinds(b), isNot(contains(RiskBadgeKind.refusedLastCod)));
    });
    test('seller-side reason (wrong address) is not a refusal', () {
      final b = run([o(RiskOutcome.returned, daysAgo: 5, reason: 'wrong_address')]);
      expect(kinds(b), isNot(contains(RiskBadgeKind.refusedLastCod)));
    });
    test('prepaid refusal does not count as a COD refusal', () {
      final b = run([o(RiskOutcome.returned, daysAgo: 5, cod: false, reason: 'customer_refused')]);
      expect(kinds(b), isNot(contains(RiskBadgeKind.refusedLastCod)));
    });
    test('fake order counts', () {
      final b = run([o(RiskOutcome.returned, daysAgo: 5, reason: 'fake_order')]);
      expect(b.firstWhere((x) => x.kind == RiskBadgeKind.refusedLastCod).orderIds, ['o0']);
    });
  });

  test('blocklisted badge, and it blocks reliable', () {
    final b = run([for (var i = 0; i < 4; i++) o(RiskOutcome.delivered)], block: true);
    expect(kinds(b), {RiskBadgeKind.blocklisted});
    expect(b.single.isWarning, isTrue);
  });

  test('new customer + blocklisted', () {
    expect(kinds(run([], block: true)),
        {RiskBadgeKind.blocklisted, RiskBadgeKind.newCustomer});
  });

  test('is deterministic regardless of input order', () {
    final f = [
      o(RiskOutcome.delivered, daysAgo: 50),
      o(RiskOutcome.returned, daysAgo: 20, reason: 'customer_refused'),
      o(RiskOutcome.delivered, daysAgo: 80),
    ];
    final a = run(f).map((x) => x.kind).toList();
    final b = run(f.reversed.toList()).map((x) => x.kind).toList();
    expect(a, b);
  });
}
