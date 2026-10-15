import 'package:meta/meta.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/features/cod/domain/ledger.dart';
import 'package:parcel_khata/features/orders/domain/order_enums.dart';

@immutable
class CodStatusInput {
  const CodStatusInput({
    required this.paymentType,
    required this.codExpected,
    required this.status,
    this.ledger,
  });

  final PaymentType paymentType;
  final Money codExpected;
  final OrderStatus status;

  /// Null until the courier has collected cash (delivered).
  final OrderLedgerState? ledger;
}

/// Derives the COD status from order status + ledger (spec §4.2 and F6).
/// Disputed is an explicit flag on the ledger, never inferred.
abstract final class CodStatusResolver {
  static CodStatus resolve(CodStatusInput i) {
    if (i.paymentType == PaymentType.prepaid || i.codExpected.isZero) {
      return CodStatus.notApplicable;
    }
    final l = i.ledger;
    final collected = l != null && l.collected.poisha > 0;

    switch (i.status) {
      case OrderStatus.draft:
      case OrderStatus.confirmed:
      case OrderStatus.packed:
      case OrderStatus.handedToCourier:
      case OrderStatus.inTransit:
        return CodStatus.pendingCollection;
      case OrderStatus.deliveryFailed:
      case OrderStatus.returnInTransit:
      case OrderStatus.returned:
      case OrderStatus.cancelled:
        // A partial return keeps the collected part in the ledger (Sprint 5).
        if (!collected) return CodStatus.notCollected;
      case OrderStatus.delivered:
        break;
    }
    if (l == null) return CodStatus.collectedByCourier;
    if (l.isDisputed && l.outstanding.poisha > 0) return CodStatus.disputed;
    if (l.outstanding.poisha <= 0) return CodStatus.settled;
    if (l.settled.poisha > 0 || l.writtenOff.poisha > 0) return CodStatus.partiallySettled;
    return CodStatus.collectedByCourier;
  }
}
