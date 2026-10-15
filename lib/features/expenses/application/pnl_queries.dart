import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parcel_khata/core/db/app_database.dart';
import 'package:parcel_khata/core/db/providers.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/core/providers.dart';
import 'package:parcel_khata/features/expenses/domain/business_pnl.dart';
import 'package:parcel_khata/features/profit/application/profit_input_builder.dart';
import 'package:parcel_khata/features/profit/domain/profit_calculator.dart';
import 'package:parcel_khata/features/reports/domain/report_math.dart';

/// Builds the monthly P&L from the same calculator that produces each order's
/// profit, so the totals can never drift from the order screens.
class PnlQueries {
  PnlQueries(this._db, this._shopId);

  final AppDatabase _db;
  final String _shopId;

  Future<BusinessPnl> compute(DatePeriod period) async {
    final orders = await (_db.select(_db.orders)
          ..where((o) =>
              o.shopId.equals(_shopId) &
              o.deletedAt.isNull() &
              o.status.equals('draft').not() &
              o.orderDate.isBiggerOrEqualValue(period.from) &
              o.orderDate.isSmallerThanValue(period.to)))
        .get();

    final rows = <OrderPnlRow>[];
    for (var i = 0; i < orders.length; i += 400) {
      final chunk = orders.sublist(i, i + 400 > orders.length ? orders.length : i + 400);
      final ids = chunk.map((o) => o.id).toList();
      final lines = await (_db.select(_db.orderLines)
            ..where((l) => l.orderId.isIn(ids) & l.deletedAt.isNull()))
          .get();
      final charges = await (_db.select(_db.orderCharges)
            ..where((c) => c.orderId.isIn(ids) & c.deletedAt.isNull()))
          .get();
      final records = await (_db.select(_db.returnRecords)
            ..where((r) => r.orderId.isIn(ids) & r.deletedAt.isNull()))
          .get();
      final recordByOrder = {for (final r in records) r.orderId: r};
      final rl = records.isEmpty
          ? <ReturnLine>[]
          : await (_db.select(_db.returnLines)
                ..where((l) =>
                    l.returnId.isIn(records.map((r) => r.id)) & l.deletedAt.isNull()))
              .get();
      for (final o in chunk) {
        final record = recordByOrder[o.id];
        final result = ProfitCalculator.compute(ProfitInputBuilder.build(
          order: o,
          lines: lines.where((l) => l.orderId == o.id).toList(),
          charges: charges.where((c) => c.orderId == o.id).toList(),
          returnLines:
              record == null ? const [] : rl.where((l) => l.returnId == record.id).toList(),
          hasReturnRecord: record != null,
        ));
        rows.add(OrderPnlRow(
          orderId: o.id,
          revenue: result.grossCollected,
          cogs: result.costOf(CostKind.cogs),
          courierFees: result.costOf(CostKind.deliveryFee) +
              result.costOf(CostKind.codFee) +
              result.costOf(CostKind.returnFee),
          goodsLoss: result.costOf(CostKind.goodsLoss),
          writeOff: result.costOf(CostKind.writeOff),
          packaging: result.costOf(CostKind.packaging),
          ads: result.costOf(CostKind.adAllocation),
          other: result.costOf(CostKind.other),
          net: result.net,
          counted: result.state != ProfitState.incomplete,
        ));
      }
    }

    final exp = await (_db.select(_db.expenses).join([
      leftOuterJoin(_db.campaigns, _db.campaigns.id.equalsExp(_db.expenses.campaignId)),
    ])
          ..where(_db.expenses.shopId.equals(_shopId) &
              _db.expenses.deletedAt.isNull() &
              _db.expenses.date.isBiggerOrEqualValue(period.from) &
              _db.expenses.date.isSmallerThanValue(period.to)))
        .get();
    final expenseRows = [
      for (final r in exp)
        ExpenseRow(
          amount: Money(r.readTable(_db.expenses).amount),
          category: ExpenseCategory.fromDb(r.readTable(_db.expenses).category),
          // Spend already spread onto orders is inside order profit.
          allocatedToOrders: r.readTableOrNull(_db.campaigns)?.allocatedAt != null,
        ),
    ];
    return BusinessPnlCalculator.compute(rows, expenseRows);
  }
}

final pnlQueriesProvider = Provider<PnlQueries>(
    (ref) => PnlQueries(ref.watch(databaseProvider), ref.watch(shopIdProvider)));
