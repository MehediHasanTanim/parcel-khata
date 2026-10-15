/// Explainable, seller-private customer risk badges (feature spec F12).
/// Pure Dart. No opaque score: every badge carries the orders behind it.
library;

enum RiskBadgeKind { reliable, refusedLastCod, highReturnRate, newCustomer, blocklisted }

enum RiskOutcome { delivered, returned, other }

/// Reasons that count as the customer's doing (not the seller's address data).
const kCustomerFaultReasons = {
  'customer_refused',
  'not_reachable',
  'changed_mind',
  'fake_order',
};

class RiskOrderFact {
  const RiskOrderFact({
    required this.orderId,
    required this.orderDate,
    required this.outcome,
    this.isCod = true,
    this.reason,
  });

  final String orderId;
  final DateTime orderDate;
  final RiskOutcome outcome;

  /// Cash on delivery (not prepaid): only COD refusals are a payment risk.
  final bool isCod;

  /// Return / failed-delivery reason code, if any.
  final String? reason;

  bool get isFake => reason == 'fake_order';
  bool get isCustomerFault => reason != null && kCustomerFaultReasons.contains(reason);
}

class RiskThresholds {
  const RiskThresholds({
    this.returnRatePercent = 40,
    this.minOrders = 3,
    this.refusalRecencyDays = 90,
  });

  /// Badge when returned / resolved orders >= this percentage.
  final int returnRatePercent;

  /// Rate-based badges (reliable / high return) need at least this many
  /// resolved (delivered or returned) orders.
  final int minOrders;

  /// A refused COD only counts while it is at most this many days old.
  final int refusalRecencyDays;
}

class RiskBadge {
  const RiskBadge(this.kind, this.orderIds);
  final RiskBadgeKind kind;

  /// The orders that caused the badge (empty for manual/new).
  final List<String> orderIds;

  /// Badges that should trigger the order-form warning.
  bool get isWarning =>
      kind == RiskBadgeKind.refusedLastCod ||
      kind == RiskBadgeKind.highReturnRate ||
      kind == RiskBadgeKind.blocklisted;
}

class CustomerRiskScorer {
  const CustomerRiskScorer();

  /// [orders] must exclude drafts and cancelled orders (they have no outcome);
  /// anything still in flight is passed as [RiskOutcome.other].
  List<RiskBadge> score({
    required List<RiskOrderFact> orders,
    required DateTime now,
    RiskThresholds thresholds = const RiskThresholds(),
    bool isBlocklisted = false,
  }) {
    final badges = <RiskBadge>[];
    if (isBlocklisted) badges.add(const RiskBadge(RiskBadgeKind.blocklisted, []));

    final resolved =
        orders.where((o) => o.outcome != RiskOutcome.other).toList()
          ..sort((a, b) {
            final c = a.orderDate.compareTo(b.orderDate);
            return c != 0 ? c : a.orderId.compareTo(b.orderId);
          });
    final returned =
        resolved.where((o) => o.outcome == RiskOutcome.returned).toList();
    final delivered =
        resolved.where((o) => o.outcome == RiskOutcome.delivered).toList();

    // Most recent resolved COD order: refused => warn, while still recent.
    final codResolved = resolved.where((o) => o.isCod).toList();
    if (codResolved.isNotEmpty) {
      final last = codResolved.last;
      final ageDays = now.difference(last.orderDate).inDays;
      if (last.outcome == RiskOutcome.returned &&
          last.isCustomerFault &&
          ageDays <= thresholds.refusalRecencyDays) {
        badges.add(RiskBadge(RiskBadgeKind.refusedLastCod, [last.orderId]));
      }
    }

    final enough = resolved.length >= thresholds.minOrders;
    final highRate = enough &&
        returned.length * 100 >= thresholds.returnRatePercent * resolved.length;
    if (highRate) {
      badges.add(RiskBadge(
          RiskBadgeKind.highReturnRate, returned.map((o) => o.orderId).toList()));
    }

    if (resolved.isEmpty) {
      badges.add(const RiskBadge(RiskBadgeKind.newCustomer, []));
    } else if (enough && returned.isEmpty && !isBlocklisted) {
      badges.add(RiskBadge(
          RiskBadgeKind.reliable, delivered.map((o) => o.orderId).toList()));
    }
    return badges;
  }
}
