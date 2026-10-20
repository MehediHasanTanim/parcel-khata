import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_khata/app/app.dart';

import '../helpers/app_harness.dart';

/// Accessibility smoke checks: 200% font scale must not overflow the shell,
/// and primary targets meet the 48 dp minimum.
void main() {
  testWidgets('shell is usable at 200% text scale', (t) async {
    t.view.physicalSize = const Size(360, 740);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final c = await bootTestApp();
    await t.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2), size: Size(360, 740)),
        child: const ParcelKhataApp(),
      ),
    ));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull); // no overflow errors
    expect(find.byType(NavigationBar), findsOneWidget);
    for (final e in find.byType(NavigationDestination).evaluate()) {
      expect(t.getSize(find.byWidget(e.widget)).height, greaterThanOrEqualTo(48));
    }
    await shutDown(t, c);
  });

  testWidgets('navigation destinations expose text labels', (t) async {
    // Phone-sized surface: from 600dp wide the bottom bar becomes a rail.
    t.view
      ..physicalSize = const Size(400, 800)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final c = await bootTestApp();
    await t.pumpWidget(UncontrolledProviderScope(container: c, child: const ParcelKhataApp()));
    await t.pumpAndSettle();
    final labels = find.descendant(
      of: find.byType(NavigationBar),
      matching: find.byType(Text),
    );
    expect(labels.evaluate().length, greaterThanOrEqualTo(5));
    await shutDown(t, c);
  });
}
