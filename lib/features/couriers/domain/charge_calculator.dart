import 'package:parcel_khata/core/money/money.dart';

enum ReturnFeeMode {
  none,
  flat,
  percentOfDelivery;

  String get dbValue => switch (this) {
        ReturnFeeMode.none => 'none',
        ReturnFeeMode.flat => 'flat',
        ReturnFeeMode.percentOfDelivery => 'percent_of_delivery',
      };

  static ReturnFeeMode fromDb(String v) => ReturnFeeMode.values
      .firstWhere((m) => m.dbValue == v, orElse: () => ReturnFeeMode.none);
}

class RateRule {
  const RateRule({
    required this.zone,
    required this.fee,
    this.weightMinG = 0,
    this.weightMaxG,
  });

  final String zone;
  final Money fee;
  final int weightMinG;

  /// Exclusive upper bound; null = no upper bound.
  final int? weightMaxG;

  bool matches(String zoneName, int? weightG) {
    if (zone != zoneName) return false;
    if (weightG == null) return true;
    return weightG >= weightMinG && (weightMaxG == null || weightG < weightMaxG!);
  }
}

class CourierFeeRules {
  const CourierFeeRules({
    this.rateRules = const [],
    this.codFeePercentBp = 0,
    this.codFeeFlat = Money.zero,
    this.codFeeFreeUnder,
    this.returnFeeMode = ReturnFeeMode.none,
    this.returnFeeValue = 0,
  });

  final List<RateRule> rateRules;
  final int codFeePercentBp;
  final Money codFeeFlat;

  /// COD amounts strictly below this pay no COD fee.
  final Money? codFeeFreeUnder;
  final ReturnFeeMode returnFeeMode;

  /// Flat: poisha. PercentOfDelivery: basis points of the delivery fee.
  final int returnFeeValue;
}

class ExpectedCharges {
  const ExpectedCharges({this.deliveryFee, required this.codFee, this.returnFee});

  /// Null when no rate rule matched (seller must enter it).
  final Money? deliveryFee;
  final Money codFee;
  final Money? returnFee;
}

/// Computes expected courier fees from a rate card. Actual fees recorded at
/// settlement always override these (feature spec F4).
abstract final class ChargeCalculator {
  static ExpectedCharges expected({
    required CourierFeeRules rules,
    required String zone,
    required Money codAmount,
    int? weightG,
  }) {
    final delivery = deliveryFee(rules, zone, weightG);
    return ExpectedCharges(
      deliveryFee: delivery,
      codFee: codFee(rules, codAmount),
      returnFee: returnFee(rules, delivery),
    );
  }

  /// Most specific (highest min weight) matching rule wins.
  static Money? deliveryFee(CourierFeeRules rules, String zone, int? weightG) {
    final matching = rules.rateRules.where((r) => r.matches(zone, weightG)).toList()
      ..sort((a, b) => b.weightMinG.compareTo(a.weightMinG));
    return matching.isEmpty ? null : matching.first.fee;
  }

  static Money codFee(CourierFeeRules rules, Money codAmount) {
    if (codAmount <= Money.zero) return Money.zero;
    final free = rules.codFeeFreeUnder;
    if (free != null && codAmount < free) return Money.zero;
    return codAmount.percentBp(rules.codFeePercentBp) + rules.codFeeFlat;
  }

  static Money? returnFee(CourierFeeRules rules, Money? delivery) {
    switch (rules.returnFeeMode) {
      case ReturnFeeMode.none:
        return Money.zero;
      case ReturnFeeMode.flat:
        return Money(rules.returnFeeValue);
      case ReturnFeeMode.percentOfDelivery:
        return delivery?.percentBp(rules.returnFeeValue);
    }
  }
}
