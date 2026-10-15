import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('en and bn ARB files have identical keys', () {
    Set<String> keys(String f) => (jsonDecode(File(f).readAsStringSync())
            as Map<String, dynamic>)
        .keys
        .where((k) => !k.startsWith('@'))
        .toSet();
    final en = keys('lib/l10n/app_en.arb');
    final bn = keys('lib/l10n/app_bn.arb');
    expect(en.difference(bn), isEmpty, reason: 'missing in bn');
    expect(bn.difference(en), isEmpty, reason: 'missing in en');
  });
}
