import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parcel_khata/core/time/providers.dart';
import 'package:parcel_khata/features/settings/application/settings_repository.dart';
import 'package:parcel_khata/features/telemetry/domain/telemetry.dart';

final telemetrySinkProvider = Provider<BufferedSink>((ref) => BufferedSink());

/// Opt-in telemetry. Replace the sink with a Crashlytics/Sentry adapter when
/// one is configured; consent and PII rules stay here (docs/release.md).
final telemetryProvider = Provider<Telemetry>((ref) {
  final clock = ref.watch(clockProvider);
  return Telemetry(
    ref.watch(telemetrySinkProvider),
    // Read lazily so a consent change applies immediately.
    hasConsent: () => ref.read(shopSettingsProvider).value?.telemetryConsent ?? false,
    now: clock.now,
  );
});
