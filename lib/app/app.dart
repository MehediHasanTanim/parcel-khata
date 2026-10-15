import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parcel_khata/app/locale_provider.dart';
import 'package:parcel_khata/app/router.dart';
import 'package:parcel_khata/app/theme.dart';
import 'package:parcel_khata/features/reminders/application/attention_service.dart';
import 'package:parcel_khata/features/reminders/application/digest_service.dart';
import 'package:parcel_khata/features/onboarding/presentation/onboarding_gate.dart';
import 'package:parcel_khata/features/security/presentation/lock_gate.dart';
import 'package:parcel_khata/features/settings/application/settings_repository.dart';
import 'package:parcel_khata/l10n/l10n.dart';

class ParcelKhataApp extends ConsumerWidget {
  const ParcelKhataApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Make sure the shop row exists, then follow the persisted language.
    ref
      ..watch(_bootstrapProvider)
      ..listen(attentionProvider, (_, next) {
        // Keep the next digest notification in step with the queue.
        if (next.hasValue) {
          final lang = ref.read(localeProvider);
          ref.read(digestServiceProvider).refresh(lang);
        }
      })
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
      // Content must stay usable at 200% font size (accessibility pass).
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        maxScaleFactor: 2,
        child: LockGate(child: OnboardingGate(child: child ?? const SizedBox.shrink())),
      ),
    );
  }
}

final _bootstrapProvider = FutureProvider<void>(
    (ref) => ref.watch(settingsRepositoryProvider).ensureShop());
