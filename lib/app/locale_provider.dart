import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Current UI locale. Persisted in settings in Sprint 1 (S1-19).
class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() => const Locale('bn');

  // ignore: use_setters_to_change_properties
  void set(Locale l) => state = l;
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(LocaleNotifier.new);
