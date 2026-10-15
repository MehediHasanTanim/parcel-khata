import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/features/orders/domain/paste_parser.dart';

import '../fixtures/paste_corpus.dart';

void main() {
  final all = [...handCases, ...generatedCases()];

  test('corpus has at least 100 messages in Bangla, English and mixed', () {
    expect(all.length, greaterThanOrEqualTo(100));
    expect(all.where((c) => RegExp('[ঀ-৿]').hasMatch(c.text)).length, greaterThan(20));
    expect(all.where((c) => !RegExp('[ঀ-৿]').hasMatch(c.text)).length, greaterThan(20));
  });

  test('precision / recall on the fixture corpus meets the recorded targets', () {
    var phoneTp = 0, phoneN = 0;
    var nameTp = 0, nameExp = 0, namePred = 0;
    var addrTp = 0, addrExp = 0, addrPred = 0;
    var lineTp = 0, lineExp = 0, linePred = 0;
    final misses = <String>[];

    for (final c in all) {
      final d = PasteParser.parse(c.text, catalog: corpusCatalog);
      if (c.phone != null) {
        phoneN++;
        if (d.phone?.value == c.phone) {
          phoneTp++;
        } else {
          misses.add('[${c.tag}] phone ${d.phone?.value} != ${c.phone}\n${c.text}');
        }
      }
      if (c.name != null) {
        nameExp++;
        if (d.name != null) namePred++;
        if (d.name?.value == c.name) {
          nameTp++;
        } else {
          misses.add('[${c.tag}] name "${d.name?.value}" != "${c.name}"\n${c.text}');
        }
      }
      if (c.address != null) {
        addrExp++;
        if (d.address != null) addrPred++;
        if (d.address?.value.contains(c.address!) ?? false) {
          addrTp++;
        } else {
          misses.add('[${c.tag}] address "${d.address?.value}" lacks "${c.address}"\n${c.text}');
        }
      }
      if (c.total != null) {
        final t = d.totalHint?.poisha;
        if (t != c.total! * 100) {
          misses.add('[${c.tag}] total ${d.totalHint} != ${c.total}\n${c.text}');
        }
      }
      // Lines: multiset compare on (productId, qty).
      final exp = [for (final l in c.lines) '${l.productId}:${l.qty}'];
      final got = [for (final l in d.lines) '${l.product?.id}:${l.qty}'];
      lineExp += exp.length;
      linePred += got.length;
      final pool = [...exp];
      var hit = 0;
      for (final g in got) {
        if (pool.remove(g)) hit++;
      }
      lineTp += hit;
      if (hit != exp.length || got.length != exp.length) {
        misses.add('[${c.tag}] lines $got != $exp\n${c.text}');
      }
    }

    double p(int tp, int pred) => pred == 0 ? 1 : tp / pred;
    double r(int tp, int exp) => exp == 0 ? 1 : tp / exp;
    final report = StringBuffer()
      ..writeln('cases: ${all.length}')
      ..writeln('phone    recall ${r(phoneTp, phoneN).toStringAsFixed(3)}')
      ..writeln('name     precision ${p(nameTp, namePred).toStringAsFixed(3)} '
          'recall ${r(nameTp, nameExp).toStringAsFixed(3)}')
      ..writeln('address  precision ${p(addrTp, addrPred).toStringAsFixed(3)} '
          'recall ${r(addrTp, addrExp).toStringAsFixed(3)}')
      ..writeln('lines    precision ${p(lineTp, linePred).toStringAsFixed(3)} '
          'recall ${r(lineTp, lineExp).toStringAsFixed(3)}');
    // ignore: avoid_print
    print(report);
    // ignore: avoid_print
    for (final m in misses.take(25)) {
      print('MISS $m\n');
    }

    expect(misses.where((m) => m.contains('] total ')), isEmpty);

    // Targets (docs/plan/paste-parser-metrics.md). Raise as the parser improves.
    expect(r(phoneTp, phoneN), greaterThanOrEqualTo(0.99));
    expect(p(nameTp, namePred), greaterThanOrEqualTo(0.85));
    expect(r(nameTp, nameExp), greaterThanOrEqualTo(0.8));
    expect(p(addrTp, addrPred), greaterThanOrEqualTo(0.9));
    expect(r(addrTp, addrExp), greaterThanOrEqualTo(0.9));
    expect(p(lineTp, linePred), greaterThanOrEqualTo(0.85));
    expect(r(lineTp, lineExp), greaterThanOrEqualTo(0.85));
  });

  group('unit behaviour', () {
    test('Bangla digits and +880 / spaced phones normalize', () {
      expect(PasteParser.parse('ফোন ০১৭১২৩৪৫৬৭৮').phone!.value, '01712345678');
      expect(PasteParser.parse('call +880 1712-345678 now').phone!.value, '01712345678');
      expect(PasteParser.parse('017 1234 5678').phone!.value, '01712345678');
    });

    test('a price or order total is never mistaken for a phone', () {
      final d = PasteParser.parse('Total 1500 tk\nDelivery 60\nShirt 2 pcs');
      expect(d.phone, isNull);
      expect(d.totalHint, const Money.taka(1500));
      expect(d.deliveryHint, const Money.taka(60));
    });

    test('second number becomes an alternative, first stays primary', () {
      final d = PasteParser.parse('01712345678\n01812345679');
      expect(d.phone!.value, '01712345678');
      expect(d.altPhones, ['01812345679']);
    });

    test('matches are graded: exact = high, partial = medium, none = low', () {
      final d = PasteParser.parse('Cotton Shirt 2 pcs\nshirt\nGadget 1 pcs', catalog: corpusCatalog);
      expect(d.lines[0].confidence, Confidence.high);
      expect(d.lines[0].product!.id, 'shirt');
      expect(d.lines[1].product!.id, 'shirt');
      expect(d.lines[1].confidence, isNot(Confidence.low));
      expect(d.lines[2].product, isNull);
      expect(d.lines[2].confidence, Confidence.low);
    });

    test('ambiguous mention is flagged, not silently chosen', () {
      const cat = [
        CatalogProduct(id: 'a', name: 'Cotton Shirt Red'),
        CatalogProduct(id: 'b', name: 'Cotton Shirt Blue'),
      ];
      final d = PasteParser.parse('cotton shirt 1 pcs', catalog: cat);
      expect(d.lines.single.ambiguousWith, isNotEmpty);
      expect(d.lines.single.confidence, Confidence.medium);
    });

    test('price hint is captured but separate from the catalog price', () {
      final d = PasteParser.parse('Leather Wallet 450 tk', catalog: corpusCatalog);
      expect(d.lines.single.priceHint, const Money.taka(450));
      expect(d.lines.single.product!.id, 'wallet');
    });

    test('empty / whitespace / pure noise yields an empty draft', () {
      expect(PasteParser.parse('').isEmpty, isTrue);
      expect(PasteParser.parse('   \n  ').isEmpty, isTrue);
      expect(PasteParser.parse('Hi\nThanks').isEmpty, isTrue);
    });

    test('deterministic: same input, same output', () {
      const t = 'Name: A\nMobile: 01712345678\nProduct: Silk Saree x2';
      final a = PasteParser.parse(t, catalog: corpusCatalog);
      final b = PasteParser.parse(t, catalog: corpusCatalog);
      expect(a.lines.single.product!.id, b.lines.single.product!.id);
      expect(a.phone!.value, b.phone!.value);
    });

    test('never throws on arbitrary text', () {
      for (final t in ['😀😀', '((((', '1' * 200, 'নাম:', ':::', '\u0000\n\n', 'x2 x3 x4']) {
        expect(() => PasteParser.parse(t, catalog: corpusCatalog), returnsNormally);
      }
    });
  });
}
