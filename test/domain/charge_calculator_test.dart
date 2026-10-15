import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/features/couriers/domain/charge_calculator.dart';

void main() {
  const rules = CourierFeeRules(
    rateRules: [
      RateRule(zone: 'inside_dhaka', fee: Money.taka(60), weightMaxG: 1000),
      RateRule(zone: 'inside_dhaka', fee: Money.taka(80), weightMinG: 1000, weightMaxG: 2000),
      RateRule(zone: 'inside_dhaka', fee: Money.taka(100), weightMinG: 2000),
      RateRule(zone: 'outside_dhaka', fee: Money.taka(130)),
    ],
    codFeePercentBp: 100,
    codFeeFlat: Money.taka(5),
    returnFeeMode: ReturnFeeMode.percentOfDelivery,
    returnFeeValue: 5000,
  );

  group('delivery fee', () {
    test('weight bands', () {
      expect(ChargeCalculator.deliveryFee(rules, 'inside_dhaka', 500), const Money.taka(60));
      expect(ChargeCalculator.deliveryFee(rules, 'inside_dhaka', 1000), const Money.taka(80));
      expect(ChargeCalculator.deliveryFee(rules, 'inside_dhaka', 1999), const Money.taka(80));
      expect(ChargeCalculator.deliveryFee(rules, 'inside_dhaka', 5000), const Money.taka(100));
    });
    test('zone without weight bands', () {
      expect(ChargeCalculator.deliveryFee(rules, 'outside_dhaka', 3000), const Money.taka(130));
    });
    test('no matching zone -> null', () {
      expect(ChargeCalculator.deliveryFee(rules, 'dhaka_suburb', 500), isNull);
    });
  });

  group('cod fee', () {
    test('percent + flat', () {
      // 1% of 1,234.50 = 12.345 -> 12.35, + 5 flat
      expect(ChargeCalculator.codFee(rules, const Money(123450)), const Money(1235 + 500));
    });
    test('zero cod -> zero fee', () {
      expect(ChargeCalculator.codFee(rules, Money.zero), Money.zero);
    });
    test('free under threshold', () {
      const r = CourierFeeRules(codFeePercentBp: 100, codFeeFreeUnder: Money.taka(1000));
      expect(ChargeCalculator.codFee(r, const Money.taka(999)), Money.zero);
      expect(ChargeCalculator.codFee(r, const Money.taka(1000)), const Money.taka(10));
    });
  });

  group('return fee', () {
    test('none', () {
      expect(ChargeCalculator.returnFee(const CourierFeeRules(), const Money.taka(60)), Money.zero);
    });
    test('flat', () {
      const r = CourierFeeRules(returnFeeMode: ReturnFeeMode.flat, returnFeeValue: 4000);
      expect(ChargeCalculator.returnFee(r, null), const Money.taka(40));
    });
    test('percent of delivery', () {
      expect(ChargeCalculator.returnFee(rules, const Money.taka(60)), const Money.taka(30));
      expect(ChargeCalculator.returnFee(rules, null), isNull);
    });
  });

  test('expected() combines all three', () {
    final e = ChargeCalculator.expected(
        rules: rules, zone: 'inside_dhaka', codAmount: const Money.taka(1000), weightG: 500);
    expect(e.deliveryFee, const Money.taka(60));
    expect(e.codFee, const Money.taka(15));
    expect(e.returnFee, const Money.taka(30));
  });

  test('ReturnFeeMode db round trip', () {
    for (final m in ReturnFeeMode.values) {
      expect(ReturnFeeMode.fromDb(m.dbValue), m);
    }
    expect(ReturnFeeMode.fromDb('garbage'), ReturnFeeMode.none);
  });
}
