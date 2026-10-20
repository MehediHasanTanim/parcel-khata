import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_khata/app/app.dart';

import 'helpers/app_harness.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

void main() {
  testWidgets('shell shows 5 destinations and navigates', (t) async {
    // Phone-sized surface: from 600dp wide the bottom bar becomes a rail.
    t.view
      ..physicalSize = const Size(400, 800)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final c = await bootTestApp();
    await t.pumpWidget(UncontrolledProviderScope(container: c, child: const ParcelKhataApp()));
    await t.pumpAndSettle();
    expect(find.byType(NavigationDestination), findsNWidgets(5));
    await t.tap(find.descendant(
      of: find.byType(NavigationBar),
      matching: find.byIcon(LucideIcons300.receiptText),
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
