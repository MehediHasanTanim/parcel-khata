import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the Bangla translation work: every string exists in both locales,
/// uses the same placeholders, and no Bangla value was left as English.
void main() {
  final en = jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync()) as Map<String, dynamic>;
  final bn = jsonDecode(File('lib/l10n/app_bn.arb').readAsStringSync()) as Map<String, dynamic>;
  Iterable<String> keys(Map<String, dynamic> m) => m.keys.where((k) => !k.startsWith('@') && !k.startsWith('@@'));
  final placeholder = RegExp(r"(?<!')\{(\w+)(?:,[^}]*)?\}");

  test('same keys in both locales', () {
    expect(keys(en).toSet(), keys(bn).toSet());
  });

  test('placeholders match per key', () {
    for (final k in keys(en)) {
      Set<String> names(String s) =>
          placeholder.allMatches(s).map((m) => m.group(1)!).toSet();
      expect(names(bn[k] as String), names(en[k] as String), reason: k);
    }
  });

  test('bangla values contain Bangla script (except brand/loanwords)', () {
    const allowed = {
      'languageEnglish', // "English"
      'secEraseWord', // typed confirmation word is the same in every language
      'payCod', // "COD"
      'sku',
      'methodBank',
      'methodBkash',
    };
    final bangla = RegExp('[ঀ-৿]');
    final offenders = [
      for (final k in keys(bn))
        if (!allowed.contains(k) && !bangla.hasMatch(bn[k] as String)) k,
    ];
    // Strings that are only symbols/placeholders are fine.
    final real = offenders.where((k) => RegExp(r'[A-Za-z]{3,}').hasMatch(bn[k] as String)).toList();
    expect(real, isEmpty, reason: 'not translated: $real');
  });
}
