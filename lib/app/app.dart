import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parcel_khata/app/locale_provider.dart';
import 'package:parcel_khata/app/router.dart';
import 'package:parcel_khata/app/theme.dart';
import 'package:parcel_khata/features/settings/application/settings_repository.dart';
import 'package:parcel_khata/l10n/l10n.dart';

class ParcelKhataApp extends ConsumerWidget {
  const ParcelKhataApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Make sure the shop row exists, then follow the persisted language.
    ref
      ..watch(_bootstrapProvider)
      ..listen(shopSettingsProvider, (_, next) {
        final code = next.value?.languageCode;
        if (code != null && code != ref.read(localeProvider).languageCode) {
          ref.read(localeProvider.notifier).set(Locale(code));
        }
      });
    return MaterialApp.router(
      onGenerateTitle: (c) => c.l10n.appName,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      locale: ref.watch(localeProvider),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: appRouter,
    );
  }
}

final _bootstrapProvider = FutureProvider<void>(
    (ref) => ref.watch(settingsRepositoryProvider).ensureShop());
