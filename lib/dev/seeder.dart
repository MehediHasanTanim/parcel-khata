import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/features/cod/application/payout_service.dart';
import 'package:parcel_khata/features/cod/domain/payout_reconciler.dart';
import 'package:parcel_khata/features/couriers/application/courier_repository.dart';
import 'package:parcel_khata/features/couriers/domain/charge_calculator.dart';
import 'package:parcel_khata/features/customers/application/customer_repository.dart';
import 'package:parcel_khata/features/orders/application/order_repository.dart';
import 'package:parcel_khata/features/orders/application/order_status_service.dart';
import 'package:parcel_khata/features/orders/domain/cod_amount_calculator.dart';
import 'package:parcel_khata/features/orders/domain/order_enums.dart';
import 'package:parcel_khata/features/orders/domain/order_input.dart';
import 'package:parcel_khata/features/products/application/product_repository.dart';

/// Dev-only seed data (S1-20): 500 customers, 80 products, 4 couriers.
class DevSeeder {
  DevSeeder(this._customers, this._products, this._couriers);

  final CustomerRepository _customers;
  final ProductRepository _products;
  final CourierRepository _couriers;

  static const _first = ['Rahim', 'Karim', 'Nusrat', 'Sadia', 'Tanvir', 'Mitu', 'Arif', 'Rina', 'Jahid', 'Lucky'];
  static const _last = ['Hasan', 'Akter', 'Islam', 'Chowdhury', 'Rahman', 'Khan', 'Begum', 'Ahmed'];
  static const _districts = ['Dhaka', 'Chattogram', 'Sylhet', 'Rajshahi', 'Khulna', 'Cumilla'];

  /// Seeds orders spread over [days] days for perf tests (S2-23). Requires
  /// customers/products (call [seed] first). Deterministic.
  Future<void> seedOrders(
    OrderRepository orders, {
    int count = 5000,
    int days = 90,
    DateTime? now,
  }) async {
    final customers = await _customers.search('');
    final products = await _products.watchAll(includeInactive: false).first;
    final couriers = await _couriers.watchAll().first;
    if (customers.isEmpty || products.isEmpty) return;
    final base = now ?? DateTime.now();
    for (var i = 0; i < count; i++) {
      final c = customers[i % customers.length];
      final lineCount = 1 + i % 3;
      final lines = <LineInput>[
        for (var j = 0; j < lineCount; j++)
          () {
            final p = products[(i * 7 + j * 13) % products.length];
            return LineInput(
              name: p.name,
              qty: 1 + (i + j) % 3,
              unitSell: Money(p.defaultSellPrice),
              unitCost: p.defaultCostPrice == null ? null : Money(p.defaultCostPrice!),
              productId: p.id,
            );
          }(),
      ];
      final courier = couriers.isEmpty ? null : couriers[i % couriers.length];
      await orders.create(OrderInput(
        customerId: c.id,
        address: 'Seed address ${i % 90}',
        orderDate: base.subtract(Duration(days: i % days, minutes: i % 1440)),
        channel: Channel.values[i % Channel.values.length],
        lines: lines,
        paymentType: i % 10 == 0 ? PaymentType.prepaid : PaymentType.cod,
        deliveryCharge: Money.taka(i % 2 == 0 ? 60 : 120),
        courierId: courier?.id,
        zone: 'inside_dhaka',
      ));
    }
  }

  /// Seeds a realistic status mix with timestamps spread over the window
  /// (S3-18): ~60% delivered, ~15% in transit, ~10% failed/returned, rest
  /// confirmed or cancelled. Orders need a courier and CN to be handed over.
  Future<void> seedStatusMix(
    OrderRepository orders,
    OrderStatusService status, {
    int limit = 2000,
  }) async {
    final rows = await orders.fetchPage(limit: limit);
    var n = 0;
    for (final item in rows.reversed) {
      final o = item.order;
      n++;
      final bucket = n % 20;
      if (bucket >= 16) continue; // leave ~20% confirmed
      if (o.courierId == null) continue;
      final handed = o.orderDate.add(Duration(hours: 4 + n % 20));
      await orders.assignCourier(o.id,
          courierId: o.courierId!, consignmentNo: 'SEED${o.orderNumber}', zone: 'inside_dhaka');
      final r = await status.changeStatus(o.id,
          to: OrderStatus.handedToCourier, at: handed);
      if (!r.isOk) continue;
      if (bucket < 12) {
        await status.changeStatus(o.id,
            to: OrderStatus.delivered, at: handed.add(Duration(days: 1 + n % 3)));
      } else if (bucket < 14) {
        // still with the courier: some will show as stuck
      } else if (bucket < 15) {
        await status.changeStatus(o.id,
            to: OrderStatus.deliveryFailed,
            at: handed.add(const Duration(days: 2)),
            reason: 'customer_refused');
      }
    }
  }

  /// Realistic payouts for delivered orders (S4-22): per courier, settle the
  /// oldest delivered COD orders in lump sums; some with a shortfall that is
  /// disputed or written off.
  Future<void> seedPayouts(PayoutService payouts) async {
    final couriers = await _couriers.watchAll().first;
    var k = 0;
    for (final c in couriers) {
      var rows = await payouts.payableOrders(c.id);
      while (rows.length >= 5) {
        final batch = rows.take(5 + k % 6).toList();
        final expected = PayoutReconciler.expectedTotal([for (final r in batch) r.reconcile]);
        k++;
        final shortfall = k % 4 == 0 ? const Money.taka(40) : Money.zero;
        final received = expected - shortfall;
        final lines = PayoutReconciler.autoAllocate(
            [for (final r in batch) r.reconcile], received);
        final r = await payouts.recordPayout(RecordPayoutInput(
          courierId: c.id,
          totalReceived: received,
          selectedOrderIds: [for (final r in batch) r.order.id],
          allocations: lines,
          policy: shortfall.isZero
              ? null
              : (k % 8 == 0 ? ShortfallPolicy.writeOff : ShortfallPolicy.dispute),
          reference: 'SEED-$k',
        ));
        if (!r.isOk) break;
        rows = await payouts.payableOrders(c.id);
        // Leave the newest ~15 orders pending so the hub has data.
        if (rows.length < 15) break;
      }
    }
  }

  Future<void> seed({int customers = 500, int products = 80}) async {
    final existing = await _customers.search('');
    if (existing.length >= customers) return;

    for (final c in kCourierPresets.take(4)) {
      await _couriers.create(CourierInput(
        name: c.name,
        trackingUrlTemplate: c.tracking,
        codFeePercentBp: 100,
        returnFeeMode: ReturnFeeMode.percentOfDelivery,
        returnFeeValue: 10000,
        rateRules: const [
          RateRuleInput(zone: 'inside_dhaka', fee: Money.taka(60)),
          RateRuleInput(zone: 'dhaka_suburb', fee: Money.taka(90)),
          RateRuleInput(zone: 'outside_dhaka', fee: Money.taka(120)),
        ],
      ));
    }
    for (var i = 0; i < products; i++) {
      final sell = 300 + (i * 37) % 2200;
      await _products.create(ProductInput(
        name: 'Product ${i + 1}',
        sku: 'SKU${(i + 1).toString().padLeft(3, '0')}',
        sellPrice: Money.taka(sell),
        // Every 10th product lacks a cost to exercise the "cost missing" path.
        costPrice: i % 10 == 9 ? null : Money.taka((sell * 0.6).round()),
        variants: i % 4 == 0
            ? const [VariantInput(label: 'M'), VariantInput(label: 'L')]
            : const [],
      ));
    }
    for (var i = 0; i < customers; i++) {
      // Unique valid BD mobile per index: 01[3-9] + 8 digits.
      final tail = (10000000 + i).toString();
      final phone = '01${3 + i % 7}$tail';
      await _customers.create(CustomerInput(
        name: '${_first[i % _first.length]} ${_last[(i ~/ 10) % _last.length]}',
        phone: phone,
        addresses: [
          AddressInput(
            fullText: 'House ${i % 90 + 1}, Road ${i % 12 + 1}',
            district: _districts[i % _districts.length],
            isDefault: true,
          ),
        ],
      ));
    }
  }
}
