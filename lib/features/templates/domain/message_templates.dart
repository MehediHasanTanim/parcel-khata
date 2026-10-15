/// Kinds of editable message snippets (feature spec F11). The app never sends
/// anything itself: text is handed to WhatsApp/SMS via a share intent.
enum TemplateKind {
  confirmation('confirmation'),
  dispatch('dispatch'),
  deliveryFollowUp('delivery_followup'),
  beAvailable('be_available');

  const TemplateKind(this.dbValue);
  final String dbValue;

  static TemplateKind? fromDb(String v) {
    for (final k in TemplateKind.values) {
      if (k.dbValue == v) return k;
    }
    return null;
  }
}

abstract final class MessageTemplates {
  static const placeholders = ['name', 'cn', 'amount', 'order', 'courier', 'shop'];

  /// Built-in bodies per language ('bn' / 'en').
  static const Map<String, Map<TemplateKind, String>> defaults = {
    'en': {
      TemplateKind.confirmation:
          'Hello {name}, your order {order} is confirmed. Total COD: {amount}. Thank you! - {shop}',
      TemplateKind.dispatch:
          'Hello {name}, your order {order} has been sent with {courier}. '
              'Tracking no: {cn}. COD: {amount}. - {shop}',
      TemplateKind.deliveryFollowUp:
          'Hello {name}, did you receive order {order}? Please let us know. - {shop}',
      TemplateKind.beAvailable:
          'Hello {name}, the courier will call you for order {order} (COD {amount}). '
              'Please keep your phone on and be available. - {shop}',
    },
    'bn': {
      TemplateKind.confirmation:
          'আসসালামু আলাইকুম {name}, আপনার অর্ডার {order} নিশ্চিত হয়েছে। মোট COD: {amount}। ধন্যবাদ! - {shop}',
      TemplateKind.dispatch:
          'আসসালামু আলাইকুম {name}, আপনার অর্ডার {order} {courier}-এর মাধ্যমে পাঠানো হয়েছে। '
              'ট্র্যাকিং নং: {cn}। COD: {amount}। - {shop}',
      TemplateKind.deliveryFollowUp:
          'আসসালামু আলাইকুম {name}, আপনি কি অর্ডার {order} পেয়েছেন? অনুগ্রহ করে জানাবেন। - {shop}',
      TemplateKind.beAvailable:
          'আসসালামু আলাইকুম {name}, অর্ডার {order} (COD {amount}) এর জন্য কুরিয়ার আপনাকে ফোন করবে। '
              'অনুগ্রহ করে ফোন খোলা রাখুন। - {shop}',
    },
  };

  static String defaultBody(TemplateKind k, String lang) =>
      (defaults[lang] ?? defaults['en']!)[k]!;

  /// Replaces `{key}` with values; unknown placeholders are left untouched so
  /// the seller notices a typo instead of sending a blank.
  static String render(String body, Map<String, String> values) {
    return body.replaceAllMapped(RegExp(r'\{(\w+)\}'), (m) => values[m.group(1)] ?? m.group(0)!);
  }

  /// Placeholders used in [body] that are not known.
  static List<String> unknownPlaceholders(String body) => [
        for (final m in RegExp(r'\{(\w+)\}').allMatches(body))
          if (!placeholders.contains(m.group(1))) m.group(1)!,
      ];

  /// `wa.me` deep link: international digits only, text URL-encoded.
  static Uri whatsAppLink(String phone, String text) {
    var digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('00')) digits = digits.substring(2);
    if (digits.startsWith('0')) digits = '880${digits.substring(1)}';
    return Uri.https('wa.me', '/$digits', {'text': text});
  }
}
