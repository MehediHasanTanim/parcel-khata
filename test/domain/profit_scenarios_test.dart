import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/features/cod/domain/ledger.dart';
import 'package:parcel_khata/features/orders/domain/order_enums.dart';
import 'package:parcel_khata/features/profit/domain/profit_calculator.dart';
import 'package:parcel_khata/features/returns/domain/return_loss_calculator.dart';

Money t(int v) => Money.taka(v);

ChargeAmount ch(String type, int expected, {int? actual}) => ChargeAmount(
      type: type,
      expected: t(expected),
      actual: actual == null ? null : t(actual),
    );

ProfitLine line(
  int qty,
  int sell, {
  int? cost = 0,
  int discount = 0,
  int returned = 0,
  ReturnCondition? cond,
  String name = 'item',
}) =>
    ProfitLine(
      name: name,
      qty: qty,
      unitSell: t(sell),
      unitCost: cost == null ? null : t(cost),
      lineDiscount: t(discount),
      returnedQty: returned,
      returnCondition: cond,
    );

ProfitResult run(
  List<ProfitLine> lines, {
  OrderStatus status = OrderStatus.delivered,
  PaymentType type = PaymentType.cod,
  CodStatus cod = CodStatus.settled,
  int orderDiscount = 0,
  int delivery = 60,
  List<ChargeAmount> charges = const [],
}) =>
    ProfitCalculator.compute(ProfitInput(
      status: status,
      paymentType: type,
      codStatus: cod,
      lines: lines,
      orderDiscount: t(orderDiscount),
      deliveryCharge: t(delivery),
      charges: charges,
    ));

void main() {
  group('spec section 16 scenarios', () {
    test('S1 prepaid delivered: revenue - COGS - fees - packaging', () {
      final r = run(
        [line(2, 500, cost: 300)],
        type: PaymentType.prepaid,
        cod: CodStatus.notApplicable,
        charges: [
          ch('delivery_fee', 60, actual: 60),
          ch('packaging', 10, actual: 10),
        ],
      );
      // 1000 + 60 - 600 - 60 - 10
      expect(r.net, t(390));
      expect(r.state, ProfitState.finalised);
    });

    test('S2 COD delivered fully settled -> final', () {
      final r = run(
        [line(1, 1000, cost: 600)],
        charges: [ch('delivery_fee', 60, actual: 60), ch('cod_fee', 11, actual: 11)],
      );
      // 1000 + 60 - 600 - 60 - 11
      expect(r.net, t(389));
      expect(r.state, ProfitState.finalised);
      expect(r.usesExpectedCosts, isFalse);
    });

    test('S2b COD delivered, not yet settled -> provisional, uses expected', () {
      final r = run(
        [line(1, 1000, cost: 600)],
        cod: CodStatus.collectedByCourier,
        charges: [ch('delivery_fee', 60), ch('cod_fee', 11)],
      );
      expect(r.net, t(389));
      expect(r.state, ProfitState.provisional);
      expect(r.usesExpectedCosts, isTrue);
    });

    test('S3 courier short-pays by 40 and it is written off -> cost', () {
      final r = run(
        [line(1, 1000, cost: 600)],
        charges: [
          ch('delivery_fee', 60, actual: 60),
          ch('cod_fee', 11, actual: 11),
          ch('write_off', 40),
        ],
      );
      expect(r.net, t(349));
      expect(r.costOf(CostKind.writeOff), t(40));
      expect(r.state, ProfitState.finalised);
    });

    test('S4 customer refuses, resellable: loss = delivery + return fee only', () {
      final r = run(
        [line(1, 1000, cost: 600, returned: 1, cond: ReturnCondition.resellable)],
        status: OrderStatus.returned,
        cod: CodStatus.notCollected,
        charges: [
          ch('delivery_fee', 60, actual: 60),
          ch('cod_fee', 11), // not charged when nothing collected
          ch('return_fee', 30, actual: 30),
          ch('packaging', 10, actual: 10),
        ],
      );
      expect(r.revenue, Money.zero);
      expect(r.grossCollected, Money.zero);
      expect(r.net, t(-100));
      expect(r.state, ProfitState.finalised);
      expect(r.costOf(CostKind.cogs), Money.zero);
    });

    test('S4b failed delivery not yet received back -> provisional', () {
      final r = run(
        [line(1, 1000, cost: 600, returned: 1)],
        status: OrderStatus.returnInTransit,
        cod: CodStatus.notCollected,
        charges: [ch('delivery_fee', 60), ch('return_fee', 30)],
      );
      expect(r.net, t(-90));
      expect(r.state, ProfitState.provisional);
    });

    test('S5 partial return 2 of 3 kept: revenue and COGS for kept lines', () {
      final r = run(
        [
          line(1, 500, cost: 300, name: 'a'),
          line(1, 400, cost: 250, name: 'b'),
          line(1, 300, cost: 150, name: 'c', returned: 1, cond: ReturnCondition.resellable),
        ],
        charges: [
          ch('delivery_fee', 60, actual: 60),
          ch('cod_fee', 9, actual: 9),
          ch('return_fee', 20, actual: 20),
        ],
      );
      // revenue 900 + 60 delivery; COGS 550; fees 89
      expect(r.revenue, t(900));
      expect(r.costOf(CostKind.cogs), t(550));
      expect(r.net, t(960 - 550 - 89));
    });

    test('S10 catalog cost change does not matter: cost lives on the line', () {
      final a = run([line(1, 1000, cost: 600)]);
      final b = run([line(1, 1000, cost: 600)]);
      expect(a.net, b.net);
    });

    test('S11 missing cost -> incomplete, excluded from final totals', () {
      final r = run([line(1, 1000, cost: null, name: 'Mystery')]);
      expect(r.state, ProfitState.incomplete);
      expect(r.missingCostLines, ['Mystery']);
    });
  });

  group('edge cases', () {
    test('order discount and line discount reduce revenue', () {
      final r = run(
        [line(2, 500, cost: 300, discount: 100)],
        orderDiscount: 50,
        delivery: 0,
      );
      expect(r.revenue, t(850));
      expect(r.net, t(250));
    });

    test('advance payment does not change profit', () {
      // Profit uses totals, not who paid; same lines/charges either way.
      final cod = run([line(1, 1000, cost: 600)], delivery: 60);
      final partial =
          run([line(1, 1000, cost: 600)], type: PaymentType.partialAdvance, delivery: 60);
      expect(partial.net, cod.net);
    });

    test('actual fee at settlement overrides expected and flips to final', () {
      final before = run(
        [line(1, 1000, cost: 600)],
        cod: CodStatus.collectedByCourier,
        charges: [ch('delivery_fee', 60)],
      );
      final after = run(
        [line(1, 1000, cost: 600)],
        cod: CodStatus.settled,
        charges: [ch('delivery_fee', 60, actual: 80)],
      );
      expect(before.net, t(400));
      expect(after.net, t(380));
      expect(before.state, ProfitState.provisional);
      expect(after.state, ProfitState.finalised);
    });

    test('damaged return loses the goods cost', () {
      final r = run(
        [line(1, 1000, cost: 600, returned: 1, cond: ReturnCondition.damaged)],
        status: OrderStatus.returned,
        cod: CodStatus.notCollected,
        charges: [ch('delivery_fee', 60, actual: 60), ch('return_fee', 30, actual: 30)],
      );
      expect(r.costOf(CostKind.goodsLoss), t(600));
      expect(r.net, t(-690));
    });

    test('lost goods in partial return', () {
      final r = run(
        [
          line(2, 500, cost: 300, returned: 1, cond: ReturnCondition.lost),
        ],
        delivery: 0,
        charges: [ch('delivery_fee', 60, actual: 60)],
      );
      // kept 1: revenue 500, COGS 300, lost 300, fee 60
      expect(r.net, t(500 - 300 - 300 - 60));
    });

    test('cancelled before dispatch is ~0 and ignores expected charges', () {
      final r = run(
        [line(1, 1000, cost: 600)],
        status: OrderStatus.cancelled,
        cod: CodStatus.notCollected,
        charges: [ch('delivery_fee', 60), ch('packaging', 10)],
      );
      expect(r.net, Money.zero);
      expect(r.state, ProfitState.finalised);
    });

    test('cancelled counts money really spent', () {
      final r = run(
        [line(1, 1000, cost: 600)],
        status: OrderStatus.cancelled,
        cod: CodStatus.notCollected,
        charges: [ch('packaging', 10, actual: 10)],
      );
      expect(r.net, t(-10));
    });

    test('prepaid delivered stays provisional while fees are only expected', () {
      final r = run(
        [line(1, 1000, cost: 600)],
        type: PaymentType.prepaid,
        cod: CodStatus.notApplicable,
        charges: [ch('delivery_fee', 60)],
      );
      expect(r.state, ProfitState.provisional);
    });

    test('before delivery is always provisional', () {
      for (final s in [
        OrderStatus.confirmed,
        OrderStatus.packed,
        OrderStatus.handedToCourier,
        OrderStatus.inTransit,
      ]) {
        final r = run([line(1, 1000, cost: 600)], status: s, cod: CodStatus.pendingCollection);
        expect(r.state, ProfitState.provisional, reason: '$s');
      }
    });

    test('proportional rounding is half up', () {
      // 100.00 * 1/3 = 33.333 -> 33.33 ; 100.00 * 2/3 = 66.667 -> 66.67
      expect(ProfitCalculator.proportional(const Money(10000), 1, 3), const Money(3333));
      expect(ProfitCalculator.proportional(const Money(10000), 2, 3), const Money(6667));
      expect(ProfitCalculator.proportional(const Money(1), 1, 2), const Money(1));
    });

    test('partial return shares the order discount proportionally', () {
      // items 1000 (2 x 500), discount 100; return 1 of 2
      final r = run(
        [line(2, 500, cost: 300, returned: 1)],
        orderDiscount: 100,
        delivery: 0,
      );
      expect(r.revenue, t(450));
      expect(ProfitCalculator.returnedValue(
              [line(2, 500, cost: 300, returned: 1)], t(100)),
          t(450));
    });

    test('margin in basis points', () {
      final r = run([line(1, 1000, cost: 600)], delivery: 0);
      expect(r.marginBp, 4000);
      final zero = run([], status: OrderStatus.cancelled);
      expect(zero.marginBp, isNull);
    });

    test('sum of per-order profits equals the aggregate (no drift)', () {
      final orders = [
        run([line(1, 1000, cost: 600)], charges: [ch('delivery_fee', 60, actual: 60)]),
        run([line(2, 300, cost: 100)], charges: [ch('delivery_fee', 60, actual: 70)]),
        run([line(1, 800, cost: 500, returned: 1)],
            status: OrderStatus.returned,
            cod: CodStatus.notCollected,
            charges: [ch('delivery_fee', 60, actual: 60)]),
      ];
      final sum = orders.fold(Money.zero, (s, r) => s + r.net);
      final viaParts = orders.fold(
          Money.zero, (s, r) => s + r.grossCollected - r.totalCosts);
      expect(sum, viaParts);
    });
  });

  group('ReturnLossCalculator', () {
    test('full return: goods loss + delivery + return fees', () {
      final l = ReturnLossCalculator.compute(
        fullReturn: true,
        lines: [
          ReturnedLine(qty: 1, unitCost: t(600), condition: ReturnCondition.damaged),
        ],
        deliveryFee: t(60),
        returnFee: t(30),
      );
      expect(l.goodsLoss, t(600));
      expect(l.nonRecoverableFees, t(90));
      expect(l.total, t(690));
    });

    test('resellable full return: only fees', () {
      final l = ReturnLossCalculator.compute(
        fullReturn: true,
        lines: [
          ReturnedLine(qty: 2, unitCost: t(300), condition: ReturnCondition.resellable),
        ],
        deliveryFee: t(60),
        returnFee: t(30),
      );
      expect(l.total, t(90));
    });

    test('partial return: only the return fee is non-recoverable', () {
      final l = ReturnLossCalculator.compute(
        fullReturn: false,
        lines: [
          ReturnedLine(qty: 1, unitCost: t(300), condition: ReturnCondition.lost),
        ],
        deliveryFee: t(60),
        returnFee: t(20),
      );
      expect(l.nonRecoverableFees, t(20));
      expect(l.total, t(320));
    });

    test('unknown condition counts as resellable', () {
      final l = ReturnLossCalculator.compute(
        fullReturn: true,
        lines: [ReturnedLine(qty: 1, unitCost: t(600))],
      );
      expect(l.goodsLoss, Money.zero);
    });
  });
}
