import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';
import 'package:parcel_khata/app/app.dart';

import '../helpers/app_harness.dart';

void main() {
  Future<ProviderContainer> boot(WidgetTester t, Size size) async {
    t.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final c = await bootTestApp();
    await t.pumpWidget(UncontrolledProviderScope(container: c, child: const ParcelKhataApp()));
    await t.pumpAndSettle();
    return c;
  }

  testWidgets('phones keep the bottom bar and no rail', (t) async {
    final c = await boot(t, const Size(400, 800));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    await shutDown(t, c);
  });

  testWidgets('tablets get a navigation rail with New order on top', (t) async {
    final c = await boot(t, const Size(1024, 768));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(FloatingActionButton), findsWidgets);
    await shutDown(t, c);
  });

  testWidgets('tablet Orders shows a two-pane layout with a prompt on the right', (t) async {
    final c = await boot(t, const Size(1024, 768));
    await t.tap(find.descendant(
      of: find.byType(NavigationRail),
      matching: find.byIcon(LucideIcons300.receiptText),
    ));
    await t.pumpAndSettle();
    expect(find.byType(VerticalDivider), findsWidgets);
    expect(find.text('একটি অর্ডার বাছুন'), findsOneWidget);
    await shutDown(t, c);
  });

  testWidgets('narrow tablets below 800dp keep the single pane', (t) async {
    final c = await boot(t, const Size(700, 900));
    await t.tap(find.descendant(
      of: find.byType(NavigationRail),
      matching: find.byIcon(LucideIcons300.receiptText),
    ));
    await t.pumpAndSettle();
    expect(find.text('একটি অর্ডার বাছুন'), findsNothing);
    await shutDown(t, c);
  });
}
