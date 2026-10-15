import 'package:drift/drift.dart';

/// Columns shared by every business table (implementation plan §4.1).
mixin BaseColumns on Table {
  TextColumn get id => text()();
  TextColumn get shopId => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get rowVersion => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

class Shops extends Table with BaseColumns {
  TextColumn get name => text().withDefault(const Constant(''))();
  TextColumn get phone => text().nullable()();
  TextColumn get currency => text().withDefault(const Constant('BDT'))();
  TextColumn get timezone => text().withDefault(const Constant('Asia/Dhaka'))();
  TextColumn get settingsJson => text().withDefault(const Constant('{}'))();
}

class Customers extends Table with BaseColumns {
  TextColumn get name => text()();
  TextColumn get phonePrimary => text()();
  TextColumn get phoneNormalized => text()();
  TextColumn get phoneAlt => text().nullable()();
  TextColumn get whatsapp => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get tagsJson => text().withDefault(const Constant('[]'))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
}

@DataClassName('CustomerAddress')
class CustomerAddresses extends Table with BaseColumns {
  TextColumn get customerId => text().references(Customers, #id)();
  TextColumn get label => text().withDefault(const Constant(''))();
  TextColumn get fullText => text()();
  TextColumn get district => text().nullable()();
  TextColumn get area => text().nullable()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
}

class Products extends Table with BaseColumns {
  TextColumn get name => text()();
  TextColumn get sku => text().nullable()();
  IntColumn get defaultSellPrice => integer().withDefault(const Constant(0))();
  // Null means "cost missing" (profit becomes Incomplete later).
  IntColumn get defaultCostPrice => integer().nullable()();
  IntColumn get stockQty => integer().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get photoPath => text().nullable()();
}

class ProductVariants extends Table with BaseColumns {
  TextColumn get productId => text().references(Products, #id)();
  TextColumn get label => text()();
  TextColumn get sku => text().nullable()();
  IntColumn get sellPrice => integer().nullable()();
  IntColumn get costPrice => integer().nullable()();
  IntColumn get stockQty => integer().nullable()();
}

class Couriers extends Table with BaseColumns {
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get trackingUrlTemplate => text().nullable()();
  IntColumn get payoutCycleDays => integer().withDefault(const Constant(3))();
  IntColumn get stuckDays => integer().withDefault(const Constant(3))();
  TextColumn get cnRegex => text().nullable()();
  IntColumn get codFeePercentBp => integer().withDefault(const Constant(0))();
  IntColumn get codFeeFlat => integer().withDefault(const Constant(0))();
  IntColumn get codFeeFreeUnder => integer().nullable()();
  // none | flat | percent_of_delivery
  TextColumn get returnFeeMode => text().withDefault(const Constant('none'))();
  IntColumn get returnFeeValue => integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

@DataClassName('CourierRateRule')
class CourierRateRules extends Table with BaseColumns {
  TextColumn get courierId => text().references(Couriers, #id)();
  // inside_dhaka | dhaka_suburb | outside_dhaka | custom
  TextColumn get zone => text()();
  IntColumn get weightMinG => integer().withDefault(const Constant(0))();
  IntColumn get weightMaxG => integer().nullable()();
  IntColumn get fee => integer()();
}

class AuditLog extends Table {
  TextColumn get id => text()();
  TextColumn get shopId => text()();
  TextColumn get entity => text()();
  TextColumn get entityId => text()();
  TextColumn get action => text()();
  TextColumn get payloadJson => text().withDefault(const Constant('{}'))();
  DateTimeColumn get at => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Orders extends Table with BaseColumns {
  IntColumn get orderNumber => integer()();
  TextColumn get orderNo => text()();
  DateTimeColumn get orderDate => dateTime()();
  TextColumn get channel => text().withDefault(const Constant('facebook'))();
  TextColumn get sourceRef => text().nullable()();
  // Nullable only while the order is a draft.
  TextColumn get customerId => text().nullable().references(Customers, #id)();
  TextColumn get addressSnapshot => text().withDefault(const Constant(''))();
  TextColumn get status => text()();
  TextColumn get paymentType => text().withDefault(const Constant('cod'))();
  IntColumn get itemsTotal => integer().withDefault(const Constant(0))();
  IntColumn get discountTotal => integer().withDefault(const Constant(0))();
  IntColumn get deliveryChargeCustomer => integer().withDefault(const Constant(0))();
  IntColumn get advanceReceived => integer().withDefault(const Constant(0))();
  TextColumn get advanceMethod => text().nullable()();
  IntColumn get codExpected => integer().withDefault(const Constant(0))();
  BoolColumn get codOverridden => boolean().withDefault(const Constant(false))();
  TextColumn get codStatus => text().withDefault(const Constant('not_applicable'))();
  IntColumn get codCollected => integer().nullable()();
  TextColumn get courierId => text().nullable().references(Couriers, #id)();
  TextColumn get consignmentNo => text().nullable()();
  TextColumn get zone => text().nullable()();
  IntColumn get weightG => integer().nullable()();
  DateTimeColumn get handedOverAt => dateTime().nullable()();
  DateTimeColumn get deliveredAt => dateTime().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get tagsJson => text().withDefault(const Constant('[]'))();
  // Cached derived values (rebuildable; filled by later sprints).
  IntColumn get netReceivable => integer().nullable()();
  IntColumn get outstanding => integer().nullable()();
  IntColumn get profit => integer().nullable()();
  TextColumn get profitState => text().nullable()();
  // Cached revenue + delivery charge actually kept (profit calculator).
  IntColumn get grossCollected => integer().nullable()();
  // Explicit dispute flag (never inferred); set by payout shortfall handling.
  BoolColumn get isDisputed => boolean().withDefault(const Constant(false))();
  TextColumn get disputeNote => text().nullable()();
}

class OrderLines extends Table with BaseColumns {
  TextColumn get orderId => text().references(Orders, #id)();
  TextColumn get productId => text().nullable()();
  TextColumn get variantId => text().nullable()();
  // Snapshots: later catalog changes never alter old orders.
  TextColumn get nameSnapshot => text()();
  IntColumn get qty => integer().withDefault(const Constant(1))();
  IntColumn get unitSellPrice => integer()();
  IntColumn get unitCostPrice => integer().nullable()();
  IntColumn get lineDiscount => integer().withDefault(const Constant(0))();
}

class OrderCharges extends Table with BaseColumns {
  TextColumn get orderId => text().references(Orders, #id)();
  // delivery_fee | cod_fee | return_fee | packaging | other
  TextColumn get type => text()();
  IntColumn get expectedAmount => integer().withDefault(const Constant(0))();
  IntColumn get actualAmount => integer().nullable()();
  // rate_card | settings | manual | statement
  TextColumn get source => text().withDefault(const Constant('manual'))();
  TextColumn get note => text().nullable()();
}

@DataClassName('OrderStatusEvent')
class OrderStatusEvents extends Table with BaseColumns {
  TextColumn get orderId => text().references(Orders, #id)();
  TextColumn get fromStatus => text().nullable()();
  TextColumn get toStatus => text()();
  DateTimeColumn get at => dateTime()();
  TextColumn get reason => text().nullable()();
  TextColumn get note => text().nullable()();
}

@DataClassName('OrderEdit')
class OrderEditLog extends Table with BaseColumns {
  TextColumn get orderId => text().references(Orders, #id)();
  TextColumn get field => text()();
  TextColumn get oldValue => text().nullable()();
  TextColumn get newValue => text().nullable()();
  DateTimeColumn get at => dateTime()();
}

class OrderAttachments extends Table with BaseColumns {
  TextColumn get orderId => text().references(Orders, #id)();
  TextColumn get path => text()();
  TextColumn get kind => text().withDefault(const Constant('chat_screenshot'))();
}

class Payouts extends Table with BaseColumns {
  TextColumn get courierId => text().references(Couriers, #id)();
  DateTimeColumn get paidAt => dateTime()();
  // bank | bkash | nagad | cash | other
  TextColumn get method => text().withDefault(const Constant('bank'))();
  TextColumn get reference => text().nullable()();
  IntColumn get totalReceived => integer()();
  TextColumn get note => text().nullable()();
  // active | reversed
  TextColumn get status => text().withDefault(const Constant('active'))();
  TextColumn get reversedReason => text().nullable()();
  DateTimeColumn get reversedAt => dateTime().nullable()();
  // allocate | dispute | write_off (null when there was no shortfall)
  TextColumn get policy => text().nullable()();
}

class PayoutAllocations extends Table with BaseColumns {
  TextColumn get payoutId => text().references(Payouts, #id)();
  TextColumn get orderId => text().references(Orders, #id)();
  IntColumn get amountApplied => integer()();
  IntColumn get deductionsApplied => integer().withDefault(const Constant(0))();
  IntColumn get writeOffAmount => integer().withDefault(const Constant(0))();
  BoolColumn get disputedSet => boolean().withDefault(const Constant(false))();
  BoolColumn get isOverpayment => boolean().withDefault(const Constant(false))();
  TextColumn get note => text().nullable()();
}

class ReturnRecords extends Table with BaseColumns {
  TextColumn get orderId => text().references(Orders, #id)();
  // full | partial
  TextColumn get type => text()();
  TextColumn get reason => text()();
  DateTimeColumn get initiatedAt => dateTime()();
  DateTimeColumn get receivedBackAt => dateTime().nullable()();
  // resellable | damaged | lost | mixed (null until received back)
  TextColumn get condition => text().nullable()();
  IntColumn get lossAmount => integer().withDefault(const Constant(0))();
  TextColumn get notes => text().nullable()();
}

class ReturnLines extends Table with BaseColumns {
  TextColumn get returnId => text().references(ReturnRecords, #id)();
  TextColumn get orderLineId => text().references(OrderLines, #id)();
  IntColumn get qty => integer()();
  // resellable | damaged | lost (null until received back)
  TextColumn get condition => text().nullable()();
}

class SavedViews extends Table with BaseColumns {
  TextColumn get name => text()();
  TextColumn get filterJson => text().withDefault(const Constant('{}'))();
  TextColumn get sort => text().withDefault(const Constant('newest'))();
  BoolColumn get isPinned => boolean().withDefault(const Constant(true))();
}
