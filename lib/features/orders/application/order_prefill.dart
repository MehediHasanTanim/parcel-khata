import 'package:parcel_khata/core/money/money.dart';

/// A starting point for the normal order form (from pasted chat text).
/// It carries values only: nothing is saved until the seller confirms in the
/// regular form, so every validation still applies.
class PrefillLine {
  const PrefillLine({
    required this.name,
    this.qty = 1,
    this.sell,
    this.cost,
    this.productId,
  });

  final String name;
  final int qty;
  final Money? sell;
  final Money? cost;
  final String? productId;
}

class OrderPrefill {
  const OrderPrefill({
    this.customerId,
    this.address = '',
    this.lines = const [],
    this.deliveryCharge,
    this.advance,
    this.notes,
    this.sourceRef,
  });

  final String? customerId;
  final String address;
  final List<PrefillLine> lines;
  final Money? deliveryCharge;
  final Money? advance;
  final String? notes;
  final String? sourceRef;
}

/// Values for a new customer opened from the paste screen.
class CustomerPrefill {
  const CustomerPrefill({this.name = '', this.phone = '', this.address = ''});
  final String name;
  final String phone;
  final String address;
}
