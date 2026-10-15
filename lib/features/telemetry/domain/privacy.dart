/// Removes personal data from text before it can reach logs or crash reports
/// (implementation plan §10: no customer PII in logs).
abstract final class PiiScrubber {
  static final _phone = RegExp(r'(?:\+?880|0)?1[3-9][\d\s\-]{8,11}');
  static final _digits = RegExp(r'\d{7,}');
  static final _bnDigits = RegExp(r'[০-৯]{7,}');
  static final _email = RegExp(r'[\w.+-]+@[\w-]+\.[\w.-]+');
  static final _url = RegExp(r'https?://\S+');

  static String scrub(String input) => input
      .replaceAll(_email, '[email]')
      .replaceAll(_url, '[url]')
      .replaceAll(_phone, '[phone]')
      .replaceAll(_digits, '[number]')
      .replaceAll(_bnDigits, '[number]');
}

/// Event names allowed to leave the device (when the seller opted in). Only
/// names, counts and durations: never customer, address or amount values.
abstract final class AllowedEvents {
  static const names = {
    'app_open',
    'order_created',
    'status_updated',
    'payout_reconciled',
    'backup_created',
    'report_opened',
    'import_completed',
  };

  static const allowedParamKeys = {'ms', 'count', 'kind', 'ok'};

  /// Keeps only whitelisted params with number/bool/short-token values.
  static Map<String, Object> sanitize(Map<String, Object?> params) {
    final out = <String, Object>{};
    for (final e in params.entries) {
      if (!allowedParamKeys.contains(e.key)) continue;
      final v = e.value;
      if (v is num || v is bool) {
        out[e.key] = v!;
      } else if (v is String && RegExp(r'^[a-z_]{1,24}$').hasMatch(v)) {
        out[e.key] = v;
      }
    }
    return out;
  }
}
