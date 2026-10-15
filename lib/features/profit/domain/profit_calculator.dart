import 'package:meta/meta.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/features/cod/domain/ledger.dart';
import 'package:parcel_khata/features/orders/domain/order_enums.dart';

enum ReturnCondition {
  resellable('resellable'),
  damaged('damaged'),
  lost('lost');

  const ReturnCondition(this.dbValue);
  final String dbValue;

  static ReturnCondition? fromDb(String? v) {
    for (final c in ReturnCondition.values) {
      if (c.dbValue == v) return c;
    }
    return null;
  }

  /// Damaged and lost goods are written off; resellable ones are recovered.
  bool get isLoss => this != ReturnCondition.resellable;
}

enum ProfitState {
  incomplete('incomplete'),
  provisional('provisional'),
  finalised('final');

  const ProfitState(this.dbValue);
  final String dbValue;
}

enum CostKind {
  cogs,
  deliveryFee,
  codFee,
  returnFee,
  packaging,
  other,
  writeOff,
  goodsLoss,
}

@immutable
class ProfitLine {
  const ProfitLine({
    required this.name,
    required this.qty,
    required this.unitSell,
    this.unitCost,
    this.lineDiscount = Money.zero,
    this.returnedQty = 0,
    this.returnCondition,
  });

  final String name;
  final int qty;
  final Money unitSell;

  /// Null = cost missing (profit is Incomplete).
  final Money? unitCost;
  final Money lineDiscount;
  final int returnedQty;

  /// Null until the goods are received back; treated as resellable.
  final ReturnCondition? returnCondition;

  Money get net => unitSell * qty - lineDiscount;
  int get keptQty => qty - returnedQty;
}

@immutable
class ProfitInput {
  const ProfitInput({
    required this.status,
    required this.paymentType,
    required this.codStatus,
    required this.lines,
    this.orderDiscount = Money.zero,
    this.deliveryCharge = Money.zero,
    this.charges = const [],
  });

  final OrderStatus status;
  final PaymentType paymentType;
  final CodStatus codStatus;
  final List<ProfitLine> lines;
  final Money orderDiscount;
  final Money deliveryCharge;
  final List<ChargeAmount> charges;
}

@immutable
class CostLine {
  const CostLine(this.kind, this.amount, {this.isExpected = false});
  final CostKind kind;
  final Money amount;

  /// True when based on an expected (rate-card) amount, not an actual one.
  final bool isExpected;
}

@immutable
class ProfitResult {
  const ProfitResult({
    required this.revenue,
    required this.deliveryCharge,
    required this.costs,
    required this.state,
    required this.missingCostLines,
  });

  /// Product revenue actually kept by the customer, after discounts.
  final Money revenue;
  final Money deliveryCharge;
  final List<CostLine> costs;
  final ProfitState state;

  /// Names of lines whose cost is unknown.
  final List<String> missingCostLines;

  /// What the customer pays in total for kept goods + delivery.
  Money get grossCollected => revenue + deliveryCharge;
  Money get totalCosts => costs.fold(Money.zero, (s, c) => s + c.amount);
  Money get net => grossCollected - totalCosts;
  bool get usesExpectedCosts => costs.any((c) => c.isExpected && !c.amount.isZero);

  Money costOf(CostKind k) =>
      costs.where((c) => c.kind == k).fold(Money.zero, (s, c) => s + c.amount);

  /// Net / gross in basis points, rounded half away from zero.
  int? get marginBp {
    final g = grossCollected.poisha;
    if (g == 0) return null;
    final n = net.poisha * 10000;
    final q = (n.abs() * 2 + g.abs()) ~/ (2 * g.abs());
    return (n < 0) == (g < 0) ? q : -q;
  }
}

/// Pure profit rules (feature spec F8 §8.1–8.3). The same function backs the
/// breakdown panel, list chip and reports so they can never drift.
abstract final class ProfitCalculator {
  static const _courierTypes = {'delivery_fee', 'cod_fee', 'return_fee', 'other'};

  /// `m * num / den`, rounded half up (non-negative inputs).
  static Money proportional(Money m, int num, int den) {
    if (den == 0 || num == 0) return Money.zero;
    final v = m.poisha * num;
    return Money((v * 2 + den) ~/ (2 * den));
  }

  static Money itemsNet(List<ProfitLine> lines) =>
      lines.fold(Money.zero, (s, l) => s + l.net);

  static Money keptNet(List<ProfitLine> lines) => lines.fold(
      Money.zero, (s, l) => s + (l.qty == 0 ? Money.zero : proportional(l.net, l.keptQty, l.qty)));

  static bool isFullyReturned(List<ProfitLine> lines) =>
      lines.isNotEmpty && lines.every((l) => l.returnedQty >= l.qty);

  /// Value of returned goods net of line and share of order discount; this is
  /// how much COD collection shrinks on a partial return.
  static Money returnedValue(List<ProfitLine> lines, Money orderDiscount) {
    final items = itemsNet(lines);
    final kept = keptNet(lines);
    final discountKept = items.isZero ? Money.zero : proportional(orderDiscount, kept.poisha, items.poisha);
    final returnedGross = items - kept;
    final discountReturned = orderDiscount - discountKept;
    final v = returnedGross - discountReturned;
    return v.isNegative ? Money.zero : v;
  }

  static ProfitResult compute(ProfitInput i) {
    final cancelled = i.status == OrderStatus.cancelled;
    final fullReturn = isFullyReturned(i.lines);
    final nothingKept = cancelled || fullReturn;

    final items = itemsNet(i.lines);
    final kept = keptNet(i.lines);
    final discountKept = items.isZero
        ? Money.zero
        : proportional(i.orderDiscount, kept.poisha, items.poisha);
    final revenue = nothingKept ? Money.zero : kept - discountKept;
    final delivery = nothingKept ? Money.zero : i.deliveryCharge;

    final missing = <String>[];
    var cogs = Money.zero;
    var goodsLoss = Money.zero;
    for (final l in i.lines) {
      final keptQty = cancelled ? 0 : l.keptQty;
      if (keptQty > 0) {
        if (l.unitCost == null) {
          missing.add(l.name);
        } else {
          cogs += l.unitCost! * keptQty;
        }
      }
      if (!cancelled && l.returnedQty > 0 && (l.returnCondition?.isLoss ?? false)) {
        if (l.unitCost == null) {
          if (!missing.contains(l.name)) missing.add(l.name);
        } else {
          goodsLoss += l.unitCost! * l.returnedQty;
        }
      }
    }

    final costs = <CostLine>[];
    if (!cogs.isZero) costs.add(CostLine(CostKind.cogs, cogs));
    if (!goodsLoss.isZero) costs.add(CostLine(CostKind.goodsLoss, goodsLoss));

    for (final c in i.charges) {
      // Cancelled orders only count money really spent (an actual amount).
      if (cancelled && c.actual == null) continue;
      // No COD fee when nothing was collected, unless the courier charged it.
      if (c.type == 'cod_fee' && fullReturn && c.actual == null) continue;
      final kind = switch (c.type) {
        'delivery_fee' => CostKind.deliveryFee,
        'cod_fee' => CostKind.codFee,
        'return_fee' => CostKind.returnFee,
        'packaging' => CostKind.packaging,
        'write_off' => CostKind.writeOff,
        _ => CostKind.other,
      };
      costs.add(CostLine(kind, c.effective, isExpected: c.actual == null));
    }

    final state = _state(i, cancelled: cancelled, fullReturn: fullReturn, missing: missing);
    return ProfitResult(
      revenue: revenue,
      deliveryCharge: delivery,
      costs: costs,
      state: state,
      missingCostLines: missing,
    );
  }

  static ProfitState _state(
    ProfitInput i, {
    required bool cancelled,
    required bool fullReturn,
    required List<String> missing,
  }) {
    if (missing.isNotEmpty) return ProfitState.incomplete;
    if (cancelled) return ProfitState.finalised;
    if (fullReturn) {
      return i.status == OrderStatus.returned
          ? ProfitState.finalised
          : ProfitState.provisional;
    }
    final delivered = i.status == OrderStatus.delivered;
    if (!delivered) return ProfitState.provisional;
    final isCod =
        i.paymentType != PaymentType.prepaid && i.codStatus != CodStatus.notApplicable;
    if (isCod) {
      return i.codStatus == CodStatus.settled
          ? ProfitState.finalised
          : ProfitState.provisional;
    }
    // Prepaid: final once every courier fee on record is an actual amount.
    final unconfirmed =
        i.charges.any((c) => _courierTypes.contains(c.type) && c.actual == null);
    return unconfirmed ? ProfitState.provisional : ProfitState.finalised;
  }
}
