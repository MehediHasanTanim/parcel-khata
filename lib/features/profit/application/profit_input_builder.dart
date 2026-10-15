import 'package:parcel_khata/core/db/app_database.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/features/cod/domain/ledger.dart';
import 'package:parcel_khata/features/orders/domain/order_enums.dart';
import 'package:parcel_khata/features/profit/domain/profit_calculator.dart';

/// Maps stored rows to the pure [ProfitInput]. Shared by the cached-profit
/// pipeline and the breakdown panel so both always agree.
abstract final class ProfitInputBuilder {
  static ProfitInput build({
    required Order order,
    required List<OrderLine> lines,
    required List<OrderCharge> charges,
    required List<ReturnLine> returnLines,
    required bool hasReturnRecord,
  }) {
    final status = OrderStatus.fromDb(order.status);
    // A failed/returned order without a record is treated as fully returned.
    final assumeFullReturn = !hasReturnRecord &&
        (status == OrderStatus.deliveryFailed ||
            status == OrderStatus.returnInTransit ||
            status == OrderStatus.returned);

    final returnedByLine = <String, int>{};
    final conditionByLine = <String, ReturnCondition?>{};
    for (final r in returnLines.where((r) => r.deletedAt == null)) {
      returnedByLine[r.orderLineId] = (returnedByLine[r.orderLineId] ?? 0) + r.qty;
      conditionByLine[r.orderLineId] = ReturnCondition.fromDb(r.condition);
    }
    return ProfitInput(
      status: status,
      paymentType: PaymentType.fromDb(order.paymentType),
      codStatus: CodStatus.fromDb(order.codStatus),
      orderDiscount: Money(order.discountTotal),
      deliveryCharge: Money(order.deliveryChargeCustomer),
      lines: [
        for (final l in lines.where((l) => l.deletedAt == null))
          ProfitLine(
            name: l.nameSnapshot,
            qty: l.qty,
            unitSell: Money(l.unitSellPrice),
            unitCost: l.unitCostPrice == null ? null : Money(l.unitCostPrice!),
            lineDiscount: Money(l.lineDiscount),
            returnedQty: assumeFullReturn ? l.qty : (returnedByLine[l.id] ?? 0),
            returnCondition: conditionByLine[l.id],
          ),
      ],
      charges: [
        for (final c in charges.where((c) => c.deletedAt == null))
          ChargeAmount(
            type: c.type,
            expected: Money(c.expectedAmount),
            actual: c.actualAmount == null ? null : Money(c.actualAmount!),
          ),
      ],
    );
  }
}
