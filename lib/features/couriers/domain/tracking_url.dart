/// Courier tracking link template with a `{cn}` placeholder.
abstract final class TrackingUrl {
  static const placeholder = '{cn}';

  static bool isValidTemplate(String template) {
    final t = template.trim();
    if (!t.contains(placeholder)) return false;
    final uri = Uri.tryParse(t.replaceAll(placeholder, 'X'));
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  /// Substitutes the (URL-encoded) consignment number.
  static Uri? build(String template, String cn) {
    if (!isValidTemplate(template) || cn.trim().isEmpty) return null;
    return Uri.parse(
        template.trim().replaceAll(placeholder, Uri.encodeComponent(cn.trim())));
  }
}
