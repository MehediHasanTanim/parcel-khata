import 'package:parcel_khata/features/orders/domain/order_enums.dart';

enum StuckLevel { none, amber, red }

/// Amber at N days with the courier, red at 2N (feature spec F4).
abstract final class StuckParcelPolicy {
  static StuckLevel level({
    required OrderStatus status,
    required DateTime? handedOverAt,
    required DateTime now,
    required int stuckDays,
  }) {
    if (!status.withCourier || handedOverAt == null || stuckDays <= 0) {
      return StuckLevel.none;
    }
    final days = now.difference(handedOverAt).inDays;
    if (days >= stuckDays * 2) return StuckLevel.red;
    if (days >= stuckDays) return StuckLevel.amber;
    return StuckLevel.none;
  }

  static int daysWithCourier(DateTime handedOverAt, DateTime now) =>
      now.difference(handedOverAt).inDays;
}
