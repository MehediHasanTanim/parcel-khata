/// Cleans a scanned/pasted consignment number. Pure Dart.
abstract final class CnNormalizer {
  static const _bn = '০১২৩৪৫৬৭৮৯';

  static final _labelPrefix = RegExp(
    r'^(?:consignment(?:\s*(?:no|number|id))?|tracking(?:\s*(?:no|number|id))?|awb|cn|c/n|id)\s*[:#.\-]\s*',
    caseSensitive: false,
  );

  /// Trim, drop invisible/whitespace characters, strip a leading label such
  /// as `CN:` / `Tracking No:`, strip barcode start/stop or check characters
  /// (`*`, `$`, `#`) at either end, and map Bangla digits to ASCII.
  static String normalize(String raw) {
    var s = raw.trim();
    final buf = StringBuffer();
    for (final r in s.runes) {
      final i = _bn.indexOf(String.fromCharCode(r));
      if (i >= 0) {
        buf.write(i);
      } else {
        buf.writeCharCode(r);
      }
    }
    s = buf.toString();
    // Zero-width / BOM / control characters.
    s = s.replaceAll(RegExp(r'[​-‏⁠﻿\u0000-\u001F]'), '');
    s = s.trim();
    s = s.replaceFirst(_labelPrefix, '');
    s = s.replaceAll(RegExp(r'\s+'), '');
    s = s.replaceAll(RegExp(r'^[*$#]+|[*$#]+$'), '');
    return s;
  }

  /// null when there is no pattern to check; false is a soft warning only.
  static bool? matchesPattern(String cn, String? pattern) {
    if (pattern == null || pattern.trim().isEmpty) return null;
    try {
      return RegExp(pattern).hasMatch(cn);
    } on FormatException {
      return null;
    }
  }
}
