import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:parcel_khata/features/orders/domain/order_enums.dart';
import 'package:parcel_khata/features/profit/domain/profit_calculator.dart';

enum ProfitSign { profit, loss }

enum OrderSort { newest, oldest, amountHigh, profitHigh, profitLow, daysSinceDispatch }

/// Combinable order filters (feature spec F10). Pure and serializable so it
/// can back saved views and dashboard drill-downs.
@immutable
class OrderFilter {
  const OrderFilter({
    this.statuses = const {},
    this.codStatuses = const {},
    this.profitStates = const {},
    this.courierId,
    this.channel,
    this.paymentType,
    this.customerId,
    this.tag,
    this.area,
    this.from,
    this.to,
    this.dispatchFrom,
    this.dispatchTo,
    this.deliveredFrom,
    this.deliveredTo,
    this.deliveredOlderThanDays,
    this.profitSign,
    this.amountMinPoisha,
    this.amountMaxPoisha,
    this.hasReturn,
    this.onlyDrafts = false,
    this.includeDrafts = false,
    this.query = '',
  });

  final Set<OrderStatus> statuses;
  final Set<CodStatus> codStatuses;
  final Set<ProfitState> profitStates;
  final String? courierId;
  final Channel? channel;
  final PaymentType? paymentType;
  final String? customerId;
  final String? tag;

  /// Matched against the address text (district / area words).
  final String? area;

  /// Order date range; [to] is exclusive.
  final DateTime? from;
  final DateTime? to;
  final DateTime? dispatchFrom;
  final DateTime? dispatchTo;
  final DateTime? deliveredFrom;
  final DateTime? deliveredTo;

  /// Relative: delivered at least this many days before "now".
  final int? deliveredOlderThanDays;
  final ProfitSign? profitSign;
  final int? amountMinPoisha;
  final int? amountMaxPoisha;
  final bool? hasReturn;

  /// Drafts are excluded from lists and aggregates unless asked for.
  final bool onlyDrafts;
  final bool includeDrafts;

  /// Free-text search (order no, customer, phone, CN, product, notes).
  final String query;

  static const empty = OrderFilter();

  OrderFilter copyWith({
    Set<OrderStatus>? statuses,
    Set<CodStatus>? codStatuses,
    Set<ProfitState>? profitStates,
    String? courierId,
    Channel? channel,
    PaymentType? paymentType,
    String? customerId,
    String? tag,
    String? area,
    DateTime? from,
    DateTime? to,
    DateTime? dispatchFrom,
    DateTime? dispatchTo,
    DateTime? deliveredFrom,
    DateTime? deliveredTo,
    int? deliveredOlderThanDays,
    ProfitSign? profitSign,
    int? amountMinPoisha,
    int? amountMaxPoisha,
    bool? hasReturn,
    String? query,
    bool clearDates = false,
    bool clearChannel = false,
    bool clearCourier = false,
    bool clearPaymentType = false,
    bool clearTag = false,
    bool clearArea = false,
    bool clearProfitSign = false,
    bool clearAmount = false,
    bool clearHasReturn = false,
    bool clearDispatch = false,
    bool clearDelivered = false,
  }) =>
      OrderFilter(
        statuses: statuses ?? this.statuses,
        codStatuses: codStatuses ?? this.codStatuses,
        profitStates: profitStates ?? this.profitStates,
        courierId: clearCourier ? null : (courierId ?? this.courierId),
        channel: clearChannel ? null : (channel ?? this.channel),
        paymentType: clearPaymentType ? null : (paymentType ?? this.paymentType),
        customerId: customerId ?? this.customerId,
        tag: clearTag ? null : (tag ?? this.tag),
        area: clearArea ? null : (area ?? this.area),
        from: clearDates ? null : (from ?? this.from),
        to: clearDates ? null : (to ?? this.to),
        dispatchFrom: clearDispatch ? null : (dispatchFrom ?? this.dispatchFrom),
        dispatchTo: clearDispatch ? null : (dispatchTo ?? this.dispatchTo),
        deliveredFrom: clearDelivered ? null : (deliveredFrom ?? this.deliveredFrom),
        deliveredTo: clearDelivered ? null : (deliveredTo ?? this.deliveredTo),
        deliveredOlderThanDays: clearDelivered
            ? null
            : (deliveredOlderThanDays ?? this.deliveredOlderThanDays),
        profitSign: clearProfitSign ? null : (profitSign ?? this.profitSign),
        amountMinPoisha: clearAmount ? null : (amountMinPoisha ?? this.amountMinPoisha),
        amountMaxPoisha: clearAmount ? null : (amountMaxPoisha ?? this.amountMaxPoisha),
        hasReturn: clearHasReturn ? null : (hasReturn ?? this.hasReturn),
        onlyDrafts: onlyDrafts,
        includeDrafts: includeDrafts,
        query: query ?? this.query,
      );

  /// Number of active constraints (for the filter button badge).
  int get activeCount => [
        statuses.isNotEmpty,
        codStatuses.isNotEmpty,
        profitStates.isNotEmpty,
        courierId != null,
        channel != null,
        paymentType != null,
        tag != null,
        area != null,
        from != null,
        dispatchFrom != null,
        deliveredFrom != null || deliveredOlderThanDays != null,
        profitSign != null,
        amountMinPoisha != null || amountMaxPoisha != null,
        hasReturn != null,
      ].where((b) => b).length;

  // ---------------------------------------------------------------- json

  Map<String, Object?> toJson() => {
        if (statuses.isNotEmpty) 'statuses': statuses.map((s) => s.dbValue).toList()..sort(),
        if (codStatuses.isNotEmpty)
          'codStatuses': codStatuses.map((s) => s.dbValue).toList()..sort(),
        if (profitStates.isNotEmpty)
          'profitStates': profitStates.map((s) => s.dbValue).toList()..sort(),
        if (courierId != null) 'courierId': courierId,
        if (channel != null) 'channel': channel!.dbValue,
        if (paymentType != null) 'paymentType': paymentType!.dbValue,
        if (customerId != null) 'customerId': customerId,
        if (tag != null) 'tag': tag,
        if (area != null) 'area': area,
        if (from != null) 'from': from!.toUtc().toIso8601String(),
        if (to != null) 'to': to!.toUtc().toIso8601String(),
        if (dispatchFrom != null) 'dispatchFrom': dispatchFrom!.toUtc().toIso8601String(),
        if (dispatchTo != null) 'dispatchTo': dispatchTo!.toUtc().toIso8601String(),
        if (deliveredFrom != null) 'deliveredFrom': deliveredFrom!.toUtc().toIso8601String(),
        if (deliveredTo != null) 'deliveredTo': deliveredTo!.toUtc().toIso8601String(),
        if (deliveredOlderThanDays != null) 'deliveredOlderThanDays': deliveredOlderThanDays,
        if (profitSign != null) 'profitSign': profitSign!.name,
        if (amountMinPoisha != null) 'amountMin': amountMinPoisha,
        if (amountMaxPoisha != null) 'amountMax': amountMaxPoisha,
        if (hasReturn != null) 'hasReturn': hasReturn,
        if (onlyDrafts) 'onlyDrafts': true,
        if (includeDrafts) 'includeDrafts': true,
        if (query.isNotEmpty) 'query': query,
      };

  String encode() => jsonEncode(toJson());

  factory OrderFilter.decode(String? raw) {
    if (raw == null || raw.isEmpty) return const OrderFilter();
    try {
      final j = jsonDecode(raw);
      if (j is! Map<String, dynamic>) return const OrderFilter();
      DateTime? d(String k) => j[k] == null ? null : DateTime.tryParse(j[k] as String);
      Set<T> set<T>(String k, T Function(String) parse) =>
          {for (final v in (j[k] as List<dynamic>? ?? const [])) parse(v as String)};
      return OrderFilter(
        statuses: set('statuses', OrderStatus.fromDb),
        codStatuses: set('codStatuses', CodStatus.fromDb),
        profitStates: set(
          'profitStates',
          (v) => ProfitState.values.firstWhere((s) => s.dbValue == v),
        ),
        courierId: j['courierId'] as String?,
        channel: j['channel'] == null ? null : Channel.fromDb(j['channel'] as String),
        paymentType:
            j['paymentType'] == null ? null : PaymentType.fromDb(j['paymentType'] as String),
        customerId: j['customerId'] as String?,
        tag: j['tag'] as String?,
        area: j['area'] as String?,
        from: d('from'),
        to: d('to'),
        dispatchFrom: d('dispatchFrom'),
        dispatchTo: d('dispatchTo'),
        deliveredFrom: d('deliveredFrom'),
        deliveredTo: d('deliveredTo'),
        deliveredOlderThanDays: j['deliveredOlderThanDays'] as int?,
        profitSign: j['profitSign'] == null
            ? null
            : ProfitSign.values.firstWhere((s) => s.name == j['profitSign']),
        amountMinPoisha: j['amountMin'] as int?,
        amountMaxPoisha: j['amountMax'] as int?,
        hasReturn: j['hasReturn'] as bool?,
        onlyDrafts: j['onlyDrafts'] as bool? ?? false,
        includeDrafts: j['includeDrafts'] as bool? ?? false,
        query: j['query'] as String? ?? '',
      );
    } on Object {
      return const OrderFilter();
    }
  }

  @override
  bool operator ==(Object other) => other is OrderFilter && other.encode() == encode();

  @override
  int get hashCode => encode().hashCode;
}

/// Plain facts about an order, used by the in-memory reference matcher that
/// the SQL filter is tested against.
@immutable
class OrderFacts {
  const OrderFacts({
    required this.status,
    required this.codStatus,
    required this.paymentType,
    required this.channel,
    required this.orderDate,
    required this.totalPoisha,
    this.courierId,
    this.customerId,
    this.handedOverAt,
    this.deliveredAt,
    this.profit,
    this.profitState,
    this.address = '',
    this.tags = const [],
    this.hasReturn = false,
  });

  final OrderStatus status;
  final CodStatus codStatus;
  final PaymentType paymentType;
  final Channel channel;
  final DateTime orderDate;

  /// items - discounts + delivery charge.
  final int totalPoisha;
  final String? courierId;
  final String? customerId;
  final DateTime? handedOverAt;
  final DateTime? deliveredAt;
  final int? profit;
  final ProfitState? profitState;
  final String address;
  final List<String> tags;
  final bool hasReturn;
}

abstract final class OrderFilterMatcher {
  /// Reference semantics of every filter field (search text excluded).
  static bool matches(OrderFilter f, OrderFacts o, {required DateTime now}) {
    final isDraft = o.status == OrderStatus.draft;
    if (f.onlyDrafts) {
      if (!isDraft) return false;
    } else if (!f.includeDrafts && isDraft) {
      return false;
    }
    if (f.statuses.isNotEmpty && !f.statuses.contains(o.status)) return false;
    if (f.codStatuses.isNotEmpty && !f.codStatuses.contains(o.codStatus)) return false;
    if (f.profitStates.isNotEmpty &&
        (o.profitState == null || !f.profitStates.contains(o.profitState))) {
      return false;
    }
    if (f.courierId != null && o.courierId != f.courierId) return false;
    if (f.channel != null && o.channel != f.channel) return false;
    if (f.paymentType != null && o.paymentType != f.paymentType) return false;
    if (f.customerId != null && o.customerId != f.customerId) return false;
    if (f.tag != null && !o.tags.contains(f.tag)) return false;
    if (f.area != null &&
        !o.address.toLowerCase().contains(f.area!.toLowerCase())) {
      return false;
    }
    if (f.from != null && o.orderDate.isBefore(f.from!)) return false;
    if (f.to != null && !o.orderDate.isBefore(f.to!)) return false;
    if (f.dispatchFrom != null &&
        (o.handedOverAt == null || o.handedOverAt!.isBefore(f.dispatchFrom!))) {
      return false;
    }
    if (f.dispatchTo != null &&
        (o.handedOverAt == null || !o.handedOverAt!.isBefore(f.dispatchTo!))) {
      return false;
    }
    if (f.deliveredFrom != null &&
        (o.deliveredAt == null || o.deliveredAt!.isBefore(f.deliveredFrom!))) {
      return false;
    }
    if (f.deliveredTo != null &&
        (o.deliveredAt == null || !o.deliveredAt!.isBefore(f.deliveredTo!))) {
      return false;
    }
    if (f.deliveredOlderThanDays != null) {
      final cutoff = now.subtract(Duration(days: f.deliveredOlderThanDays!));
      if (o.deliveredAt == null || o.deliveredAt!.isAfter(cutoff)) return false;
    }
    switch (f.profitSign) {
      case ProfitSign.profit:
        if (o.profit == null || o.profit! < 0) return false;
      case ProfitSign.loss:
        if (o.profit == null || o.profit! >= 0) return false;
      case null:
        break;
    }
    if (f.amountMinPoisha != null && o.totalPoisha < f.amountMinPoisha!) return false;
    if (f.amountMaxPoisha != null && o.totalPoisha > f.amountMaxPoisha!) return false;
    if (f.hasReturn != null && o.hasReturn != f.hasReturn) return false;
    return true;
  }
}

/// Filters shipped with the app (spec F10); users can add their own.
class DefaultViews {
  const DefaultViews._();

  static const toDispatch = 'default:to_dispatch';
  static const codPending5 = 'default:cod_pending_5d';
  static const returnsNotReceived = 'default:returns_not_received';
  static const lossMaking = 'default:loss_making';

  static final Map<String, OrderFilter> filters = {
    toDispatch: OrderFilter(statuses: {OrderStatus.confirmed, OrderStatus.packed}),
    codPending5: OrderFilter(
      statuses: {OrderStatus.delivered},
      codStatuses: {CodStatus.collectedByCourier, CodStatus.partiallySettled},
      deliveredOlderThanDays: 5,
    ),
    returnsNotReceived: OrderFilter(
      statuses: {OrderStatus.deliveryFailed, OrderStatus.returnInTransit},
    ),
    lossMaking: OrderFilter(
      profitSign: ProfitSign.loss,
      profitStates: {ProfitState.provisional, ProfitState.finalised},
    ),
  };
}
