import 'package:meta/meta.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/features/cod/domain/ledger.dart';

/// What to do with a shortfall (feature spec F6 §6.2 step 5).
enum ShortfallPolicy { allocate, dispute, writeOff }

enum ReconcileError {
  noOrders,
  totalNotPositive,
  negativeAmount,
  unknownOrder,
  allocationMismatch,
  exceedsOutstanding,
  shortfallNeedsPolicy,
}

@immutable
class ReconcileOrder {
  const ReconcileOrder({
    required this.id,
    required this.deliveredAt,
    required this.outstanding,
    this.orderNo = '',
    this.isDisputed = false,
  });

  final String id;
  final String orderNo;
  final DateTime? deliveredAt;
  final Money outstanding;
  final bool isDisputed;
}

@immutable
class AllocationLine {
  const AllocationLine(this.orderId, this.amount);
  final String orderId;
  final Money amount;
}

@immutable
class SettlementPlan {
  const SettlementPlan({
    required this.totalReceived,
    required this.allocations,
    this.writeOffs = const [],
    this.newlyDisputedIds = const {},
    this.overpaymentIds = const {},
  });

  final Money totalReceived;
  final List<AllocationLine> allocations;

  /// Remaining outstanding accepted as a loss, per order.
  final List<AllocationLine> writeOffs;

  /// Orders whose disputed flag this payout turned on.
  final Set<String> newlyDisputedIds;

  /// Orders that received more than their outstanding (explicit overpayment).
  final Set<String> overpaymentIds;

  Money get totalApplied => allocations.fold(Money.zero, (s, a) => s + a.amount);
}

@immutable
class PlanResult {
  const PlanResult.ok(SettlementPlan this.plan) : error = null;
  const PlanResult.err(ReconcileError this.error) : plan = null;

  final SettlementPlan? plan;
  final ReconcileError? error;
  bool get isOk => plan != null;
}

/// Pure reconciliation rules for courier payouts (implementation plan §5.6).
abstract final class PayoutReconciler {
  /// Oldest-delivered first, never more than each order's outstanding.
  /// Cash left after every order is covered stays unallocated.
  static List<AllocationLine> autoAllocate(List<ReconcileOrder> orders, Money total) {
    final sorted = [...orders]..sort((a, b) {
        final ad = a.deliveredAt;
        final bd = b.deliveredAt;
        if (ad == null && bd == null) return a.id.compareTo(b.id);
        if (ad == null) return 1;
        if (bd == null) return -1;
        final c = ad.compareTo(bd);
        return c != 0 ? c : a.id.compareTo(b.id);
      });
    var remaining = total;
    final out = <AllocationLine>[];
    for (final o in sorted) {
      if (remaining.poisha <= 0) break;
      if (o.outstanding.poisha <= 0) continue;
      final take = o.outstanding < remaining ? o.outstanding : remaining;
      out.add(AllocationLine(o.id, take));
      remaining -= take;
    }
    return out;
  }

  /// Sum of positive outstanding balances the payout is expected to cover.
  static Money expectedTotal(List<ReconcileOrder> orders) => orders.fold(
      Money.zero, (s, o) => o.outstanding.poisha > 0 ? s + o.outstanding : s);

  /// `received - expected`; negative is a shortfall.
  static Money difference(List<ReconcileOrder> orders, Money received) =>
      received - expectedTotal(orders);

  /// Validates and turns requested per-order amounts into a settlement plan.
  static PlanResult plan({
    required List<ReconcileOrder> orders,
    required List<AllocationLine> allocations,
    required Money totalReceived,
    ShortfallPolicy? policy,
    bool allowOverpayment = false,
  }) {
    if (orders.isEmpty) return const PlanResult.err(ReconcileError.noOrders);
    if (totalReceived.poisha <= 0) {
      return const PlanResult.err(ReconcileError.totalNotPositive);
    }
    final byId = {for (final o in orders) o.id: o};
    final applied = <String, Money>{};
    for (final a in allocations) {
      if (a.amount.isNegative) return const PlanResult.err(ReconcileError.negativeAmount);
      if (!byId.containsKey(a.orderId)) {
        return const PlanResult.err(ReconcileError.unknownOrder);
      }
      if (a.amount.isZero) continue;
      applied[a.orderId] = (applied[a.orderId] ?? Money.zero) + a.amount;
    }
    final sum = applied.values.fold(Money.zero, (s, m) => s + m);
    if (sum != totalReceived) {
      return const PlanResult.err(ReconcileError.allocationMismatch);
    }
    final overpaid = <String>{};
    for (final e in applied.entries) {
      final out = byId[e.key]!.outstanding;
      if (e.value > out) {
        if (!allowOverpayment) {
          return const PlanResult.err(ReconcileError.exceedsOutstanding);
        }
        overpaid.add(e.key);
      }
    }
    // Remaining balance on every selected order after this payout.
    final shortfalls = <AllocationLine>[];
    for (final o in orders) {
      final remaining = o.outstanding - (applied[o.id] ?? Money.zero);
      if (remaining.poisha > 0) shortfalls.add(AllocationLine(o.id, remaining));
    }
    if (shortfalls.isNotEmpty && policy == null) {
      return const PlanResult.err(ReconcileError.shortfallNeedsPolicy);
    }
    final lines = [
      for (final e in applied.entries) AllocationLine(e.key, e.value),
    ];
    return PlanResult.ok(SettlementPlan(
      totalReceived: totalReceived,
      allocations: lines,
      writeOffs: policy == ShortfallPolicy.writeOff ? shortfalls : const [],
      newlyDisputedIds: policy == ShortfallPolicy.dispute
          ? {
              for (final s in shortfalls)
                if (!byId[s.orderId]!.isDisputed) s.orderId,
            }
          : const {},
      overpaymentIds: overpaid,
    ));
  }

  /// Applies a plan to ledger states (pure).
  static Map<String, OrderLedgerState> apply(
    Map<String, OrderLedgerState> states,
    SettlementPlan plan,
  ) {
    final out = Map<String, OrderLedgerState>.of(states);
    for (final a in plan.allocations) {
      final s = out[a.orderId]!;
      out[a.orderId] = s.copyWith(settled: s.settled + a.amount);
    }
    for (final w in plan.writeOffs) {
      final s = out[w.orderId]!;
      out[w.orderId] = s.copyWith(writtenOff: s.writtenOff + w.amount);
    }
    for (final id in plan.newlyDisputedIds) {
      out[id] = out[id]!.copyWith(isDisputed: true);
    }
    return out;
  }

  /// Exact inverse of [apply] (payout reversal).
  static Map<String, OrderLedgerState> reverse(
    Map<String, OrderLedgerState> states,
    SettlementPlan plan,
  ) {
    final out = Map<String, OrderLedgerState>.of(states);
    for (final a in plan.allocations) {
      final s = out[a.orderId]!;
      out[a.orderId] = s.copyWith(settled: s.settled - a.amount);
    }
    for (final w in plan.writeOffs) {
      final s = out[w.orderId]!;
      out[w.orderId] = s.copyWith(writtenOff: s.writtenOff - w.amount);
    }
    for (final id in plan.newlyDisputedIds) {
      out[id] = out[id]!.copyWith(isDisputed: false);
    }
    return out;
  }
}
