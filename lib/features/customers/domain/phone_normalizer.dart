/// Normalizes Bangladeshi mobile numbers to the canonical `01XXXXXXXXX` form.
abstract final class PhoneNormalizer {
  static const _bn = '০১২৩৪৫৬৭৮৯';

  /// Returns the canonical 11-digit number or null if it is not a valid BD
  /// mobile number.
  static String? normalize(String input) {
    var s = input.replaceAllMapped(
        RegExp('[০-৯]'), (m) => _bn.indexOf(m.group(0)!).toString());
    s = s.replaceAll(RegExp(r'[^0-9+]'), '');
    if (s.startsWith('+')) s = s.substring(1);
    if (s.startsWith('00')) s = s.substring(2);
    if (s.startsWith('880')) s = s.substring(3);
    // After the country code the leading 0 is dropped (e.g. +8801712...).
    if (s.length == 10 && s.startsWith('1')) s = '0$s';
    if (!RegExp(r'^01[3-9]\d{8}$').hasMatch(s)) return null;
    return s;
  }

  /// Best-effort key for duplicate detection of free-form input.
  static String keyFor(String input) => normalize(input) ?? input.trim();
}
