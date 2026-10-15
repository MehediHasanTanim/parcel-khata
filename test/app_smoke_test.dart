import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_khata/app/app.dart';

void main() {
  testWidgets('shell shows 5 destinations and navigates', (t) async {
    await t.pumpWidget(const ProviderScope(child: ParcelKhataApp()));
    await t.pumpAndSettle();
    expect(find.byType(NavigationDestination), findsNWidgets(5));
    await t.tap(find.byIcon(Icons.receipt_long_outlined));
    await t.pumpAndSettle();
    expect(find.byIcon(Icons.construction), findsOneWidget);
  });
}
