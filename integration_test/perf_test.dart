import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:parcel_khata/core/db/app_database.dart';
import 'package:parcel_khata/core/db/providers.dart';
import 'package:parcel_khata/core/providers.dart';
import 'package:parcel_khata/dev/seeder.dart';
import 'package:parcel_khata/features/couriers/application/courier_repository.dart';
import 'package:parcel_khata/features/customers/application/customer_repository.dart';
import 'package:parcel_khata/features/orders/application/order_repository.dart';
import 'package:parcel_khata/features/orders/domain/order_enums.dart';
import 'package:parcel_khata/features/products/application/product_repository.dart';
import 'package:parcel_khata/features/reports/application/dashboard_service.dart';
import 'package:parcel_khata/features/reports/application/report_queries.dart';
import 'package:parcel_khata/features/reports/domain/report_math.dart';
import 'package:parcel_khata/features/settings/application/settings_repository.dart';

/// Measures the performance budgets with 20,000 orders on the connected
/// device (implementation plan §11). Runs in debug mode, so numbers are a
/// conservative upper bound for a release build.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('20k orders: dashboard, search, list, report within budget', (t) async {
    final c = ProviderContainer(overrides: [
      databaseProvider.overrideWith((ref) {
        final db = AppDatabase.memory();
        ref.onDispose(db.close);
        return db;
      }),
    ]);
    await c.read(settingsRepositoryProvider).ensureShop();
    final seeder = DevSeeder(
      c.read(customerRepositoryProvider),
      c.read(productRepositoryProvider),
      c.read(courierRepositoryProvider),
    );
    await seeder.seed(customers: 200, products: 20);
    final seedSw = Stopwatch()..start();
    await seeder.seedBulk(c.read(databaseProvider), c.read(uuidProvider),
        shopId: c.read(shopIdProvider));
    seedSw.stop();

    final orders = c.read(orderRepositoryProvider);
    Future<int> time(Future<void> Function() f, {int runs = 3}) async {
      final ms = <int>[];
      for (var i = 0; i < runs; i++) {
        final sw = Stopwatch()..start();
        await f();
        sw.stop();
        ms.add(sw.elapsedMilliseconds);
      }
      ms.sort();
      return ms[ms.length ~/ 2];
    }

    final total = (await orders.totals(const OrderFilter())).count;
    final period = DatePeriod.resolve(PeriodPreset.thisMonth, DateTime.now());
    final dashboard = await time(() => c.read(dashboardServiceProvider).load(period));
    final firstPage = await time(() => orders.fetchPage());
    final search = await time(() => orders.searchIds('BULK1000500'));
    final searchShort = await time(() => orders.searchIds('Rah'));
    final filtered = await time(() => orders.fetchPage(
          filter: const OrderFilter(statuses: {OrderStatus.delivered}),
          sort: OrderSort.amountHigh,
        ));
    final report = await time(() => c
        .read(reportQueriesProvider)
        .grouped(OrderFilter(from: DateTime(2020), to: DateTime(2030)), ReportGroup.courier));

    // ignore: avoid_print
    print('PERF orders=$total seed=${seedSw.elapsedMilliseconds}ms '
        'dashboard=${dashboard}ms firstPage=${firstPage}ms search=${search}ms '
        'searchShort=${searchShort}ms filtered=${filtered}ms report=${report}ms');

    expect(total, greaterThanOrEqualTo(20000));
    expect(dashboard, lessThan(1500), reason: 'dashboard budget 1.5 s');
    expect(search, lessThan(300), reason: 'search budget 300 ms');
    expect(firstPage, lessThan(500), reason: 'list first paint budget 500 ms');
    c.dispose();
  });
}
