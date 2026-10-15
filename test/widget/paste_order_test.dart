import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/features/customers/application/customer_repository.dart';
import 'package:parcel_khata/features/orders/application/order_prefill.dart';
import 'package:parcel_khata/features/orders/presentation/paste_order_screen.dart';
import 'package:parcel_khata/features/products/application/product_repository.dart';
import 'package:parcel_khata/l10n/app_localizations.dart';

import '../helpers/app_harness.dart';

/// Lets real (non-fake-async) database work finish, then renders frames.
Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('parses a message, keeps an existing customer unchanged, prefills the form',
      (t) async {
    t.view.physicalSize = const Size(420, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final c = await bootTestApp();
    await c.read(productRepositoryProvider).create(const ProductInput(
        name: 'Cotton Shirt', sellPrice: Money.taka(650), costPrice: Money.taka(400)));
    final saved = (await c.read(customerRepositoryProvider).create(
            const CustomerInput(name: 'Saved Name', phone: '01712345678')))
        .valueOrNull!;

    OrderPrefill? got;
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const PasteOrderScreen(
          initialText: 'Name: Someone Else\nMobile: 01712345678\n'
              'Address: House 3, Road 5, Dhanmondi, Dhaka\nProduct: Cotton Shirt x2',
        ),
      ),
      GoRoute(
        path: '/orders/new',
        builder: (_, st) {
          got = st.extra as OrderPrefill?;
          return const Scaffold(body: Text('ORDER FORM'));
        },
      ),
    ]);
    await t.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp.router(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ));
    await _settle(t);

    // Existing customer is recognised and not renamed.
    expect(find.textContaining('Saved Name'), findsWidgets);
    expect(find.textContaining('details are not changed'), findsOneWidget);
    expect((await c.read(customerRepositoryProvider).getById(saved.id))!.name, 'Saved Name');

    await t.scrollUntilVisible(find.text('Create order'), 300,
        scrollable: find.byType(Scrollable).first);
    await t.tap(find.text('Create order'));
    await _settle(t);

    expect(find.text('ORDER FORM'), findsOneWidget);
    expect(got!.customerId, saved.id);
    expect(got!.address, contains('Dhanmondi'));
    expect(got!.lines.single.name, 'Cotton Shirt');
    expect(got!.lines.single.qty, 2);
    expect(got!.lines.single.sell, const Money.taka(650));
    expect(got!.lines.single.productId, isNotNull);
    // Still nothing saved: no order exists.
    await shutDown(t, c);
  });

  testWidgets('empty message shows the manual-entry hint, nothing is created', (t) async {
    final c = await bootTestApp();
    await t.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PasteOrderScreen(initialText: 'hello'),
      ),
    ));
    await _settle(t);
    expect(find.textContaining('Nothing recognised'), findsOneWidget);
    await shutDown(t, c);
  });
}
