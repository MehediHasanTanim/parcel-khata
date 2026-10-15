import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_khata/l10n/app_localizations.dart';
import 'package:parcel_khata/shared/cn_scanner.dart';

class _Host extends ConsumerWidget {
  const _Host({required this.onResult, this.pattern});

  final void Function(String?) onResult;
  final String? pattern;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async =>
                onResult(await scanCn(context, ref, courierPattern: pattern)),
            child: const Text('scan'),
          ),
        ),
      );
}

Widget _app(ScannerViewBuilder builder, _Host host) => ProviderScope(
      overrides: [scannerViewBuilderProvider.overrideWithValue(builder)],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: host,
      ),
    );

void main() {
  testWidgets('a scanned code is normalized and returned', (t) async {
    ScannerHandle? handle;
    String? result;
    await t.pumpWidget(_app(
      (c, h) {
        handle = h;
        return const SizedBox(key: Key('fake-camera'));
      },
      _Host(onResult: (v) => result = v),
    ));
    await t.tap(find.text('scan'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('fake-camera')), findsOneWidget);

    handle!.onCode('  CN: *dt 2508*  ');
    await t.pumpAndSettle();
    expect(result, 'dt2508');
  });

  testWidgets('pattern mismatch warns but still returns the code', (t) async {
    ScannerHandle? handle;
    String? result;
    await t.pumpWidget(_app(
      (c, h) {
        handle = h;
        return const SizedBox();
      },
      _Host(onResult: (v) => result = v, pattern: r'^\d{8}$'),
    ));
    await t.tap(find.text('scan'));
    await t.pumpAndSettle();
    handle!.onCode('ABC');
    await t.pumpAndSettle();
    expect(result, 'ABC');
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('camera unavailable falls back to manual entry', (t) async {
    ScannerHandle? handle;
    String? result;
    await t.pumpWidget(_app(
      (c, h) {
        handle = h;
        return const SizedBox();
      },
      _Host(onResult: (v) => result = v),
    ));
    await t.tap(find.text('scan'));
    await t.pumpAndSettle();
    handle!.onUnavailable();
    await t.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    await t.enterText(find.byType(TextField), ' 998877 ');
    await t.tap(find.text('Use'));
    await t.pumpAndSettle();
    expect(result, '998877');
  });

  testWidgets('dismissing returns null', (t) async {
    String? result = 'unset';
    await t.pumpWidget(_app((c, h) => const SizedBox(), _Host(onResult: (v) => result = v)));
    await t.tap(find.text('scan'));
    await t.pumpAndSettle();
    await t.tapAt(const Offset(10, 10));
    await t.pumpAndSettle();
    expect(result, isNull);
  });
}
