import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_khata/features/customers/domain/phone_normalizer.dart';

void main() {
  const canonical = '01712345678';

  test('accepted formats normalize to the same canonical number', () {
    for (final s in [
      '01712345678',
      '+8801712345678',
      '8801712345678',
      '008801712345678',
      '01712-345678',
      '0171 234 5678',
      '+880 1712-345678',
      '(0171) 2345678',
      '০১৭১২৩৪৫৬৭৮',
      '+৮৮০১৭১২৩৪৫৬৭৮',
      '1712345678',
      '  01712345678  ',
    ]) {
      expect(PhoneNormalizer.normalize(s), canonical, reason: s);
    }
  });

  test('all valid operator prefixes', () {
    for (final p in ['013', '014', '015', '016', '017', '018', '019']) {
      expect(PhoneNormalizer.normalize('${p}12345678'), '${p}12345678');
    }
  });

  test('invalid numbers return null', () {
    for (final s in [
      '',
      'abc',
      '0171234567',
      '017123456789',
      '01212345678',
      '02712345678',
      '+8801212345678',
      '12345',
    ]) {
      expect(PhoneNormalizer.normalize(s), isNull, reason: s);
    }
  });

  test('keyFor falls back to trimmed input', () {
    expect(PhoneNormalizer.keyFor(' 123 '), '123');
    expect(PhoneNormalizer.keyFor('+8801712345678'), canonical);
  });
}
