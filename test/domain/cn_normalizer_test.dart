import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_khata/features/couriers/domain/cn_normalizer.dart';

void main() {
  String n(String s) => CnNormalizer.normalize(s);

  test('trims and removes inner whitespace', () {
    expect(n('  DT 2508 12ABC \n'), 'DT250812ABC');
  });

  test('strips labels', () {
    expect(n('CN: 1234567'), '1234567');
    expect(n('Consignment No: DT1'), 'DT1');
    expect(n('tracking # ab12'), 'ab12');
    expect(n('AWB-998877'), '998877');
  });

  test('keeps a CN that merely starts with letters of a label', () {
    expect(n('CN123456'), 'CN123456');
    expect(n('IDX99'), 'IDX99');
  });

  test('strips barcode start/stop and check characters', () {
    expect(n('*A1B2C3*'), 'A1B2C3');
    expect(n('\$123456\$'), '123456');
  });

  test('removes zero-width characters and maps Bangla digits', () {
    expect(n('​১২৩৪﻿'), '1234');
  });

  test('is idempotent', () {
    for (final s in ['CN: *a b*', ' 123 ', 'tracking no: X-9']) {
      expect(n(n(s)), n(s));
    }
  });

  test('empty stays empty', () {
    expect(n('   '), '');
  });

  test('pattern: null when none/invalid, false on mismatch', () {
    expect(CnNormalizer.matchesPattern('A1', null), isNull);
    expect(CnNormalizer.matchesPattern('A1', ''), isNull);
    expect(CnNormalizer.matchesPattern('A1', '('), isNull);
    expect(CnNormalizer.matchesPattern('A1', r'^[A-Z]\d$'), isTrue);
    expect(CnNormalizer.matchesPattern('AA1', r'^[A-Z]\d$'), isFalse);
  });
}
