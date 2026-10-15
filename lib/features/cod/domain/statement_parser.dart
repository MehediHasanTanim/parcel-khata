import 'package:meta/meta.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/features/cod/domain/statement_import.dart';

/// Fields a statement row can supply.
const kStatementFields = [
  'cn',
  'collected',
  'delivery_fee',
  'cod_fee',
  'return_fee',
  'net_payable',
  'status',
  'date',
];

/// Which statement column feeds each field. A value may list alternative
/// header spellings separated by `|` (case/spacing insensitive).
@immutable
class StatementProfile {
  const StatementProfile({
    required this.name,
    required this.columns,
    this.toleranceTaka = 0,
  });

  final String name;
  final Map<String, String> columns;

  /// Collected-amount difference (whole taka) still treated as a match.
  final int toleranceTaka;

  StatementProfile copyWith({String? name, Map<String, String>? columns, int? toleranceTaka}) =>
      StatementProfile(
        name: name ?? this.name,
        columns: columns ?? this.columns,
        toleranceTaka: toleranceTaka ?? this.toleranceTaka,
      );
}

/// Template starting points: column names only, never rates. The spellings
/// are best-effort guesses of common portal exports; sellers edit them.
const kStatementPresets = <StatementProfile>[
  StatementProfile(name: 'Generic', columns: {
    'cn': 'consignment|consignment no|consignment id|cn|tracking|tracking no|awb',
    'collected': 'collected amount|cod amount|collected|cod|amount',
    'delivery_fee': 'delivery charge|delivery fee|delivery',
    'cod_fee': 'cod charge|cod fee',
    'return_fee': 'return charge|return fee',
    'net_payable': 'payable|net payable|payable amount|net amount|payout',
    'status': 'status|delivery status',
    'date': 'date|delivered date|delivery date',
  }),
  StatementProfile(name: 'Pathao (template)', columns: {
    'cn': 'consignment id|consignment|merchant order id',
    'collected': 'collected amount|amount to collect|collected',
    'delivery_fee': 'delivery fee|delivery charge',
    'cod_fee': 'cod fee',
    'return_fee': 'return fee',
    'net_payable': 'payable|net payable|payout amount',
    'status': 'status',
    'date': 'delivered at|date',
  }),
  StatementProfile(name: 'Steadfast (template)', columns: {
    'cn': 'consignment id|consignment no|tracking code',
    'collected': 'collected amount|cod amount|collected',
    'delivery_fee': 'delivery charge|delivery fee',
    'cod_fee': 'cod charge',
    'return_fee': 'return charge',
    'net_payable': 'payable|net payable',
    'status': 'status',
    'date': 'delivered date|date',
  }),
  StatementProfile(name: 'RedX (template)', columns: {
    'cn': 'tracking id|tracking no|tracking',
    'collected': 'collected|cash collected|collected amount',
    'delivery_fee': 'delivery charge|delivery fee',
    'cod_fee': 'cod charge',
    'return_fee': 'return charge',
    'net_payable': 'payable|net payable|payment',
    'status': 'status',
    'date': 'delivered date|date',
  }),
];

@immutable
class StatementParseIssue {
  const StatementParseIssue(this.row, this.code);
  final int row;
  final String code;
}

@immutable
class StatementParseResult {
  const StatementParseResult({
    required this.rows,
    required this.issues,
    required this.missingFields,
    required this.headerRowIndex,
  });

  final List<StatementRow> rows;
  final List<StatementParseIssue> issues;

  /// Profile fields whose header was not found in the file.
  final List<String> missingFields;

  /// Index of the header row within the supplied table, or -1.
  final int headerRowIndex;

  bool get hasCnColumn => !missingFields.contains('cn') && headerRowIndex >= 0;
}

abstract final class StatementParser {
  static String _norm(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'[\s_\-./]+'), ' ');

  static const _bn = '০১২৩৪৫৬৭৮৯';

  /// "৳ 1,250.50", "Tk 800", "1 250" -> money; blank / junk -> null.
  static Money? parseMoney(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return null;
    final b = StringBuffer();
    for (final r in s.runes) {
      final ch = String.fromCharCode(r);
      final i = _bn.indexOf(ch);
      b.write(i >= 0 ? '$i' : ch);
    }
    s = b.toString().replaceAll(RegExp(r'tk|bdt|taka|৳', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'[,\s]'), '');
    if (!RegExp(r'^-?\d+(\.\d+)?$').hasMatch(s)) return null;
    return Money.tryParse(s);
  }

  static int? _find(List<String> headers, String? spec) {
    if (spec == null || spec.trim().isEmpty) return null;
    final wanted = [for (final a in spec.split('|')) _norm(a)].where((a) => a.isNotEmpty);
    final norm = [for (final h in headers) _norm(h)];
    // Earlier alternatives win, so a more specific name beats a generic one.
    for (final w in wanted) {
      final i = norm.indexOf(w);
      if (i >= 0) return i;
    }
    return null;
  }

  static StatementParseResult parse(List<List<String>> table, StatementProfile profile) {
    // Portals sometimes put a title block above the header: scan a few rows.
    var headerIdx = -1;
    Map<String, int> map = {};
    for (var i = 0; i < table.length && i < 12; i++) {
      final cn = _find(table[i], profile.columns['cn']);
      if (cn != null) {
        headerIdx = i;
        map = {
          for (final f in kStatementFields)
            if (_find(table[i], profile.columns[f]) != null)
              f: _find(table[i], profile.columns[f])!,
        };
        break;
      }
    }
    if (headerIdx < 0) {
      return StatementParseResult(
        rows: const [],
        issues: const [],
        missingFields: [for (final f in kStatementFields) f],
        headerRowIndex: -1,
      );
    }
    String cell(List<String> r, String f) {
      final i = map[f];
      return i == null || i >= r.length ? '' : r[i].trim();
    }

    final rows = <StatementRow>[];
    final issues = <StatementParseIssue>[];
    for (var i = headerIdx + 1; i < table.length; i++) {
      final r = table[i];
      if (r.every((c) => c.trim().isEmpty)) continue;
      final n = i - headerIdx;
      final cn = cell(r, 'cn');
      if (cn.isEmpty) {
        issues.add(StatementParseIssue(n, 'missing_cn'));
        continue;
      }
      Money? money(String f) {
        final raw = cell(r, f);
        if (raw.isEmpty) return null;
        final m = parseMoney(raw);
        if (m == null) issues.add(StatementParseIssue(n, 'bad_amount_$f'));
        return m;
      }

      rows.add(StatementRow(
        row: n,
        cnRaw: cn,
        collected: money('collected'),
        deliveryFee: money('delivery_fee'),
        codFee: money('cod_fee'),
        returnFee: money('return_fee'),
        netPayable: money('net_payable'),
        status: cell(r, 'status').isEmpty ? null : cell(r, 'status'),
        date: _date(cell(r, 'date')),
      ));
    }
    return StatementParseResult(
      rows: rows,
      issues: issues,
      missingFields: [
        for (final f in kStatementFields)
          if (!map.containsKey(f)) f,
      ],
      headerRowIndex: headerIdx,
    );
  }

  static DateTime? _date(String s) {
    if (s.isEmpty) return null;
    final serial = int.tryParse(s);
    if (serial != null && serial >= 20000 && serial <= 80000) {
      return DateTime(1899, 12, 30).add(Duration(days: serial));
    }
    final iso = DateTime.tryParse(s);
    if (iso != null) return iso;
    final m = RegExp(r'^(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4})').firstMatch(s);
    if (m == null) return null;
    final d = int.parse(m.group(1)!);
    final mo = int.parse(m.group(2)!);
    if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
    return DateTime(int.parse(m.group(3)!), mo, d);
  }
}
