import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/features/orders/domain/cod_amount_calculator.dart';
import 'package:parcel_khata/features/orders/domain/order_enums.dart';
import 'package:parcel_khata/features/orders/domain/order_input.dart';

LineInput line(int sellTaka, {int qty = 1, Discount d = const Discount.none(), int? cost}) =>
    LineInput(
      name: 'x',
      qty: qty,
      unitSell: Money.taka(sellTaka),
      unitCost: cost == null ? null : Money.taka(cost),
      discount: d,
    );

CodBreakdown calc(
  List<LineInput> lines, {
  PaymentType type = PaymentType.cod,
  Discount discount = const Discount.none(),
  int delivery = 0,
  int advance = 0,
  Money? override,
}) =>
    CodAmountCalculator.compute(
      lines: lines,
      paymentType: type,
      orderDiscount: discount,
      deliveryCharge: Money.taka(delivery),
      advance: Money.taka(advance),
      override: override,
    );

void main() {
  test('basic: items + delivery', () {
    final b = calc([line(500, qty: 2), line(300)], delivery: 60);
    expect(b.itemsTotal, const Money.taka(1300));
    expect(b.calculated, const Money.taka(1360));
    expect(b.effective, const Money.taka(1360));
    expect(b.overridden, isFalse);
  });

  test('line discount amount and percent', () {
    final b = calc([
      line(1000, d: const Discount.amount(Money.taka(100))),
      line(500, qty: 2, d: const Discount.percentBp(1000)), // 10% of 1000
    ]);
    expect(b.itemsTotal, const Money.taka(900 + 900));
  });

  test('order discount amount', () {
    final b = calc([line(1000)], discount: const Discount.amount(Money.taka(150)), delivery: 60);
    expect(b.orderDiscount, const Money.taka(150));
    expect(b.calculated, const Money.taka(910));
  });

  test('order discount percent with rounding', () {
    // 12.5% of 999 = 124.875 -> 124.88
    final b = calc([line(999)], discount: const Discount.percentBp(1250));
    expect(b.orderDiscount, const Money(12488));
    expect(b.calculated, const Money(99900 - 12488));
  });

  test('discount cannot exceed base', () {
    final b = calc([line(100, d: const Discount.amount(Money.taka(500)))]);
    expect(b.itemsTotal, Money.zero);
    final c = calc([line(100)], discount: const Discount.amount(Money.taka(999)));
    expect(c.orderDiscount, const Money.taka(100));
    expect(c.calculated, Money.zero);
  });

  test('negative discount is ignored', () {
    final b = calc([line(100, d: const Discount.amount(Money(-500)))]);
    expect(b.itemsTotal, const Money.taka(100));
  });

  test('partial advance reduces COD', () {
    final b = calc([line(1000)], type: PaymentType.partialAdvance, delivery: 100, advance: 400);
    expect(b.advance, const Money.taka(400));
    expect(b.calculated, const Money.taka(700));
  });

  test('advance larger than total clamps COD to zero', () {
    final b = calc([line(100)], type: PaymentType.partialAdvance, advance: 500);
    expect(b.calculated, Money.zero);
  });

  test('COD type ignores any advance value', () {
    final b = calc([line(1000)], advance: 400);
    expect(b.advance, Money.zero);
    expect(b.calculated, const Money.taka(1000));
  });

  test('prepaid -> zero COD even with override', () {
    final b = calc([line(1000)], type: PaymentType.prepaid, delivery: 60, override: const Money.taka(5));
    expect(b.calculated, Money.zero);
    expect(b.effective, Money.zero);
    expect(b.overridden, isFalse);
  });

  test('override wins and is flagged; calculated is preserved for reset', () {
    final b = calc([line(1000)], delivery: 60, override: const Money.taka(950));
    expect(b.calculated, const Money.taka(1060));
    expect(b.effective, const Money.taka(950));
    expect(b.overridden, isTrue);
  });

  test('empty order', () {
    final b = calc([]);
    expect(b.calculated, Money.zero);
  });

  test('cost missing flag on lines', () {
    expect(line(100).costMissing, isTrue);
    expect(line(100, cost: 60).costMissing, isFalse);
  });

  group('OrderInput validation', () {
    test('requires customer, items, address for confirm', () {
      expect(const OrderInput(lines: []).validateForConfirm(), 'customer_required');
      expect(const OrderInput(customerId: 'c', lines: []).validateForConfirm(), 'items_required');
      expect(OrderInput(customerId: 'c', lines: [line(1)]).validateForConfirm(), 'address_required');
      expect(OrderInput(customerId: 'c', address: 'a', lines: [line(1)]).validateForConfirm(), isNull);
    });
    test('hasAnyData', () {
      expect(const OrderInput(lines: []).hasAnyData, isFalse);
      expect(const OrderInput(lines: [], notes: 'n').hasAnyData, isTrue);
    });
  });

  test('enum db round trips', () {
    for (final s in OrderStatus.values) {
      expect(OrderStatus.fromDb(s.dbValue), s);
    }
    for (final c in CodStatus.values) {
      expect(CodStatus.fromDb(c.dbValue), c);
    }
    for (final p in PaymentType.values) {
      expect(PaymentType.fromDb(p.dbValue), p);
    }
    for (final c in Channel.values) {
      expect(Channel.fromDb(c.dbValue), c);
    }
  });
}
