import 'package:meta/meta.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/features/profit/domain/profit_calculator.dart';

@immutable
class ReturnedLine {
  const ReturnedLine({required this.qty, this.unitCost, this.condition});

  final int qty;
  final Money? unitCost;

  /// Null until received back; counts as resellable.
  final ReturnCondition? condition;
}

@immutable
class ReturnLoss {
  const ReturnLoss({required this.goodsLoss, required this.nonRecoverableFees});

  /// Cost of damaged or lost goods.
  final Money goodsLoss;

  /// Fees the courier keeps although no sale (or only a partial sale) happened.
  final Money nonRecoverableFees;

  Money get total => goodsLoss + nonRecoverableFees;
}

/// `loss = non-resellable cost + non-recoverable fees` (feature spec F7).
abstract final class ReturnLossCalculator {
  static ReturnLoss compute({
    required bool fullReturn,
    required List<ReturnedLine> lines,
    Money deliveryFee = Money.zero,
    Money returnFee = Money.zero,
  }) {
    var goods = Money.zero;
    for (final l in lines) {
      if ((l.condition?.isLoss ?? false) && l.unitCost != null) {
        goods += l.unitCost! * l.qty;
      }
    }
    // On a full return the delivery fee is also wasted; on a partial return
    // the delivery fee was paid for a real sale, only the return fee is lost.
    final fees = fullReturn ? deliveryFee + returnFee : returnFee;
    return ReturnLoss(goodsLoss: goods, nonRecoverableFees: fees);
  }
}
