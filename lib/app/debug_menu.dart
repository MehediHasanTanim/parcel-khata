import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parcel_khata/dev/seeder.dart';
import 'package:parcel_khata/features/couriers/application/courier_repository.dart';
import 'package:parcel_khata/features/cod/application/payout_service.dart';
import 'package:parcel_khata/features/customers/application/customer_repository.dart';
import 'package:parcel_khata/features/returns/application/return_service.dart';
import 'package:parcel_khata/features/orders/application/order_repository.dart';
import 'package:parcel_khata/features/orders/application/order_status_service.dart';
import 'package:parcel_khata/features/products/application/product_repository.dart';
import 'package:parcel_khata/l10n/l10n.dart';

/// Non-production debug menu. Clock override and DB export are added as their
/// backing features land (S3-18, S7-12).
class DebugMenuScreen extends ConsumerWidget {
  const DebugMenuScreen({super.key});

  static bool get enabled => !kReleaseMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.debugMenu)),
      body: ListView(children: [
        ListTile(
          leading: const Icon(Icons.dataset),
          title: const Text('Seed 500 customers, 80 products, 4 couriers'),
          onTap: () async {
            final m = ScaffoldMessenger.of(context);
            await DevSeeder(
              ref.read(customerRepositoryProvider),
              ref.read(productRepositoryProvider),
              ref.read(courierRepositoryProvider),
            ).seed();
            m.showSnackBar(const SnackBar(content: Text('Seeded')));
          },
        ),
        ListTile(
          leading: const Icon(Icons.receipt_long),
          title: const Text('Seed 5,000 orders (90 days)'),
          onTap: () async {
            final m = ScaffoldMessenger.of(context);
            await DevSeeder(
              ref.read(customerRepositoryProvider),
              ref.read(productRepositoryProvider),
              ref.read(courierRepositoryProvider),
            ).seedOrders(ref.read(orderRepositoryProvider));
            m.showSnackBar(const SnackBar(content: Text('Seeded orders')));
          },
        ),
        ListTile(
          leading: const Icon(Icons.timeline),
          title: const Text('Apply realistic status mix to seeded orders'),
          onTap: () async {
            final m = ScaffoldMessenger.of(context);
            await DevSeeder(
              ref.read(customerRepositoryProvider),
              ref.read(productRepositoryProvider),
              ref.read(courierRepositoryProvider),
            ).seedStatusMix(
                ref.read(orderRepositoryProvider), ref.read(orderStatusServiceProvider));
            m.showSnackBar(const SnackBar(content: Text('Status mix applied')));
          },
        ),
        ListTile(
          leading: const Icon(Icons.account_balance_wallet),
          title: const Text('Seed payouts (shortfalls, disputes)'),
          onTap: () async {
            final m = ScaffoldMessenger.of(context);
            await DevSeeder(
              ref.read(customerRepositoryProvider),
              ref.read(productRepositoryProvider),
              ref.read(courierRepositoryProvider),
            ).seedPayouts(ref.read(payoutServiceProvider));
            m.showSnackBar(const SnackBar(content: Text('Payouts seeded')));
          },
        ),
        ListTile(
          leading: const Icon(Icons.build),
          title: const Text('Repair derived ledger fields'),
          onTap: () async {
            final m = ScaffoldMessenger.of(context);
            final n = await ref.read(ledgerWriterProvider).repairAll();
            m.showSnackBar(SnackBar(content: Text('Repaired $n orders')));
          },
        ),
        ListTile(
          leading: const Icon(Icons.assignment_return),
          title: const Text('Seed returns (full, partial, damaged)'),
          onTap: () async {
            final m = ScaffoldMessenger.of(context);
            await DevSeeder(
              ref.read(customerRepositoryProvider),
              ref.read(productRepositoryProvider),
              ref.read(courierRepositoryProvider),
            ).seedReturns(ref.read(orderRepositoryProvider), ref.read(returnServiceProvider));
            m.showSnackBar(const SnackBar(content: Text('Returns seeded')));
          },
        ),
        const ListTile(title: Text('Clock override'), subtitle: Text('Not implemented yet')),
        const ListTile(title: Text('Export DB'), subtitle: Text('Not implemented yet')),
      ]),
    );
  }
}
