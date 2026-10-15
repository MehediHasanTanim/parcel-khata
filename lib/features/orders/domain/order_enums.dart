enum OrderStatus {
  draft('draft'),
  confirmed('confirmed'),
  packed('packed'),
  handedToCourier('handed_to_courier'),
  inTransit('in_transit'),
  delivered('delivered'),
  deliveryFailed('delivery_failed'),
  returnInTransit('return_in_transit'),
  returned('returned'),
  cancelled('cancelled');

  const OrderStatus(this.dbValue);
  final String dbValue;

  static OrderStatus fromDb(String v) => OrderStatus.values
      .firstWhere((s) => s.dbValue == v, orElse: () => OrderStatus.confirmed);

  /// Statuses where the courier is holding the parcel.
  bool get withCourier =>
      this == OrderStatus.handedToCourier || this == OrderStatus.inTransit;
}

enum PaymentType {
  cod('cod'),
  prepaid('prepaid'),
  partialAdvance('partial_advance');

  const PaymentType(this.dbValue);
  final String dbValue;

  static PaymentType fromDb(String v) => PaymentType.values
      .firstWhere((s) => s.dbValue == v, orElse: () => PaymentType.cod);
}

enum Channel {
  facebook('facebook'),
  whatsapp('whatsapp'),
  instagram('instagram'),
  phone('phone'),
  walkIn('walk_in'),
  other('other');

  const Channel(this.dbValue);
  final String dbValue;

  static Channel fromDb(String v) => Channel.values
      .firstWhere((s) => s.dbValue == v, orElse: () => Channel.other);
}

enum CodStatus {
  notApplicable('not_applicable'),
  pendingCollection('pending_collection'),
  collectedByCourier('collected_by_courier'),
  settled('settled'),
  partiallySettled('partially_settled'),
  notCollected('not_collected'),
  disputed('disputed');

  const CodStatus(this.dbValue);
  final String dbValue;

  static CodStatus fromDb(String v) => CodStatus.values
      .firstWhere((s) => s.dbValue == v, orElse: () => CodStatus.notApplicable);
}
