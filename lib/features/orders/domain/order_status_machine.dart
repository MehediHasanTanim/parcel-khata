import 'package:parcel_khata/features/orders/domain/order_enums.dart';

enum TransitionError {
  notAllowed,
  courierRequired,
  cnRequired,
  reasonRequired,
  futureDate,
  beforeInitiated,
}

/// Reserved reason key written on correction events.
const kCorrectionReason = 'correction';

const kFailedReasons = [
  'customer_refused',
  'not_reachable',
  'wrong_address',
  'courier_issue',
  'other',
];

const kCancelReasons = [
  'customer_cancelled',
  'out_of_stock',
  'wrong_address',
  'other',
];

/// Pure transition table + guards (feature spec F5, implementation plan §5.2).
class OrderStatusMachine {
  const OrderStatusMachine({this.packedEnabled = true, this.inTransitEnabled = true});

  final bool packedEnabled;
  final bool inTransitEnabled;

  /// Forward transitions offered by default. Drafts are promoted through the
  /// order form, not here. Optional steps follow the shop settings.
  List<OrderStatus> allowedNext(OrderStatus from) {
    final next = switch (from) {
      OrderStatus.draft => <OrderStatus>[],
      OrderStatus.confirmed => [
          if (packedEnabled) OrderStatus.packed,
          OrderStatus.handedToCourier,
          OrderStatus.cancelled,
        ],
      OrderStatus.packed => [OrderStatus.handedToCourier, OrderStatus.cancelled],
      OrderStatus.handedToCourier => [
          if (inTransitEnabled) OrderStatus.inTransit,
          OrderStatus.delivered,
          OrderStatus.deliveryFailed,
        ],
      OrderStatus.inTransit => [OrderStatus.delivered, OrderStatus.deliveryFailed],
      OrderStatus.deliveryFailed => [OrderStatus.returnInTransit, OrderStatus.returned],
      OrderStatus.returnInTransit => [OrderStatus.returned],
      OrderStatus.delivered ||
      OrderStatus.returned ||
      OrderStatus.cancelled =>
        <OrderStatus>[],
    };
    return next;
  }

  static bool requiresReason(OrderStatus to) =>
      to == OrderStatus.deliveryFailed || to == OrderStatus.cancelled;

  /// Returns the first violated guard, or null when the move is valid.
  TransitionError? validate({
    required OrderStatus from,
    required OrderStatus to,
    required DateTime at,
    required DateTime now,
    required bool hasCourier,
    required bool hasCn,
    String? reason,
    DateTime? returnInitiatedAt,
  }) {
    if (!allowedNext(from).contains(to)) return TransitionError.notAllowed;
    return _guards(
      to: to,
      at: at,
      now: now,
      hasCourier: hasCourier,
      hasCn: hasCn,
      reason: reason,
      returnInitiatedAt: returnInitiatedAt,
    );
  }

  /// Same guards without the transition table (used by status correction).
  TransitionError? validateCorrection({
    required OrderStatus to,
    required DateTime at,
    required DateTime now,
    required bool hasCourier,
    required bool hasCn,
  }) {
    if (to == OrderStatus.draft) return TransitionError.notAllowed;
    if (at.isAfter(now)) return TransitionError.futureDate;
    // A corrected status that implies the courier holds or delivered the
    // parcel still needs the courier and CN on record.
    const needsCourier = {
      OrderStatus.handedToCourier,
      OrderStatus.inTransit,
      OrderStatus.delivered,
    };
    if (needsCourier.contains(to)) {
      if (!hasCourier) return TransitionError.courierRequired;
      if (!hasCn) return TransitionError.cnRequired;
    }
    return null;
  }

  TransitionError? _guards({
    required OrderStatus to,
    required DateTime at,
    required DateTime now,
    required bool hasCourier,
    required bool hasCn,
    String? reason,
    DateTime? returnInitiatedAt,
  }) {
    if (at.isAfter(now)) return TransitionError.futureDate;
    if (to == OrderStatus.handedToCourier) {
      if (!hasCourier) return TransitionError.courierRequired;
      if (!hasCn) return TransitionError.cnRequired;
    }
    if (requiresReason(to) && (reason == null || reason.trim().isEmpty)) {
      return TransitionError.reasonRequired;
    }
    if (to == OrderStatus.returned &&
        returnInitiatedAt != null &&
        at.isBefore(returnInitiatedAt)) {
      return TransitionError.beforeInitiated;
    }
    return null;
  }
}
