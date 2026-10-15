import 'package:meta/meta.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/features/orders/domain/cod_amount_calculator.dart';
import 'package:parcel_khata/features/orders/domain/order_enums.dart';

/// Everything the order form collects, independent of storage.
@immutable
class OrderInput {
  const OrderInput({
    required this.lines,
    this.customerId,
    this.address = '',
    this.orderDate,
    this.channel = Channel.facebook,
    this.sourceRef,
    this.paymentType = PaymentType.cod,
    this.advance = Money.zero,
    this.advanceMethod,
    this.deliveryCharge = Money.zero,
    this.orderDiscount = const Discount.none(),
    this.codOverride,
    this.courierId,
    this.consignmentNo,
    this.zone,
    this.weightG,
    this.notes,
    this.tags = const [],
    this.exchangeOfOrderId,
  });

  final String? customerId;
  final String address;
  final DateTime? orderDate;
  final Channel channel;
  final String? sourceRef;
  final List<LineInput> lines;
  final PaymentType paymentType;
  final Money advance;
  final String? advanceMethod;
  final Money deliveryCharge;
  final Discount orderDiscount;

  /// Manual COD override; null = use the calculated amount.
  final Money? codOverride;
  final String? courierId;
  final String? consignmentNo;
  final String? zone;
  final int? weightG;
  final String? notes;
  final List<String> tags;

  /// Set when this order replaces goods of an earlier order (exchange).
  final String? exchangeOfOrderId;

  CodBreakdown get breakdown => CodAmountCalculator.compute(
        lines: lines,
        paymentType: paymentType,
        orderDiscount: orderDiscount,
        deliveryCharge: deliveryCharge,
        advance: advance,
        override: codOverride,
      );

  /// A draft may be saved with nothing; a real order needs these.
  String? validateForConfirm() {
    if (customerId == null) return 'customer_required';
    if (lines.isEmpty) return 'items_required';
    if (address.trim().isEmpty) return 'address_required';
    return null;
  }

  bool get hasAnyData =>
      customerId != null ||
      lines.isNotEmpty ||
      address.trim().isNotEmpty ||
      (notes?.trim().isNotEmpty ?? false);
}
