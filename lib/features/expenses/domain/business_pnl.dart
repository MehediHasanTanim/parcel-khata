import 'package:meta/meta.dart';
import 'package:parcel_khata/core/money/money.dart';

enum ExpenseCategory {
  ads('ads'),
  packaging('packaging'),
  rent('rent'),
  salary('salary'),
  misc('misc');

  const ExpenseCategory(this.dbValue);
  final String dbValue;

  static ExpenseCategory fromDb(String v) => ExpenseCategory.values
      .firstWhere((c) => c.dbValue == v, orElse: () => ExpenseCategory.misc);
}

/// One order's contribution to the monthly P&L (all poisha, from the same
/// profit calculator that drives the order screen).
@immutable
class OrderPnlRow {
  const OrderPnlRow({
    required this.orderId,
    required this.revenue,
    required this.cogs,
    required this.courierFees,
    required this.goodsLoss,
    required this.writeOff,
    required this.packaging,
    required this.ads,
    required this.other,
    required this.net,
    required this.counted,
  });

  final String orderId;
  final Money revenue;
  final Money cogs;
  final Money courierFees;
  final Money goodsLoss;
  final Money writeOff;
  final Money packaging;
  final Money ads;
  final Money other;
  final Money net;

  /// False for Incomplete-profit orders: reported separately, not summed.
  final bool counted;
}

@immutable
class ExpenseRow {
  const ExpenseRow({
    required this.amount,
    required this.category,
    this.allocatedToOrders = false,
  });

  final Money amount;
  final ExpenseCategory category;

  /// Part of a campaign already spread onto orders (so already inside the
  /// orders' profit); counting it again would double count.
  final bool allocatedToOrders;
}

@immutable
class BusinessPnl {
  const BusinessPnl({
    required this.revenue,
    required this.cogs,
    required this.courierFees,
    required this.returnLoss,
    required this.packaging,
    required this.ads,
    required this.otherOrderCosts,
    required this.orderProfit,
    required this.unallocatedExpenses,
    required this.expensesByCategory,
    required this.businessProfit,
    required this.orderCount,
    required this.incompleteCount,
  });

  final Money revenue;
  final Money cogs;
  final Money courierFees;
  final Money returnLoss;
  final Money packaging;
  final Money ads;
  final Money otherOrderCosts;

  /// Sum of per-order net profit (what the order screens show).
  final Money orderProfit;

  /// Expenses not already inside order profit.
  final Money unallocatedExpenses;
  final Map<ExpenseCategory, Money> expensesByCategory;

  /// `orderProfit - unallocatedExpenses`.
  final Money businessProfit;
  final int orderCount;
  final int incompleteCount;

  /// Reconciles the columns: revenue - all order costs == orderProfit.
  Money get costsTotal => cogs + courierFees + returnLoss + packaging + ads + otherOrderCosts;
}

abstract final class BusinessPnlCalculator {
  static BusinessPnl compute(List<OrderPnlRow> orders, List<ExpenseRow> expenses) {
    var revenue = Money.zero;
    var cogs = Money.zero;
    var fees = Money.zero;
    var loss = Money.zero;
    var pack = Money.zero;
    var ads = Money.zero;
    var other = Money.zero;
    var net = Money.zero;
    var counted = 0;
    var incomplete = 0;
    for (final o in orders) {
      if (!o.counted) {
        incomplete++;
        continue;
      }
      counted++;
      revenue += o.revenue;
      cogs += o.cogs;
      fees += o.courierFees;
      loss += o.goodsLoss + o.writeOff;
      pack += o.packaging;
      ads += o.ads;
      other += o.other;
      net += o.net;
    }
    final byCat = <ExpenseCategory, Money>{};
    var unallocated = Money.zero;
    for (final e in expenses) {
      if (e.allocatedToOrders) continue;
      byCat[e.category] = (byCat[e.category] ?? Money.zero) + e.amount;
      unallocated += e.amount;
    }
    return BusinessPnl(
      revenue: revenue,
      cogs: cogs,
      courierFees: fees,
      returnLoss: loss,
      packaging: pack,
      ads: ads,
      otherOrderCosts: other,
      orderProfit: net,
      unallocatedExpenses: unallocated,
      expensesByCategory: byCat,
      businessProfit: net - unallocated,
      orderCount: counted,
      incompleteCount: incomplete,
    );
  }
}
