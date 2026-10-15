import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Minimal read-only `.xlsx` reader: first worksheet -> text rows, so a
/// spreadsheet feeds the same row model as CSV. Formulas are read as their
/// cached values; styles/formatting are ignored.
abstract final class XlsxReader {
  static List<List<String>> read(Uint8List bytes) {
    final zip = ZipDecoder().decodeBytes(bytes);
    ArchiveFile? file(String name) {
      for (final f in zip) {
        if (f.name == name) return f;
      }
      return null;
    }

    String text(ArchiveFile f) => utf8.decode(f.content as List<int>);

    final shared = <String>[];
    final ss = file('xl/sharedStrings.xml');
    if (ss != null) {
      final doc = XmlDocument.parse(text(ss));
      for (final si in doc.findAllElements('si')) {
        shared.add(si.findAllElements('t').map((t) => t.innerText).join());
      }
    }

    // Lowest-numbered worksheet is the first visible sheet in practice.
    final sheets = [
      for (final f in zip)
        if (RegExp(r'^xl/worksheets/sheet\d+\.xml$').hasMatch(f.name)) f,
    ]..sort((a, b) => _sheetNo(a.name).compareTo(_sheetNo(b.name)));
    if (sheets.isEmpty) return const [];

    final doc = XmlDocument.parse(text(sheets.first));
    final rows = <int, Map<int, String>>{};
    var maxCol = 0;
    for (final c in doc.findAllElements('c')) {
      final ref = c.getAttribute('r');
      if (ref == null) continue;
      final m = RegExp(r'^([A-Z]+)(\d+)$').firstMatch(ref);
      if (m == null) continue;
      final col = _colIndex(m.group(1)!);
      final row = int.parse(m.group(2)!);
      final type = c.getAttribute('t');
      String value;
      if (type == 'inlineStr') {
        value = c.findAllElements('t').map((t) => t.innerText).join();
      } else {
        final v = c.getElement('v')?.innerText ?? '';
        if (type == 's') {
          final i = int.tryParse(v);
          value = i != null && i < shared.length ? shared[i] : '';
        } else if (type == 'b') {
          value = v == '1' ? 'true' : 'false';
        } else {
          value = _cleanNumber(v);
        }
      }
      rows.putIfAbsent(row, () => {})[col] = value;
      if (col > maxCol) maxCol = col;
    }
    final keys = rows.keys.toList()..sort();
    return [
      for (final r in keys)
        [for (var c = 0; c <= maxCol; c++) rows[r]![c] ?? ''],
    ].where((r) => r.any((x) => x.trim().isNotEmpty)).toList();
  }

  static int _sheetNo(String name) =>
      int.parse(RegExp(r'sheet(\d+)\.xml').firstMatch(name)!.group(1)!);

  static int _colIndex(String letters) {
    var n = 0;
    for (final u in letters.codeUnits) {
      n = n * 26 + (u - 64);
    }
    return n - 1;
  }

  /// "12.0" -> "12"; keeps real decimals.
  static String _cleanNumber(String v) {
    final d = double.tryParse(v);
    if (d == null) return v;
    if (d == d.roundToDouble() && d.abs() < 1e15) return d.toInt().toString();
    return v;
  }
}
