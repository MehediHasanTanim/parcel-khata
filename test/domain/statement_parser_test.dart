import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/features/cod/domain/statement_parser.dart';

void main() {
  final generic = kStatementPresets.first;

  test('maps headers by alternatives, case and spacing', () {
    final r = StatementParser.parse([
      ['Consignment ID', 'COD Amount', 'Delivery Charge', 'COD Charge', 'Payable', 'Status'],
      ['DT1', '1,250', '60', '12.50', '1,177.50', 'Delivered'],
      ['DT2', '৳ 800', '60', '', '740', 'Delivered'],
    ], generic);
    expect(r.rows, hasLength(2));
    expect(r.rows[0].cnRaw, 'DT1');
    expect(r.rows[0].collected, const Money.taka(1250));
    expect(r.rows[0].codFee!.poisha, 1250);
    expect(r.rows[0].netPayable!.poisha, 117750);
    expect(r.rows[1].collected, const Money.taka(800));
    expect(r.rows[1].codFee, isNull);
    expect(r.missingFields, containsAll(['return_fee', 'date']));
    expect(r.hasCnColumn, isTrue);
  });

  test('skips title lines above the header and blank rows', () {
    final r = StatementParser.parse([
      ['Pathao Merchant Statement', ''],
      ['Period: Sept 2026', ''],
      ['CN', 'Collected'],
      ['A1', '100'],
      ['', ''],
      ['A2', '200'],
    ], generic);
    expect(r.headerRowIndex, 2);
    expect(r.rows.map((x) => x.cnRaw), ['A1', 'A2']);
    expect(r.rows.last.row, 3); // blank row still counts in numbering
  });

  test('bad amounts and missing CN become issues, not crashes', () {
    final r = StatementParser.parse([
      ['CN', 'Collected', 'Payable'],
      ['A1', 'abc', '10'],
      ['', '5', '5'],
      ['A3', '১২০০', ''],
    ], generic);
    expect(r.issues.map((i) => i.code), ['bad_amount_collected', 'missing_cn']);
    expect(r.rows.first.collected, isNull);
    expect(r.rows.last.collected, const Money.taka(1200));
  });

  test('no recognizable header yields nothing and says so', () {
    final r = StatementParser.parse([
      ['foo', 'bar'],
      ['1', '2'],
    ], generic);
    expect(r.hasCnColumn, isFalse);
    expect(r.rows, isEmpty);
  });

  test('profiles are editable data: a custom header works', () {
    final custom = generic.copyWith(columns: {...generic.columns, 'cn': 'পার্সেল নং'});
    final r = StatementParser.parse([
      ['পার্সেল নং', 'Collected'],
      ['X9', '50'],
    ], custom);
    expect(r.rows.single.cnRaw, 'X9');
  });

  test('dates: iso, dd/mm/yyyy and excel serials', () {
    final r = StatementParser.parse([
      ['CN', 'Date'],
      ['A', '2026-09-01'],
      ['B', '05/09/2026'],
      ['C', '46037'],
      ['D', 'soon'],
    ], generic);
    expect(r.rows[0].date, DateTime(2026, 9, 1));
    expect(r.rows[1].date, DateTime(2026, 9, 5));
    expect(r.rows[2].date, DateTime(2026, 1, 15));
    expect(r.rows[3].date, isNull);
  });

  test('presets are templates only: no rates or amounts anywhere', () {
    for (final p in kStatementPresets) {
      for (final v in p.columns.values) {
        expect(RegExp(r'\d').hasMatch(v), isFalse, reason: '${p.name}: $v');
      }
    }
  });
}
