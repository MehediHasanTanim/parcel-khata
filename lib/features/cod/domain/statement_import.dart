import 'package:meta/meta.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/features/cod/domain/ledger.dart';
import 'package:parcel_khata/features/cod/domain/payout_reconciler.dart';
import 'package:parcel_khata/features/couriers/domain/cn_normalizer.dart';

/// One parsed line of a courier's payout statement.
@immutable
class StatementRow {
  const StatementRow({
    required this.row,
    required this.cnRaw,
    this.collected,
    this.deliveryFee,
    this.codFee,
    this.returnFee,
    this.netPayable,
    this.status,
    this.date,
  });

  /// 1-based data row (header excluded).
  final int row;
  final String cnRaw;

  /// COD the courier says it collected.
  final Money? collected;
  final Money? deliveryFee;
  final Money? codFee;
  final Money? returnFee;

  /// What the courier says it is paying for this parcel.
  final Money? netPayable;
  final String? status;
  final DateTime? date;
}

/// An order of the chosen courier as the ledger sees it right now.
@immutable
class StatementOrder {
  const StatementOrder({
    required this.id,
    required this.orderNo,
    required this.cn,
    required this.collected,
    this.charges = const [],
    this.settled = Money.zero,
    this.isDisputed = false,
    this.hasReturn = false,
    this.deliveredAt,
  });

  final String id;
  final String orderNo;
  final String cn;

  /// What the courier is recorded as having collected (collected, else COD).
  final Money collected;
  final List<ChargeAmount> charges;
  final Money settled;
  final bool isDisputed;
  final bool hasReturn;
  final DateTime? deliveredAt;

  OrderLedgerState ledger({Money? collectedOverride, List<ChargeAmount>? chargesOverride}) =>
      LedgerCalculator.state(
        collected: collectedOverride ?? collected,
        charges: relevantCharges(chargesOverride ?? charges, hasReturn: hasReturn),
        settled: settled,
        isDisputed: isDisputed,
      );

  Money get outstanding => ledger().outstanding;
}

enum StatementOutcome { matched, unknownCn, duplicateInFile, amountMismatch, alreadySettled }

@immutable
class MatchedRow {
  const MatchedRow(this.row, this.outcome, {this.order, this.difference});

  final StatementRow row;
  final StatementOutcome outcome;
  final StatementOrder? order;

  /// Statement collected minus recorded collected (only when both known).
  final Money? difference;
}

abstract final class StatementMatcher {
  /// Comparison key: normalized, case-insensitive, punctuation-free, and
  /// leading zeros dropped from all-digit numbers (spreadsheets eat them).
  static String cnKey(String raw) {
    var s = CnNormalizer.normalize(raw).toLowerCase();
    s = s.replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (RegExp(r'^\d+$').hasMatch(s)) s = s.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    return s;
  }

  /// Deterministic: rows are classified in file order. [tolerance] is the
  /// largest collected-amount difference still considered a match.
  static List<MatchedRow> match(
    List<StatementRow> rows,
    List<StatementOrder> orders, {
    Money tolerance = Money.zero,
  }) {
    final byKey = <String, List<StatementOrder>>{};
    for (final o in orders) {
      final k = cnKey(o.cn);
      if (k.isEmpty) continue;
      byKey.putIfAbsent(k, () => []).add(o);
    }
    final seen = <String>{};
    final out = <MatchedRow>[];
    for (final r in rows) {
      final k = cnKey(r.cnRaw);
      if (k.isEmpty) {
        out.add(MatchedRow(r, StatementOutcome.unknownCn));
        continue;
      }
      if (!seen.add(k)) {
        out.add(MatchedRow(r, StatementOutcome.duplicateInFile));
        continue;
      }
      final candidates = byKey[k];
      // An ambiguous CN is never guessed.
      if (candidates == null || candidates.length != 1) {
        out.add(MatchedRow(r, StatementOutcome.unknownCn));
        continue;
      }
      final o = candidates.single;
      if (o.outstanding.poisha <= 0) {
        out.add(MatchedRow(r, StatementOutcome.alreadySettled, order: o));
        continue;
      }
      final diff = r.collected == null ? null : r.collected! - o.collected;
      if (diff != null && diff.poisha.abs() > tolerance.poisha) {
        out.add(MatchedRow(r, StatementOutcome.amountMismatch, order: o, difference: diff));
        continue;
      }
      out.add(MatchedRow(r, StatementOutcome.matched, order: o, difference: diff));
    }
    return out;
  }
}

/// Seller's choice for one reviewed row.
@immutable
class StatementDecision {
  const StatementDecision(
    this.matched, {
    this.include = true,
    this.adjustCollected = false,
    this.reason,
  });

  final MatchedRow matched;
  final bool include;

  /// Replace the recorded collected amount by the statement's (needs reason).
  final bool adjustCollected;
  final String? reason;
}

@immutable
class FeeUpdate {
  const FeeUpdate(this.orderId, this.type, this.amount);
  final String orderId;
  final String type;
  final Money amount;
}

@immutable
class CollectedAdjustment {
  const CollectedAdjustment(this.orderId, this.amount, this.reason);
  final String orderId;
  final Money amount;
  final String reason;
}

enum StatementPlanError { nothingSelected, ineligibleRow, reasonRequired, reconcile }

@immutable
class StatementPlan {
  const StatementPlan({
    required this.feeUpdates,
    required this.adjustments,
    required this.allocations,
    required this.selectedOrderIds,
    required this.totalReceived,
    required this.settlement,
  });

  final List<FeeUpdate> feeUpdates;
  final List<CollectedAdjustment> adjustments;
  final List<AllocationLine> allocations;

  /// Orders whose shortfall the chosen policy is judged on.
  final List<String> selectedOrderIds;
  final Money totalReceived;

  /// Result of the existing reconciler for these allocations.
  final PlanResult settlement;
}

@immutable
class StatementPlanResult {
  const StatementPlanResult.ok(StatementPlan this.plan)
      : error = null,
        reconcileError = null;
  const StatementPlanResult.err(StatementPlanError this.error, {this.reconcileError})
      : plan = null;

  final StatementPlan? plan;
  final StatementPlanError? error;
  final ReconcileError? reconcileError;
  bool get isOk => plan != null;
}

abstract final class StatementPlanBuilder {
  static StatementPlanResult build(
    List<StatementDecision> decisions, {
    ShortfallPolicy? policy,
    bool allowOverpayment = false,
  }) {
    final chosen = decisions.where((d) => d.include).toList();
    if (chosen.isEmpty) return const StatementPlanResult.err(StatementPlanError.nothingSelected);

    final fees = <FeeUpdate>[];
    final adjustments = <CollectedAdjustment>[];
    final allocations = <AllocationLine>[];
    final reconcile = <ReconcileOrder>[];
    final seenOrders = <String>{};

    for (final d in chosen) {
      final m = d.matched;
      final o = m.order;
      final eligible = o != null &&
          (m.outcome == StatementOutcome.matched ||
              m.outcome == StatementOutcome.amountMismatch);
      if (!eligible) return const StatementPlanResult.err(StatementPlanError.ineligibleRow);
      if (!seenOrders.add(o.id)) {
        return const StatementPlanResult.err(StatementPlanError.ineligibleRow);
      }
      final r = m.row;

      // Simulate the order after the statement's actual fees / collection.
      var charges = [...o.charges];
      void setFee(String type, Money? v) {
        if (v == null) return;
        fees.add(FeeUpdate(o.id, type, v));
        final existing = charges.indexWhere((c) => c.type == type);
        final expected = existing >= 0 ? charges[existing].expected : Money.zero;
        final updated = ChargeAmount(type: type, expected: expected, actual: v);
        if (existing >= 0) {
          charges[existing] = updated;
        } else {
          charges = [...charges, updated];
        }
      }

      setFee('delivery_fee', r.deliveryFee);
      setFee('cod_fee', r.codFee);
      setFee('return_fee', r.returnFee);

      var collected = o.collected;
      if (d.adjustCollected && r.collected != null) {
        if ((d.reason ?? '').trim().isEmpty) {
          return const StatementPlanResult.err(StatementPlanError.reasonRequired);
        }
        collected = r.collected!;
        adjustments.add(CollectedAdjustment(o.id, collected, d.reason!.trim()));
      }
      final after = o.ledger(collectedOverride: collected, chargesOverride: charges);
      final outstanding = after.outstanding;
      reconcile.add(ReconcileOrder(
        id: o.id,
        orderNo: o.orderNo,
        deliveredAt: o.deliveredAt,
        outstanding: outstanding,
        isDisputed: o.isDisputed,
      ));

      // Pay what the statement says, but never more than is outstanding
      // unless overpayment was explicitly allowed.
      var pay = r.netPayable ?? outstanding;
      if (pay.isNegative) pay = Money.zero;
      if (pay > outstanding && !allowOverpayment) {
        pay = outstanding.poisha > 0 ? outstanding : Money.zero;
      }
      if (pay.poisha > 0) allocations.add(AllocationLine(o.id, pay));
    }

    final total = allocations.fold(Money.zero, (s, a) => s + a.amount);
    final settlement = PayoutReconciler.plan(
      orders: reconcile,
      allocations: allocations,
      totalReceived: total,
      policy: policy,
      allowOverpayment: allowOverpayment,
    );
    return StatementPlanResult.ok(StatementPlan(
      feeUpdates: fees,
      adjustments: adjustments,
      allocations: allocations,
      selectedOrderIds: [for (final r in reconcile) r.id],
      totalReceived: total,
      settlement: settlement,
    ));
  }
}
