import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parcel_khata/core/db/app_database.dart';
import 'package:parcel_khata/core/db/providers.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/core/providers.dart';
import 'package:parcel_khata/core/time/clock.dart';
import 'package:parcel_khata/core/time/providers.dart';
import 'package:parcel_khata/features/cod/application/payout_service.dart';
import 'package:parcel_khata/features/orders/domain/order_enums.dart';

class CodSummary {
  const CodSummary({
    required this.pending,
    required this.inTransit,
    required this.disputed,
    required this.settledThisMonth,
  });

  /// Delivered, courier holds the cash (excluding disputed).
  final Money pending;

  /// With the courier, not delivered yet (forecast).
  final Money inTransit;
  final Money disputed;
  final Money settledThisMonth;
}

class CourierPending {
  const CourierPending({
    required this.courier,
    required this.total,
    required this.orderCount,
    required this.overdueCount,
    required this.overdueTotal,
    required this.oldestAgeDays,
  });

  final Courier courier;
  final Money total;
  final int orderCount;
  final int overdueCount;
  final Money overdueTotal;
  final int oldestAgeDays;
}

enum AgeBucket {
  d0to3(0, 3),
  d4to7(4, 7),
  d8to14(8, 14),
  d15plus(15, null);

  const AgeBucket(this.minDays, this.maxDays);
  final int minDays;
  final int? maxDays;

  static AgeBucket of(int days) =>
      AgeBucket.values.lastWhere((b) => days >= b.minDays, orElse: () => AgeBucket.d0to3);
}

class AgeingRow {
  const AgeingRow(this.bucket, this.count, this.total);
  final AgeBucket bucket;
  final int count;
  final Money total;
}

class OpenCodOrder {
  const OpenCodOrder(this.order, this.courier, this.ageDays);
  final Order order;
  final Courier? courier;

  /// Whole days since delivery (0 when not stamped).
  final int ageDays;

  Money get outstanding => Money(order.outstanding ?? 0);
}

/// Read-side COD views (feature spec F6 §6.3). All figures are derived from
/// the cached ledger columns that the ledger writer keeps in sync.
class CodQueries {
  CodQueries(this._db, this._clock, this._shopId);

  final AppDatabase _db;
  final Clock _clock;
  final String _shopId;

  Future<List<OpenCodOrder>> openOrders({
    String? courierId,
    AgeBucket? bucket,
    bool disputedOnly = false,
  }) async {
    final o = _db.orders;
    final q = _db.select(o).join([
      leftOuterJoin(_db.couriers, _db.couriers.id.equalsExp(o.courierId)),
    ])
      ..where(o.shopId.equals(_shopId) &
          o.deletedAt.isNull() &
          (disputedOnly
              ? o.codStatus.equals(CodStatus.disputed.dbValue)
              : o.codStatus.isIn(kCodOpenStatuses)) &
          (courierId == null ? const Constant(true) : o.courierId.equals(courierId)))
      ..orderBy([OrderingTerm.asc(o.deliveredAt), OrderingTerm.asc(o.id)]);
    final now = _clock.now();
    final rows = <OpenCodOrder>[];
    for (final r in await q.get()) {
      final order = r.readTable(o);
      final age = order.deliveredAt == null ? 0 : now.difference(order.deliveredAt!).inDays;
      if (bucket != null && AgeBucket.of(age) != bucket) continue;
      rows.add(OpenCodOrder(order, r.readTableOrNull(_db.couriers), age));
    }
    return rows;
  }

  Future<List<CourierPending>> pendingByCourier() async {
    final open = await openOrders();
    final byCourier = <String, List<OpenCodOrder>>{};
    for (final r in open) {
      if (r.courier == null) continue;
      byCourier.putIfAbsent(r.courier!.id, () => []).add(r);
    }
    final out = <CourierPending>[];
    for (final list in byCourier.values) {
      final c = list.first.courier!;
      var total = Money.zero;
      var overdueTotal = Money.zero;
      var overdue = 0;
      var oldest = 0;
      for (final r in list) {
        total += r.outstanding;
        if (r.ageDays > oldest) oldest = r.ageDays;
        // Overdue when waiting longer than the courier's payout cycle (AC5).
        if (r.ageDays > c.payoutCycleDays) {
          overdue++;
          overdueTotal += r.outstanding;
        }
      }
      out.add(CourierPending(
        courier: c,
        total: total,
        orderCount: list.length,
        overdueCount: overdue,
        overdueTotal: overdueTotal,
        oldestAgeDays: oldest,
      ));
    }
    out.sort((a, b) => b.total.compareTo(a.total));
    return out;
  }

  Future<CodSummary> summary() async {
    final o = _db.orders;
    final open = await openOrders();
    var pending = Money.zero;
    var disputed = Money.zero;
    for (final r in open) {
      if (r.order.codStatus == CodStatus.disputed.dbValue) {
        disputed += r.outstanding;
      } else {
        pending += r.outstanding;
      }
    }
    final inTransitSum = o.codExpected.sum();
    final t = await (_db.selectOnly(o)
          ..addColumns([inTransitSum])
          ..where(o.shopId.equals(_shopId) &
              o.deletedAt.isNull() &
              o.status.isIn([
                OrderStatus.handedToCourier.dbValue,
                OrderStatus.inTransit.dbValue,
              ]) &
              o.codStatus.equals(CodStatus.pendingCollection.dbValue)))
        .getSingle();
    final now = _clock.now();
    final monthStart = DateTime(now.year, now.month);
    final paid = _db.payouts.totalReceived.sum();
    final p = await (_db.selectOnly(_db.payouts)
          ..addColumns([paid])
          ..where(_db.payouts.shopId.equals(_shopId) &
              _db.payouts.status.equals('active') &
              _db.payouts.paidAt.isBiggerOrEqualValue(monthStart)))
        .getSingle();
    return CodSummary(
      pending: pending,
      inTransit: Money(t.read(inTransitSum) ?? 0),
      disputed: disputed,
      settledThisMonth: Money(p.read(paid) ?? 0),
    );
  }

  Future<List<AgeingRow>> ageing({String? courierId}) async {
    final open = await openOrders(courierId: courierId);
    return [
      for (final b in AgeBucket.values)
        () {
          final inB = open.where((r) => AgeBucket.of(r.ageDays) == b).toList();
          return AgeingRow(
            b,
            inB.length,
            inB.fold(Money.zero, (s, r) => s + r.outstanding),
          );
        }(),
    ];
  }
}

final codQueriesProvider = Provider<CodQueries>((ref) => CodQueries(
      ref.watch(databaseProvider),
      ref.watch(clockProvider),
      ref.watch(shopIdProvider),
    ));

/// Re-emits on any ledger-affecting change.
final codRevisionProvider = StreamProvider<int>((ref) async* {
  final s = ref.watch(payoutServiceProvider);
  var n = 0;
  yield n;
  await for (final _ in s.changes) {
    yield ++n;
  }
});

final codSummaryProvider = FutureProvider<CodSummary>((ref) {
  ref.watch(codRevisionProvider);
  return ref.watch(codQueriesProvider).summary();
});

final courierPendingProvider = FutureProvider<List<CourierPending>>((ref) {
  ref.watch(codRevisionProvider);
  return ref.watch(codQueriesProvider).pendingByCourier();
});
