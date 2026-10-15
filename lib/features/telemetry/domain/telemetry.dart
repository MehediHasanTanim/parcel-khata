import 'package:meta/meta.dart';
import 'package:parcel_khata/features/telemetry/domain/privacy.dart';

@immutable
class TelemetryEvent {
  const TelemetryEvent(this.name, this.params, this.at);
  final String name;
  final Map<String, Object> params;
  final DateTime at;
}

abstract class TelemetrySink {
  void record(TelemetryEvent e);
  void recordError(String scrubbedMessage, String scrubbedStack);
}

/// Opt-in gate in front of any sink. Consent defaults to "not given": nothing
/// is recorded until the seller says yes, and nothing unexpected passes.
class Telemetry {
  Telemetry(this._sink, {required bool Function() hasConsent, required DateTime Function() now})
      : _hasConsent = hasConsent,
        _now = now;

  final TelemetrySink _sink;
  final bool Function() _hasConsent;
  final DateTime Function() _now;

  void event(String name, [Map<String, Object?> params = const {}]) {
    if (!_hasConsent()) return;
    if (!AllowedEvents.names.contains(name)) return;
    _sink.record(TelemetryEvent(name, AllowedEvents.sanitize(params), _now()));
  }

  void error(Object error, StackTrace? stack) {
    if (!_hasConsent()) return;
    _sink.recordError(
      PiiScrubber.scrub(error.toString()),
      PiiScrubber.scrub(stack?.toString() ?? ''),
    );
  }
}

/// Keeps the last [capacity] events in memory (debug menu / future uploader).
class BufferedSink implements TelemetrySink {
  BufferedSink({this.capacity = 200});

  final int capacity;
  final List<TelemetryEvent> events = [];
  final List<String> errors = [];

  @override
  void record(TelemetryEvent e) {
    events.add(e);
    if (events.length > capacity) events.removeAt(0);
  }

  @override
  void recordError(String message, String stack) {
    errors.add('$message\n$stack');
    if (errors.length > 50) errors.removeAt(0);
  }
}
