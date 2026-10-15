import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_khata/features/customers/application/customer_repository.dart';
import 'package:parcel_khata/features/customers/application/customer_risk_queries.dart';
import 'package:parcel_khata/features/customers/presentation/risk_widgets.dart';
import 'package:parcel_khata/l10n/app_localizations.dart';

import '../helpers/app_harness.dart';

void main() {
  testWidgets('banner appears for a blocklisted customer, disappears when cleared',
      (t) async {
    final c = await bootTestApp();
    final repo = c.read(customerRepositoryProvider);
    final id = (await repo.create(
            const CustomerInput(name: 'Risky', phone: '01712345678')))
        .valueOrNull!
        .id;
    var tapped = 0;
    await t.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: RiskBanner(customerId: id, onTakeAdvance: () => tapped++),
        ),
      ),
    ));
    await t.pumpAndSettle();
    expect(find.text('Take advance'), findsNothing); // new customer: no warning

    await repo.setBlocklisted(id, blocked: true, reason: 'fake');
    c.invalidate(customerRiskProvider(id));
    await t.pumpAndSettle();
    expect(find.text('Take advance'), findsOneWidget);
    await t.tap(find.text('Take advance'));
    expect(tapped, 1);

    await repo.setBlocklisted(id, blocked: false);
    c.invalidate(customerRiskProvider(id));
    await t.pumpAndSettle();
    expect(find.text('Take advance'), findsNothing);
    await shutDown(t, c);
  });
}
