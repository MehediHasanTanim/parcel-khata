import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_khata/features/orders/domain/order_enums.dart';
import 'package:parcel_khata/features/orders/domain/order_filter.dart';
import 'package:parcel_khata/features/profit/domain/profit_calculator.dart';

void main() {
  final now = DateTime.utc(2026, 10, 15, 12);

  OrderFacts facts({
    OrderStatus status = OrderStatus.confirmed,
    CodStatus cod = CodStatus.pendingCollection,
    PaymentType pay = PaymentType.cod,
    Channel channel = Channel.facebook,
    DateTime? date,
    int total = 100000,
    String? courier,
    String? customer,
    DateTime? handed,
    DateTime? delivered,
    int? profit,
    ProfitState? state,
    String address = 'House 1, Dhanmondi, Dhaka',
    List<String> tags = const [],
    bool ret = false,
  }) =>
      OrderFacts(
        status: status,
        codStatus: cod,
        paymentType: pay,
        channel: channel,
        orderDate: date ?? now,
        totalPoisha: total,
        courierId: courier,
        customerId: customer,
        handedOverAt: handed,
        deliveredAt: delivered,
        profit: profit,
        profitState: state,
        address: address,
        tags: tags,
        hasReturn: ret,
      );

  bool m(OrderFilter f, OrderFacts o) => OrderFilterMatcher.matches(f, o, now: now);

  group('json', () {
    test('round trip keeps every field', () {
      final f = OrderFilter(
        statuses: {OrderStatus.delivered, OrderStatus.packed},
        codStatuses: {CodStatus.settled},
        profitStates: {ProfitState.finalised},
        courierId: 'c1',
        channel: Channel.whatsapp,
        paymentType: PaymentType.prepaid,
        customerId: 'u1',
        tag: 'eid',
        area: 'Mirpur',
        from: DateTime.utc(2026, 10),
        to: DateTime.utc(2026, 11),
        dispatchFrom: DateTime.utc(2026, 10, 2),
        deliveredOlderThanDays: 5,
        profitSign: ProfitSign.loss,
        amountMinPoisha: 100,
        amountMaxPoisha: 900,
        hasReturn: true,
        query: 'rahim',
      );
      expect(OrderFilter.decode(f.encode()), f);
    });

    test('garbage decodes to empty', () {
      expect(OrderFilter.decode('nope'), OrderFilter.empty);
      expect(OrderFilter.decode(null), OrderFilter.empty);
      expect(OrderFilter.decode('[1]'), OrderFilter.empty);
    });

    test('activeCount counts constraints, not drafts/query', () {
      expect(OrderFilter.empty.activeCount, 0);
      expect(
          OrderFilter(statuses: {OrderStatus.packed}, channel: Channel.phone, tag: 'x')
              .activeCount,
          3);
    });
  });

  group('matcher', () {
    test('drafts excluded unless asked', () {
      final d = facts(status: OrderStatus.draft);
      expect(m(OrderFilter.empty, d), isFalse);
      expect(m(const OrderFilter(includeDrafts: true), d), isTrue);
      expect(m(const OrderFilter(onlyDrafts: true), d), isTrue);
      expect(m(const OrderFilter(onlyDrafts: true), facts()), isFalse);
    });

    test('status / cod / channel / payment / courier / customer', () {
      final o = facts(
        status: OrderStatus.delivered,
        cod: CodStatus.collectedByCourier,
        channel: Channel.whatsapp,
        pay: PaymentType.partialAdvance,
        courier: 'c1',
        customer: 'u1',
      );
      expect(m(OrderFilter(statuses: {OrderStatus.delivered}), o), isTrue);
      expect(m(OrderFilter(statuses: {OrderStatus.packed}), o), isFalse);
      expect(m(OrderFilter(codStatuses: {CodStatus.collectedByCourier}), o), isTrue);
      expect(m(const OrderFilter(channel: Channel.whatsapp), o), isTrue);
      expect(m(const OrderFilter(channel: Channel.phone), o), isFalse);
      expect(m(const OrderFilter(paymentType: PaymentType.partialAdvance), o), isTrue);
      expect(m(const OrderFilter(courierId: 'c1'), o), isTrue);
      expect(m(const OrderFilter(courierId: 'c2'), o), isFalse);
      expect(m(const OrderFilter(customerId: 'u1'), o), isTrue);
    });

    test('date ranges: order date, dispatch, delivered', () {
      final o = facts(
        date: DateTime.utc(2026, 10, 10),
        handed: DateTime.utc(2026, 10, 11),
        delivered: DateTime.utc(2026, 10, 12),
      );
      expect(m(OrderFilter(from: DateTime.utc(2026, 10, 10)), o), isTrue);
      expect(m(OrderFilter(to: DateTime.utc(2026, 10, 10)), o), isFalse); // exclusive
      expect(m(OrderFilter(dispatchFrom: DateTime.utc(2026, 10, 12)), o), isFalse);
      expect(m(OrderFilter(deliveredTo: DateTime.utc(2026, 10, 13)), o), isTrue);
      expect(m(OrderFilter(dispatchFrom: DateTime.utc(2026, 10)), facts()), isFalse);
    });

    test('delivered older than N days is relative to now', () {
      final old = facts(delivered: now.subtract(const Duration(days: 6)));
      final fresh = facts(delivered: now.subtract(const Duration(days: 2)));
      const f = OrderFilter(deliveredOlderThanDays: 5);
      expect(m(f, old), isTrue);
      expect(m(f, fresh), isFalse);
      expect(m(f, facts()), isFalse);
    });

    test('profit sign and states', () {
      expect(m(const OrderFilter(profitSign: ProfitSign.loss), facts(profit: -1)), isTrue);
      expect(m(const OrderFilter(profitSign: ProfitSign.loss), facts(profit: 0)), isFalse);
      expect(m(const OrderFilter(profitSign: ProfitSign.profit), facts(profit: 0)), isTrue);
      expect(m(const OrderFilter(profitSign: ProfitSign.profit), facts()), isFalse);
      expect(
          m(OrderFilter(profitStates: {ProfitState.finalised}),
              facts(state: ProfitState.provisional)),
          isFalse);
    });

    test('amount range inclusive, tag, area, hasReturn', () {
      expect(m(const OrderFilter(amountMinPoisha: 100000, amountMaxPoisha: 100000), facts()),
          isTrue);
      expect(m(const OrderFilter(amountMinPoisha: 100001), facts()), isFalse);
      expect(m(const OrderFilter(tag: 'eid'), facts(tags: ['eid', 'live'])), isTrue);
      expect(m(const OrderFilter(tag: 'eid'), facts()), isFalse);
      expect(m(const OrderFilter(area: 'dhanmondi'), facts()), isTrue);
      expect(m(const OrderFilter(area: 'mirpur'), facts()), isFalse);
      expect(m(const OrderFilter(hasReturn: true), facts(ret: true)), isTrue);
      expect(m(const OrderFilter(hasReturn: false), facts(ret: true)), isFalse);
    });

    test('default views behave as described', () {
      final toDispatch = DefaultViews.filters[DefaultViews.toDispatch]!;
      expect(m(toDispatch, facts(status: OrderStatus.packed)), isTrue);
      expect(m(toDispatch, facts(status: OrderStatus.delivered)), isFalse);

      final cod5 = DefaultViews.filters[DefaultViews.codPending5]!;
      expect(
          m(
              cod5,
              facts(
                status: OrderStatus.delivered,
                cod: CodStatus.collectedByCourier,
                delivered: now.subtract(const Duration(days: 6)),
              )),
          isTrue);
      expect(
          m(
              cod5,
              facts(
                status: OrderStatus.delivered,
                cod: CodStatus.collectedByCourier,
                delivered: now.subtract(const Duration(days: 3)),
              )),
          isFalse);

      final loss = DefaultViews.filters[DefaultViews.lossMaking]!;
      expect(m(loss, facts(profit: -500, state: ProfitState.finalised)), isTrue);
      expect(m(loss, facts(profit: -500, state: ProfitState.incomplete)), isFalse);
    });

    test('combined filters are an AND', () {
      final f = OrderFilter(
        statuses: {OrderStatus.delivered},
        channel: Channel.facebook,
        courierId: 'c1',
      );
      expect(m(f, facts(status: OrderStatus.delivered, courier: 'c1')), isTrue);
      expect(m(f, facts(status: OrderStatus.delivered, courier: 'c2')), isFalse);
    });
  });
}
