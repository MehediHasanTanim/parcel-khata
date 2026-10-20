import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parcel_khata/dev/seeder.dart';
import 'package:parcel_khata/features/couriers/application/courier_repository.dart';
import 'package:parcel_khata/features/cod/application/payout_service.dart';
import 'package:parcel_khata/features/customers/application/customer_repository.dart';
import 'package:parcel_khata/core/db/providers.dart';
import 'package:parcel_khata/core/providers.dart';
import 'package:parcel_khata/features/reports/application/dashboard_service.dart';
import 'package:parcel_khata/features/returns/application/return_service.dart';
import 'package:parcel_khata/features/orders/application/order_repository.dart';
import 'package:parcel_khata/features/orders/application/order_status_service.dart';
import 'package:parcel_khata/features/products/application/product_repository.dart';
import 'package:parcel_khata/l10n/l10n.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

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
          leading: const Icon(LucideIcons300.sparkles),
          title: const Text('Seed demo data (60 orders, mixed statuses, payouts)'),
          onTap: () async {
            final m = ScaffoldMessenger.of(context);
            final seeder = DevSeeder(
              ref.read(customerRepositoryProvider),
              ref.read(productRepositoryProvider),
              ref.read(courierRepositoryProvider),
            );
            await seeder.seed();
            await seeder.seedOrders(ref.read(orderRepositoryProvider), count: 60, days: 30);
            await seeder.seedStatusMix(
                ref.read(orderRepositoryProvider), ref.read(orderStatusServiceProvider));
            await seeder.seedPayouts(ref.read(payoutServiceProvider));
            m.showSnackBar(const SnackBar(content: Text('Demo data seeded')));
          },
        ),
        ListTile(
          leading: const Icon(LucideIcons300.layoutGrid),
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
          leading: const Icon(LucideIcons300.receiptText),
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
          leading: const Icon(LucideIcons300.activity),
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
          leading: const Icon(LucideIcons300.wallet),
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
          leading: const Icon(LucideIcons300.wrench),
          title: const Text('Repair derived ledger fields'),
          onTap: () async {
            final m = ScaffoldMessenger.of(context);
            final n = await ref.read(ledgerWriterProvider).repairAll();
            m.showSnackBar(SnackBar(content: Text('Repaired $n orders')));
          },
        ),
        ListTile(
          leading: const Icon(LucideIcons300.undo2),
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
        ListTile(
          leading: const Icon(LucideIcons300.gauge),
          title: const Text('Seed 20,000 orders (fast bulk)'),
          onTap: () async {
            final m = ScaffoldMessenger.of(context);
            await DevSeeder(
              ref.read(customerRepositoryProvider),
              ref.read(productRepositoryProvider),
              ref.read(courierRepositoryProvider),
            ).seedBulk(
              ref.read(databaseProvider),
              ref.read(uuidProvider),
              shopId: ref.read(shopIdProvider),
            );
            m.showSnackBar(const SnackBar(content: Text('Bulk seeded')));
          },
        ),
        ListTile(
          leading: const Icon(LucideIcons300.timer),
          title: const Text('Measure dashboard load'),
          onTap: () async {
            final m = ScaffoldMessenger.of(context);
            final sw = Stopwatch()..start();
            await ref.read(dashboardServiceProvider).load(ref.read(currentPeriodProvider));
            sw.stop();
            m.showSnackBar(SnackBar(content: Text('Dashboard: ${sw.elapsedMilliseconds} ms')));
          },
        ),
        const ListTile(title: Text('Clock override'), subtitle: Text('Not implemented yet')),
        const ListTile(title: Text('Export DB'), subtitle: Text('Not implemented yet')),
      ]),
    );
  }
}
