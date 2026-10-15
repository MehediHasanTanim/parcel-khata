import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parcel_khata/core/db/app_database.dart';
import 'package:parcel_khata/core/db/providers.dart';
import 'package:parcel_khata/core/time/clock.dart';
import 'package:parcel_khata/core/time/providers.dart';
import 'package:parcel_khata/features/customers/domain/customer_risk.dart';
import 'package:parcel_khata/features/orders/domain/order_enums.dart';
import 'package:parcel_khata/features/settings/application/settings_repository.dart';

/// Derived, never stored: recomputed from the seller's own orders.
class CustomerRisk {
  const CustomerRisk({
    required this.badges,
    required this.facts,
    this.riskNote,
    this.blocklistReason,
    this.isBlocklisted = false,
  });

  final List<RiskBadge> badges;
  final List<RiskOrderFact> facts;
  final String? riskNote;
  final String? blocklistReason;
  final bool isBlocklisted;

  bool get hasWarning =>
      badges.any((b) => b.isWarning) || (riskNote != null && riskNote!.isNotEmpty);
  RiskBadge? badge(RiskBadgeKind k) {
    for (final b in badges) {
      if (b.kind == k) return b;
    }
    return null;
  }
}

class CustomerRiskQueries {
  CustomerRiskQueries(this._db, this._clock, this._settings);

  final AppDatabase _db;
  final Clock _clock;
  final SettingsRepository _settings;

  static const _failedStatuses = {'delivery_failed', 'return_in_transit', 'returned'};

  Future<CustomerRisk> assess(String customerId) async {
    final customer = await (_db.select(_db.customers)
          ..where((c) => c.id.equals(customerId)))
        .getSingleOrNull();
    final settings = await _settings.read();
    final orders = await (_db.select(_db.orders)
          ..where((o) =>
              o.customerId.equals(customerId) &
              o.deletedAt.isNull() &
              o.status.isNotIn(['draft', 'cancelled'])))
        .get();
    final ids = [for (final o in orders) o.id];
    final reasons = <String, String>{};
    if (ids.isNotEmpty) {
      final events = await (_db.select(_db.orderStatusEvents)
            ..where((e) =>
                e.orderId.isIn(ids) &
                e.reason.isNotNull() &
                e.toStatus.isIn(_failedStatuses))
            ..orderBy([(e) => OrderingTerm.asc(e.at)]))
          .get();
      for (final e in events) {
        reasons[e.orderId] = e.reason!;
      }
      final returns = await (_db.select(_db.returnRecords)
            ..where((r) => r.orderId.isIn(ids) & r.deletedAt.isNull())
            ..orderBy([(r) => OrderingTerm.asc(r.initiatedAt)]))
          .get();
      // A return record carries the authoritative reason.
      for (final r in returns) {
        reasons[r.orderId] = r.reason;
      }
    }
    final facts = <RiskOrderFact>[
      for (final o in orders)
        RiskOrderFact(
          orderId: o.id,
          orderDate: o.orderDate,
          outcome: switch (OrderStatus.fromDb(o.status)) {
            OrderStatus.delivered => RiskOutcome.delivered,
            OrderStatus.returned ||
            OrderStatus.returnInTransit ||
            OrderStatus.deliveryFailed =>
              RiskOutcome.returned,
            _ => RiskOutcome.other,
          },
          isCod: o.paymentType != PaymentType.prepaid.dbValue,
          reason: reasons[o.id],
        ),
    ];
    final badges = const CustomerRiskScorer().score(
      orders: facts,
      now: _clock.now(),
      isBlocklisted: customer?.isBlocklisted ?? false,
      thresholds: RiskThresholds(
        returnRatePercent: settings.riskReturnRatePercent,
        minOrders: settings.riskMinOrders,
        refusalRecencyDays: settings.riskRefusalRecencyDays,
      ),
    );
    return CustomerRisk(
      badges: badges,
      facts: facts,
      riskNote: customer?.riskNote,
      blocklistReason: customer?.blocklistReason,
      isBlocklisted: customer?.isBlocklisted ?? false,
    );
  }
}

final customerRiskQueriesProvider = Provider<CustomerRiskQueries>((ref) =>
    CustomerRiskQueries(ref.watch(databaseProvider), ref.watch(clockProvider),
        ref.watch(settingsRepositoryProvider)));

final customerRiskProvider = FutureProvider.autoDispose.family<CustomerRisk, String>(
    (ref, id) => ref.watch(customerRiskQueriesProvider).assess(id));
