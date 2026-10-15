import 'package:meta/meta.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/features/orders/domain/order_enums.dart';

/// A discount as an absolute amount or basis points of a base.
@immutable
class Discount {
  const Discount.none()
      : amount = Money.zero,
        percentBp = 0;
  const Discount.amount(this.amount) : percentBp = 0;
  const Discount.percentBp(this.percentBp) : amount = Money.zero;

  final Money amount;
  final int percentBp;

  bool get isPercent => percentBp > 0;

  /// Discount in money for [base], clamped to [0, base].
  Money amountFor(Money base) {
    final raw = isPercent ? base.percentBp(percentBp) : amount;
    if (raw.isNegative) return Money.zero;
    return raw > base ? base : raw;
  }
}

@immutable
class LineInput {
  const LineInput({
    required this.name,
    required this.qty,
    required this.unitSell,
    this.unitCost,
    this.discount = const Discount.none(),
    this.productId,
    this.variantId,
  });

  final String name;
  final int qty;
  final Money unitSell;

  /// Null = cost missing (profit will be Incomplete).
  final Money? unitCost;
  final Discount discount;
  final String? productId;
  final String? variantId;

  Money get gross => unitSell * qty;
  Money get discountAmount => discount.amountFor(gross);
  Money get net => gross - discountAmount;
  bool get costMissing => unitCost == null;
}

@immutable
class CodBreakdown {
  const CodBreakdown({
    required this.itemsTotal,
    required this.orderDiscount,
    required this.deliveryCharge,
    required this.advance,
    required this.calculated,
    required this.effective,
    required this.overridden,
  });

  /// Sum of line totals after line discounts.
  final Money itemsTotal;
  final Money orderDiscount;
  final Money deliveryCharge;
  final Money advance;

  /// What the formula says.
  final Money calculated;

  /// What will be stored (the override when set).
  final Money effective;
  final bool overridden;

  /// Everything the customer pays in total (before advance).
  Money get grandTotal => itemsTotal - orderDiscount + deliveryCharge;
}

/// `COD = items - discounts + delivery charge - advance` (feature spec F1).
abstract final class CodAmountCalculator {
  static CodBreakdown compute({
    required List<LineInput> lines,
    required PaymentType paymentType,
    Discount orderDiscount = const Discount.none(),
    Money deliveryCharge = Money.zero,
    Money advance = Money.zero,
    Money? override,
  }) {
    final items = lines.fold(Money.zero, (sum, l) => sum + l.net);
    final discount = orderDiscount.amountFor(items);
    final grand = items - discount + deliveryCharge;
    final adv = switch (paymentType) {
      PaymentType.cod => Money.zero,
      PaymentType.prepaid => grand,
      PaymentType.partialAdvance => advance.isNegative ? Money.zero : advance,
    };
    var calc = grand - adv;
    if (calc.isNegative) calc = Money.zero;
    final overridden = override != null && paymentType != PaymentType.prepaid;
    return CodBreakdown(
      itemsTotal: items,
      orderDiscount: discount,
      deliveryCharge: deliveryCharge,
      advance: adv,
      calculated: calc,
      effective: overridden ? override : calc,
      overridden: overridden,
    );
  }
}
