import 'package:meta/meta.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/features/orders/domain/order_enums.dart';

enum AllocationMode {
  byCount('by_count'),
  byRevenue('by_revenue');

  const AllocationMode(this.dbValue);
  final String dbValue;

  static AllocationMode fromDb(String v) => AllocationMode.values
      .firstWhere((m) => m.dbValue == v, orElse: () => AllocationMode.byCount);
}

@immutable
class CampaignWindow {
  const CampaignWindow({
    required this.tag,
    required this.start,
    required this.endExclusive,
    required this.spend,
    required this.mode,
  });

  final String tag;

  /// Inclusive start, exclusive end (the UI passes the end date + 1 day).
  final DateTime start;
  final DateTime endExclusive;
  final Money spend;
  final AllocationMode mode;
}

@immutable
class CampaignOrder {
  const CampaignOrder({
    required this.id,
    required this.orderDate,
    required this.status,
    required this.tags,
    required this.weight,
  });

  final String id;
  final DateTime orderDate;
  final OrderStatus status;
  final List<String> tags;

  /// Kept revenue used by `byRevenue` (poisha, >= 0).
  final int weight;
}

/// Spreads a campaign's spend across its orders so shares always add up to
/// the spend exactly (feature spec F13).
abstract final class AdAllocator {
  /// Orders that carry the tag and fall inside the window. Cancelled orders
  /// and drafts never absorb ad cost.
  static List<CampaignOrder> eligible(CampaignWindow c, Iterable<CampaignOrder> orders) {
    return [
      for (final o in orders)
        if (o.tags.contains(c.tag) &&
            o.status != OrderStatus.draft &&
            o.status != OrderStatus.cancelled &&
            !o.orderDate.isBefore(c.start) &&
            o.orderDate.isBefore(c.endExclusive))
          o,
    ]..sort((a, b) => a.id.compareTo(b.id));
  }

  /// Order id -> share. Deterministic: remainders go by largest fractional
  /// part, ties by id. Empty when there are no eligible orders.
  static Map<String, Money> allocate(
    Money spend,
    List<CampaignOrder> orders,
    AllocationMode mode,
  ) {
    if (orders.isEmpty || spend.poisha <= 0) return {};
    final sorted = [...orders]..sort((a, b) => a.id.compareTo(b.id));
    final n = sorted.length;
    final total = spend.poisha;

    final weights = [
      for (final o in sorted)
        mode == AllocationMode.byRevenue && o.weight > 0 ? o.weight : 0,
    ];
    final weightSum = weights.fold(0, (s, w) => s + w);
    final useWeights = mode == AllocationMode.byRevenue && weightSum > 0;

    final shares = List<int>.filled(n, 0);
    // Fractional remainder numerators over a common denominator.
    final remainders = List<int>.filled(n, 0);
    final denom = useWeights ? weightSum : n;
    for (var i = 0; i < n; i++) {
      final w = useWeights ? weights[i] : 1;
      final exact = total * w;
      shares[i] = exact ~/ denom;
      remainders[i] = exact % denom;
    }
    var left = total - shares.fold(0, (s, v) => s + v);
    final order = List<int>.generate(n, (i) => i)
      ..sort((a, b) {
        final c = remainders[b].compareTo(remainders[a]);
        return c != 0 ? c : sorted[a].id.compareTo(sorted[b].id);
      });
    for (var k = 0; left > 0; k++, left--) {
      shares[order[k % n]] += 1;
    }
    return {for (var i = 0; i < n; i++) sorted[i].id: Money(shares[i])};
  }
}
