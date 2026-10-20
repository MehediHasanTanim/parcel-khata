import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_khata/app/theme.dart';
import 'package:parcel_khata/features/couriers/presentation/courier_form_screen.dart';
import 'package:parcel_khata/features/couriers/presentation/couriers_screen.dart';
import 'package:parcel_khata/features/customers/presentation/customer_form_screen.dart';
import 'package:parcel_khata/features/customers/presentation/customers_screen.dart';
import 'package:parcel_khata/features/products/presentation/product_form_screen.dart';
import 'package:parcel_khata/features/products/presentation/products_screen.dart';
import 'package:parcel_khata/features/settings/presentation/settings_screen.dart';
import 'package:parcel_khata/l10n/l10n.dart';

import '../helpers/app_harness.dart';

/// Layout guard: the less common screens must not overflow at 320dp, at
/// 200% text, in dark mode or in high contrast. (Overflows throw in tests.)
void main() {
  final screens = <String, Widget Function()>{
    'customers': () => const CustomersScreen(),
    'customer form': () => const CustomerFormScreen(),
    'products': () => const ProductsScreen(),
    'product form': () => const ProductFormScreen(),
    'couriers': () => const CouriersScreen(),
    'courier form': () => const CourierFormScreen(),
    'settings': () => const SettingsScreen(),
  };
  final variants = <String, ({ThemeData theme, double scale})>{
    'light 100%': (theme: AppTheme.light(), scale: 1),
    'dark 200%': (theme: AppTheme.dark(), scale: 2),
    'high contrast 200%': (theme: AppTheme.light(highContrast: true), scale: 2),
  };
  for (final s in screens.entries) {
    for (final v in variants.entries) {
      for (final lang in const ['en', 'bn']) {
        testWidgets('${s.key} at 320dp, ${v.key}, $lang', (t) async {
          t.view
            ..physicalSize = const Size(320, 640)
            ..devicePixelRatio = 1;
          addTearDown(t.view.reset);
          final c = await bootTestApp();
          await t.pumpWidget(UncontrolledProviderScope(
            container: c,
            child: MaterialApp(
              theme: v.value.theme,
              locale: Locale(lang),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (ctx, child) => MediaQuery.withClampedTextScaling(
                minScaleFactor: v.value.scale,
                maxScaleFactor: v.value.scale,
                child: child!,
              ),
              home: s.value(),
            ),
          ));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
          await shutDown(t, c);
        });
      }
    }
  }
}
