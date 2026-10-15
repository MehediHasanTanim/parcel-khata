import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parcel_khata/app/app.dart';
import 'package:parcel_khata/features/backup/application/drive_scheduler.dart';
import 'package:parcel_khata/features/telemetry/application/telemetry_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DriveScheduler.init();
  final container = ProviderContainer();

  // Crash reports are opt-in and scrubbed of personal data (telemetry domain).
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    container.read(telemetryProvider).error(details.exception, details.stack);
    previous?.call(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    container.read(telemetryProvider).error(error, stack);
    return kReleaseMode; // swallow in release; surface in debug
  };

  container.read(telemetryProvider).event('app_open');
  runApp(UncontrolledProviderScope(container: container, child: const ParcelKhataApp()));
}
