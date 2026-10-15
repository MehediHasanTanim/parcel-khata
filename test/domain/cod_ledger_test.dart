import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/features/cod/domain/cod_status_resolver.dart';
import 'package:parcel_khata/features/cod/domain/ledger.dart';
import 'package:parcel_khata/features/orders/domain/order_enums.dart';

ChargeAmount ch(String type, int expected, [int? actual]) => ChargeAmount(
      type: type,
      expected: Money.taka(expected),
      actual: actual == null ? null : Money.taka(actual),
    );

void main() {
  group('LedgerCalculator', () {
    test('deductions = delivery + cod + return + other; packaging excluded', () {
      final d = LedgerCalculator.deductions([
        ch('delivery_fee', 60),
        ch('cod_fee', 15),
        ch('return_fee', 30),
        ch('other', 5),
        ch('packaging', 10),
        ch('write_off', 999),
      ]);
      expect(d, const Money.taka(110));
    });

    test('actual overrides expected', () {
      final d = LedgerCalculator.deductions([
        ch('delivery_fee', 60, 80),
        ch('cod_fee', 15),
      ]);
      expect(d, const Money.taka(95));
    });

    test('state: net and outstanding', () {
      final s = LedgerCalculator.state(
        collected: const Money.taka(1060),
        charges: [ch('delivery_fee', 60), ch('cod_fee', 11), ch('write_off', 9)],
        settled: const Money.taka(500),
      );
      expect(s.netReceivable, const Money.taka(989));
      expect(s.writtenOff, const Money.taka(9));
      expect(s.outstanding, const Money.taka(480));
    });
  });

  group('CodStatusResolver truth table', () {
    OrderLedgerState led({int collected = 1000, int ded = 100, int settled = 0, int wo = 0, bool disputed = false}) =>
        OrderLedgerState(
          collected: Money.taka(collected),
          deductions: Money.taka(ded),
          settled: Money.taka(settled),
          writtenOff: Money.taka(wo),
          isDisputed: disputed,
        );

    CodStatus r(
      OrderStatus s, {
      PaymentType p = PaymentType.cod,
      int cod = 1000,
      OrderLedgerState? ledger,
    }) =>
        CodStatusResolver.resolve(CodStatusInput(
          paymentType: p,
          codExpected: Money.taka(cod),
          status: s,
          ledger: ledger,
        ));

    test('prepaid or zero COD', () {
      expect(r(OrderStatus.delivered, p: PaymentType.prepaid), CodStatus.notApplicable);
      expect(r(OrderStatus.delivered, cod: 0), CodStatus.notApplicable);
    });

    test('before delivery: pending collection', () {
      for (final s in [
        OrderStatus.confirmed,
        OrderStatus.packed,
        OrderStatus.handedToCourier,
        OrderStatus.inTransit,
      ]) {
        expect(r(s), CodStatus.pendingCollection);
      }
    });

    test('failed/returned/cancelled with nothing collected', () {
      for (final s in [
        OrderStatus.deliveryFailed,
        OrderStatus.returnInTransit,
        OrderStatus.returned,
        OrderStatus.cancelled,
      ]) {
        expect(r(s), CodStatus.notCollected);
      }
    });

    test('delivered: collected -> partial -> settled', () {
      expect(r(OrderStatus.delivered, ledger: led()), CodStatus.collectedByCourier);
      expect(r(OrderStatus.delivered, ledger: led(settled: 400)), CodStatus.partiallySettled);
      expect(r(OrderStatus.delivered, ledger: led(settled: 900)), CodStatus.settled);
    });

    test('write-off counts toward settlement', () {
      expect(r(OrderStatus.delivered, ledger: led(settled: 850, wo: 50)), CodStatus.settled);
      expect(r(OrderStatus.delivered, ledger: led(settled: 800, wo: 50)), CodStatus.partiallySettled);
    });

    test('disputed is explicit and only while money is outstanding', () {
      expect(r(OrderStatus.delivered, ledger: led(settled: 400, disputed: true)),
          CodStatus.disputed);
      expect(r(OrderStatus.delivered, ledger: led(settled: 900, disputed: true)),
          CodStatus.settled);
    });

    test('overpaid is settled', () {
      expect(r(OrderStatus.delivered, ledger: led(settled: 1000)), CodStatus.settled);
    });

    test('partial return keeps collected money in the ledger', () {
      expect(r(OrderStatus.returned, ledger: led(collected: 500, ded: 60)),
          CodStatus.collectedByCourier);
    });
  });
}
