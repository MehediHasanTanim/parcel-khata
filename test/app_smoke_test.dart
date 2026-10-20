import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_khata/app/app.dart';

import 'helpers/app_harness.dart';

void main() {
  testWidgets('shell shows 5 destinations and navigates', (t) async {
    final c = await bootTestApp();
    await t.pumpWidget(UncontrolledProviderScope(container: c, child: const ParcelKhataApp()));
    await t.pumpAndSettle();
    expect(find.byType(NavigationDestination), findsNWidgets(5));
    await t.tap(find.descendant(
      of: find.byType(NavigationBar),
      matching: find.byIcon(Icons.receipt_long_outlined),
    ));
    await t.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsOneWidget);
    await shutDown(t, c);
  });

  testWidgets('first run shows onboarding until finished', (t) async {
    final c = await bootTestApp(onboardingDone: false);
    await t.pumpWidget(UncontrolledProviderScope(container: c, child: const ParcelKhataApp()));
    await t.pumpAndSettle();
    expect(find.byType(NavigationDestination), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await shutDown(t, c);
  });
}
