import 'package:meta/meta.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/features/profit/domain/profit_calculator.dart';

enum ExchangePayer { customer, seller }

@immutable
class ExchangeInput {
  const ExchangeInput({
    required this.returnedValue,
    required this.replacementValue,
    this.replacementDelivery = Money.zero,
    this.returnShipping = Money.zero,
    this.payer = ExchangePayer.seller,
  });

  /// Value (after discounts) of the goods coming back.
  final Money returnedValue;

  /// Value of the replacement items.
  final Money replacementValue;

  /// What delivering the replacement costs / would be billed.
  final Money replacementDelivery;

  /// Courier charge for taking the original goods back.
  final Money returnShipping;

  /// Who bears the two shipping legs.
  final ExchangePayer payer;
}

@immutable
class ExchangeOutcome {
  const ExchangeOutcome({
    required this.replacementCod,
    required this.refundDue,
    required this.customerDeliveryCharge,
    required this.businessShippingLoss,
  });

  /// Cash the courier collects on the replacement (difference, floor 0).
  final Money replacementCod;

  /// Owed back to the customer when the replacement is cheaper.
  final Money refundDue;

  /// Delivery charge billed to the customer on the replacement order
  /// (replacement delivery + return shipping when the customer pays).
  final Money customerDeliveryCharge;

  /// Shipping the business absorbs (zero when the customer pays).
  final Money businessShippingLoss;

  /// Prepaid-equivalent: nothing to collect.
  bool get isEven => replacementCod.isZero;
}

abstract final class ExchangeCalculator {
  static ExchangeOutcome compute(ExchangeInput i) {
    final customerPays = i.payer == ExchangePayer.customer;
    final billedShipping =
        customerPays ? i.replacementDelivery + i.returnShipping : Money.zero;
    // Positive: customer owes more; negative: seller owes the customer.
    final net = i.replacementValue - i.returnedValue + billedShipping;
    return ExchangeOutcome(
      replacementCod: net.isNegative ? Money.zero : net,
      refundDue: net.isNegative ? Money(-net.poisha) : Money.zero,
      customerDeliveryCharge: billedShipping,
      businessShippingLoss:
          customerPays ? Money.zero : i.replacementDelivery + i.returnShipping,
    );
  }
}

/// The original order and its replacement reported together; the group's
/// profit is exactly the sum of the two orders' profits.
@immutable
class ExchangeGroupProfit {
  const ExchangeGroupProfit({
    required this.original,
    required this.replacement,
  });

  factory ExchangeGroupProfit.of(ProfitResult original, ProfitResult replacement) =>
      ExchangeGroupProfit(original: original, replacement: replacement);

  final ProfitResult original;
  final ProfitResult replacement;

  Money get revenue => original.revenue + replacement.revenue;
  Money get grossCollected => original.grossCollected + replacement.grossCollected;
  Money get totalCosts => original.totalCosts + replacement.totalCosts;
  Money get net => original.net + replacement.net;

  ProfitState get state {
    final s = [original.state, replacement.state];
    if (s.contains(ProfitState.incomplete)) return ProfitState.incomplete;
    if (s.contains(ProfitState.provisional)) return ProfitState.provisional;
    return ProfitState.finalised;
  }
}
