/// Minimal RFC 4180 CSV writer/parser (UTF-8, with optional BOM).
abstract final class Csv {
  static const bom = '﻿';

  static String _field(String v) {
    final needsQuote = v.contains(',') || v.contains('"') || v.contains('\n') || v.contains('\r');
    return needsQuote ? '"${v.replaceAll('"', '""')}"' : v;
  }

  /// Rows to text. [withBom] makes Excel open Bangla text correctly.
  static String encode(List<List<String>> rows, {bool withBom = true}) {
    final b = StringBuffer();
    if (withBom) b.write(bom);
    for (final r in rows) {
      b
        ..write(r.map(_field).join(','))
        ..write('\r\n');
    }
    return b.toString();
  }

  /// Text to rows; handles quotes, embedded newlines, BOM, CRLF/LF.
  static List<List<String>> parse(String input) {
    var s = input;
    if (s.startsWith(bom)) s = s.substring(1);
    final rows = <List<String>>[];
    var row = <String>[];
    final field = StringBuffer();
    var inQuotes = false;
    var any = false;
    for (var i = 0; i < s.length; i++) {
      final c = s[i];
      if (inQuotes) {
        if (c == '"') {
          if (i + 1 < s.length && s[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          field.write(c);
        }
        continue;
      }
      switch (c) {
        case '"':
          inQuotes = true;
          any = true;
        case ',':
          row.add(field.toString());
          field.clear();
          any = true;
        case '\r':
          break;
        case '\n':
          if (any || field.isNotEmpty) {
            row.add(field.toString());
            rows.add(row);
          }
          row = <String>[];
          field.clear();
          any = false;
        default:
          field.write(c);
          any = true;
      }
    }
    if (any || field.isNotEmpty) {
      row.add(field.toString());
      rows.add(row);
    }
    return rows;
  }
}
