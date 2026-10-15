import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/features/cod/domain/ledger.dart';
import 'package:parcel_khata/features/orders/domain/order_enums.dart';
import 'package:parcel_khata/features/profit/domain/profit_calculator.dart';
import 'package:parcel_khata/features/returns/domain/exchange_calculator.dart';

void main() {
  ExchangeOutcome calc({
    int returned = 1000,
    int replacement = 1000,
    int delivery = 60,
    int returnShipping = 60,
    ExchangePayer payer = ExchangePayer.seller,
  }) =>
      ExchangeCalculator.compute(ExchangeInput(
        returnedValue: Money.taka(returned),
        replacementValue: Money.taka(replacement),
        replacementDelivery: Money.taka(delivery),
        returnShipping: Money.taka(returnShipping),
        payer: payer,
      ));

  group('ExchangeCalculator', () {
    test('same price, seller pays shipping: nothing to collect, business loss', () {
      final o = calc();
      expect(o.replacementCod, Money.zero);
      expect(o.isEven, isTrue);
      expect(o.refundDue, Money.zero);
      expect(o.customerDeliveryCharge, Money.zero);
      expect(o.businessShippingLoss, const Money.taka(120));
    });

    test('same price, customer pays both legs', () {
      final o = calc(payer: ExchangePayer.customer);
      expect(o.replacementCod, const Money.taka(120));
      expect(o.customerDeliveryCharge, const Money.taka(120));
      expect(o.businessShippingLoss, Money.zero);
    });

    test('higher price: customer pays the difference', () {
      final o = calc(replacement: 1500);
      expect(o.replacementCod, const Money.taka(500));
      expect(o.refundDue, Money.zero);
    });

    test('lower price: COD floors at 0 and a refund is due', () {
      final o = calc(replacement: 700);
      expect(o.replacementCod, Money.zero);
      expect(o.refundDue, const Money.taka(300));
    });

    test('lower price but customer pays shipping offsets the refund', () {
      final o = calc(replacement: 900, payer: ExchangePayer.customer);
      // 900 - 1000 + 120 = +20
      expect(o.replacementCod, const Money.taka(20));
      expect(o.refundDue, Money.zero);
    });

    test('lower price, customer shipping smaller than the gap', () {
      final o = calc(replacement: 500, payer: ExchangePayer.customer);
      // 500 - 1000 + 120 = -380
      expect(o.refundDue, const Money.taka(380));
      expect(o.replacementCod, Money.zero);
    });

    test('exactly zero difference never produces a refund', () {
      final o = calc(replacement: 880, payer: ExchangePayer.customer);
      expect(o.replacementCod, Money.zero);
      expect(o.refundDue, Money.zero);
    });

    test('COD and refund are never both positive (property)', () {
      for (var r = 0; r <= 2000; r += 130) {
        for (var p = 0; p <= 2000; p += 170) {
          for (final payer in ExchangePayer.values) {
            final o = calc(returned: r, replacement: p, payer: payer);
            expect(o.replacementCod.isZero || o.refundDue.isZero, isTrue);
            expect(o.replacementCod.isNegative, isFalse);
            expect(o.refundDue.isNegative, isFalse);
            // Conservation: cod - refund = p - r + billed shipping.
            expect(
              (o.replacementCod - o.refundDue).poisha,
              (Money.taka(p) - Money.taka(r) + o.customerDeliveryCharge).poisha,
            );
          }
        }
      }
    });
  });

  group('ExchangeGroupProfit', () {
    ProfitResult profit(List<ProfitLine> lines,
        {OrderStatus status = OrderStatus.delivered, List<ChargeAmount> charges = const []}) {
      return ProfitCalculator.compute(ProfitInput(
        status: status,
        paymentType: PaymentType.cod,
        codStatus: CodStatus.settled,
        lines: lines,
        charges: charges,
      ));
    }

    test('group profit is exactly the sum of the pair', () {
      final original = profit(
        [
          const ProfitLine(
              name: 'Shirt M',
              qty: 1,
              unitSell: Money.taka(1000),
              unitCost: Money.taka(600),
              returnedQty: 1,
              returnCondition: ReturnCondition.resellable),
          const ProfitLine(
              name: 'Cap', qty: 1, unitSell: Money.taka(300), unitCost: Money.taka(100)),
        ],
        charges: const [
          ChargeAmount(type: 'delivery_fee', expected: Money.taka(60), actual: Money.taka(60)),
          ChargeAmount(type: 'return_fee', expected: Money.taka(60), actual: Money.taka(60)),
        ],
      );
      final replacement = profit(
        [
          const ProfitLine(
              name: 'Shirt L', qty: 1, unitSell: Money.taka(1000), unitCost: Money.taka(600)),
        ],
        charges: const [
          ChargeAmount(type: 'delivery_fee', expected: Money.taka(60), actual: Money.taka(60)),
        ],
      );
      final g = ExchangeGroupProfit.of(original, replacement);
      expect(g.net, original.net + replacement.net);
      expect(g.revenue, const Money.taka(300 + 1000));
      // Original: 300 - 100 - 60 - 60 = 80 ; replacement: 1000 - 600 - 60 = 340
      expect(original.net, const Money.taka(80));
      expect(replacement.net, const Money.taka(340));
      expect(g.net, const Money.taka(420));
      expect(g.state, ProfitState.finalised);
    });

    test('damaged return: loss lands on the original, group reflects it', () {
      final original = profit([
        const ProfitLine(
            name: 'Shirt M',
            qty: 1,
            unitSell: Money.taka(1000),
            unitCost: Money.taka(600),
            returnedQty: 1,
            returnCondition: ReturnCondition.damaged),
        const ProfitLine(
            name: 'Cap', qty: 1, unitSell: Money.taka(300), unitCost: Money.taka(100)),
      ]);
      expect(original.costOf(CostKind.goodsLoss), const Money.taka(600));
      final replacement = profit([
        const ProfitLine(
            name: 'Shirt L', qty: 1, unitSell: Money.taka(1000), unitCost: Money.taka(600)),
      ]);
      expect(ExchangeGroupProfit.of(original, replacement).net,
          const Money.taka(300 - 100 - 600 + 1000 - 600));
    });

    test('state: incomplete beats provisional beats final', () {
      final done = profit([
        const ProfitLine(name: 'a', qty: 1, unitSell: Money.taka(10), unitCost: Money.taka(5)),
      ]);
      final open = profit([
        const ProfitLine(name: 'b', qty: 1, unitSell: Money.taka(10), unitCost: Money.taka(5)),
      ], status: OrderStatus.confirmed);
      final missing = profit([
        const ProfitLine(name: 'c', qty: 1, unitSell: Money.taka(10)),
      ]);
      expect(ExchangeGroupProfit.of(done, open).state, ProfitState.provisional);
      expect(ExchangeGroupProfit.of(done, missing).state, ProfitState.incomplete);
      expect(ExchangeGroupProfit.of(open, missing).state, ProfitState.incomplete);
    });

    test('replacement cancelled: costs only what was actually spent', () {
      final original = profit([
        const ProfitLine(
            name: 'Shirt M',
            qty: 1,
            unitSell: Money.taka(1000),
            unitCost: Money.taka(600),
            returnedQty: 1,
            returnCondition: ReturnCondition.resellable),
        const ProfitLine(
            name: 'Cap', qty: 1, unitSell: Money.taka(300), unitCost: Money.taka(100)),
      ]);
      final replacement = profit(
        [
          const ProfitLine(
              name: 'Shirt L', qty: 1, unitSell: Money.taka(1000), unitCost: Money.taka(600)),
        ],
        status: OrderStatus.cancelled,
        charges: const [
          ChargeAmount(type: 'delivery_fee', expected: Money.taka(60)),
        ],
      );
      expect(replacement.revenue, Money.zero);
      expect(replacement.net, Money.zero);
      expect(ExchangeGroupProfit.of(original, replacement).net, original.net);
    });
  });
}
