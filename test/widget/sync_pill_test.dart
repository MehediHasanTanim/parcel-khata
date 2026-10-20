import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_khata/app/theme.dart';
import 'package:parcel_khata/features/sync/application/sync_engine.dart';
import 'package:parcel_khata/features/sync/application/sync_status_provider.dart';
import 'package:parcel_khata/l10n/l10n.dart';
import 'package:parcel_khata/shared/sync_pill.dart';

Widget _host(SyncStatus s) => ProviderScope(
      overrides: [syncStatusProvider.overrideWith((ref) async => s)],
      child: MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: Center(child: SyncPill())),
      ),
    );

void main() {
  testWidgets('pill is hidden while sync is off', (t) async {
    await t.pumpWidget(_host(const SyncStatus(SyncPhase.disabled)));
    await t.pumpAndSettle();
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('pill shows the pending count with text, not colour alone', (t) async {
    await t.pumpWidget(_host(const SyncStatus(SyncPhase.pending, pending: 3)));
    await t.pumpAndSettle();
    expect(find.text('Pending 3'), findsOneWidget);
    expect(t.getSize(find.byType(InkWell)).height, greaterThanOrEqualTo(48));
  });

  testWidgets('pill shows the failed state', (t) async {
    await t.pumpWidget(_host(const SyncStatus(SyncPhase.error, lastError: 'x')));
    await t.pumpAndSettle();
    expect(find.text('Sync failed'), findsOneWidget);
  });

  testWidgets('pill shows the synced state', (t) async {
    await t.pumpWidget(_host(const SyncStatus(SyncPhase.synced)));
    await t.pumpAndSettle();
    expect(find.text('Synced'), findsOneWidget);
  });
}
