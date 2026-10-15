import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_khata/core/money/money.dart';

void main() {
  group('Money arithmetic', () {
    test('add/sub/mul', () {
      expect(const Money.taka(10) + const Money(50), const Money(1050));
      expect(const Money.taka(10) - const Money.taka(12), const Money(-200));
      expect(const Money.taka(7) * 3, const Money.taka(21));
    });
  });

  group('percentBp rounding (half away from zero)', () {
    test('1% of 1,234.50 taka = 12.345 -> 12.35', () {
      expect(const Money(123450).percentBp(100), const Money(1235));
    });
    test('exact', () {
      expect(const Money.taka(1000).percentBp(100), const Money.taka(10));
    });
    test('below half rounds down', () {
      expect(const Money(149).percentBp(100), const Money(1));
    });
    test('negative symmetric', () {
      expect(const Money(-123450).percentBp(100), const Money(-1235));
    });
  });

  group('parse', () {
    test('formats', () {
      expect(Money.tryParse('1,234.5'), const Money(123450));
      expect(Money.tryParse('৳1234'), const Money(123400));
      expect(Money.tryParse('১,২৩৪.৫০'), const Money(123450));
      expect(Money.tryParse('-10'), const Money(-1000));
      expect(Money.tryParse('0.05'), const Money(5));
    });
    test('invalid', () {
      expect(Money.tryParse(''), isNull);
      expect(Money.tryParse('abc'), isNull);
      expect(Money.tryParse('1.2.3'), isNull);
    });
  });

  group('format', () {
    test('whole taka western grouping', () {
      expect(const Money.taka(12450).format(), '৳12,450');
      expect(const Money.taka(999).format(), '৳999');
      expect(const Money.taka(1250000).format(), '৳1,250,000');
    });
    test('indian grouping', () {
      expect(const Money.taka(125000).format(indianGrouping: true), '৳1,25,000');
    });
    test('decimals', () {
      expect(const Money(123450).format(decimals: true), '৳1,234.50');
    });
    test('bangla digits', () {
      expect(const Money.taka(12450).format(banglaDigits: true), '৳১২,৪৫০');
    });
    test('negative', () {
      expect(const Money.taka(-500).format(), '-৳500');
    });
    test('rounds half up to whole taka', () {
      expect(const Money(150).format(), '৳2');
      expect(const Money(149).format(), '৳1');
    });
  });
}
