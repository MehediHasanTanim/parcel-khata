import 'package:meta/meta.dart';
import 'package:parcel_khata/core/money/money.dart';

/// Charge types the courier deducts from what it pays the seller.
/// Packaging is the seller's own cost and is never a courier deduction.
const kCourierDeductionTypes = {'delivery_fee', 'cod_fee', 'return_fee', 'other'};

/// Loss accepted on a payout shortfall; reduces outstanding like cash would.
const kWriteOffType = 'write_off';

@immutable
class ChargeAmount {
  const ChargeAmount({required this.type, required this.expected, this.actual});

  final String type;
  final Money expected;

  /// Recorded at settlement; always preferred over [expected].
  final Money? actual;

  Money get effective => actual ?? expected;
}

/// Money position of one order with its courier (feature spec F6 §6.1).
@immutable
class OrderLedgerState {
  const OrderLedgerState({
    required this.collected,
    required this.deductions,
    this.settled = Money.zero,
    this.writtenOff = Money.zero,
    this.isDisputed = false,
  });

  /// What the courier actually collected from the customer.
  final Money collected;

  /// Delivery + COD + return + other courier deductions.
  final Money deductions;

  /// Cash received for this order through active payouts.
  final Money settled;
  final Money writtenOff;
  final bool isDisputed;

  Money get netReceivable => collected - deductions;
  Money get outstanding => netReceivable - settled - writtenOff;

  OrderLedgerState copyWith({
    Money? collected,
    Money? deductions,
    Money? settled,
    Money? writtenOff,
    bool? isDisputed,
  }) =>
      OrderLedgerState(
        collected: collected ?? this.collected,
        deductions: deductions ?? this.deductions,
        settled: settled ?? this.settled,
        writtenOff: writtenOff ?? this.writtenOff,
        isDisputed: isDisputed ?? this.isDisputed,
      );

  @override
  bool operator ==(Object other) =>
      other is OrderLedgerState &&
      other.collected == collected &&
      other.deductions == deductions &&
      other.settled == settled &&
      other.writtenOff == writtenOff &&
      other.isDisputed == isDisputed;

  @override
  int get hashCode => Object.hash(collected, deductions, settled, writtenOff, isDisputed);

  @override
  String toString() =>
      'Ledger(collected: $collected, deductions: $deductions, settled: $settled, '
      'writtenOff: $writtenOff, disputed: $isDisputed, outstanding: $outstanding)';
}

/// A rate-card return fee is only a real cost once something is returned.
/// Without any return it is an expectation that never materializes, so it
/// must not reduce net receivable or profit. An actual amount always counts.
List<ChargeAmount> relevantCharges(Iterable<ChargeAmount> charges, {required bool hasReturn}) => [
      for (final c in charges)
        if (hasReturn || c.type != 'return_fee' || c.actual != null) c,
    ];

abstract final class LedgerCalculator {
  /// Actual overrides expected per charge (ChargeCalculator v2).
  static Money deductions(Iterable<ChargeAmount> charges) => charges
      .where((c) => kCourierDeductionTypes.contains(c.type))
      .fold(Money.zero, (s, c) => s + c.effective);

  static Money writtenOff(Iterable<ChargeAmount> charges) => charges
      .where((c) => c.type == kWriteOffType)
      .fold(Money.zero, (s, c) => s + c.effective);

  static OrderLedgerState state({
    required Money collected,
    required Iterable<ChargeAmount> charges,
    Money settled = Money.zero,
    bool isDisputed = false,
  }) =>
      OrderLedgerState(
        collected: collected,
        deductions: deductions(charges),
        settled: settled,
        writtenOff: writtenOff(charges),
        isDisputed: isDisputed,
      );
}
