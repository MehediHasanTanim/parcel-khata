import 'package:meta/meta.dart';

/// Integer money in poisha (1 BDT = 100 poisha). Never uses floats.
@immutable
class Money implements Comparable<Money> {
  const Money(this.poisha);

  /// Builds from whole taka.
  const Money.taka(int taka) : poisha = taka * 100;

  static const zero = Money(0);

  final int poisha;

  Money operator +(Money o) => Money(poisha + o.poisha);
  Money operator -(Money o) => Money(poisha - o.poisha);
  Money operator -() => Money(-poisha);
  Money operator *(int qty) => Money(poisha * qty);

  bool operator <(Money o) => poisha < o.poisha;
  bool operator <=(Money o) => poisha <= o.poisha;
  bool operator >(Money o) => poisha > o.poisha;
  bool operator >=(Money o) => poisha >= o.poisha;

  bool get isZero => poisha == 0;
  bool get isNegative => poisha < 0;

  /// Percentage in basis points (100 bp = 1%). Rounds half away from zero.
  /// This is the single place percentage rounding happens.
  Money percentBp(int basisPoints) {
    final product = poisha * basisPoints;
    final abs = product.abs();
    final rounded = (abs + 5000) ~/ 10000;
    return Money(product < 0 ? -rounded : rounded);
  }

  /// Parses "1,234.5", "১,২৩৪.৫", "৳1234". Returns null when invalid.
  static Money? tryParse(String input) {
    var s = _toAsciiDigits(input).replaceAll(RegExp(r'[,\s৳]|BDT|Tk', caseSensitive: false), '');
    if (s.isEmpty) return null;
    var negative = false;
    if (s.startsWith('-')) {
      negative = true;
      s = s.substring(1);
    }
    final m = RegExp(r'^(\d+)(?:\.(\d{0,2})\d*)?$').firstMatch(s);
    if (m == null) return null;
    final whole = int.parse(m.group(1)!);
    final frac = (m.group(2) ?? '').padRight(2, '0');
    final total = whole * 100 + int.parse(frac);
    return Money(negative ? -total : total);
  }

  /// Formats as `৳12,450`. Whole taka by default.
  String format({
    bool decimals = false,
    bool indianGrouping = false,
    bool banglaDigits = false,
    bool symbol = true,
  }) {
    final abs = poisha.abs();
    final whole = abs ~/ 100;
    final frac = (abs % 100).toString().padLeft(2, '0');
    // Without decimals, round half up to whole taka.
    final shownWhole = decimals ? whole : (abs + 50) ~/ 100;
    var digits = _group(shownWhole.toString(), indianGrouping);
    if (decimals) digits = '$digits.$frac';
    var out = '${poisha < 0 ? '-' : ''}${symbol ? '৳' : ''}$digits';
    if (banglaDigits) out = _toBanglaDigits(out);
    return out;
  }

  static String _group(String s, bool indian) {
    if (s.length <= 3) return s;
    final last3 = s.substring(s.length - 3);
    var rest = s.substring(0, s.length - 3);
    final size = indian ? 2 : 3;
    final parts = <String>[];
    while (rest.length > size) {
      parts.insert(0, rest.substring(rest.length - size));
      rest = rest.substring(0, rest.length - size);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    return '${parts.join(',')},$last3';
  }

  static const _bn = '০১২৩৪৫৬৭৮৯';

  static String _toBanglaDigits(String s) => s.replaceAllMapped(
      RegExp(r'\d'), (m) => _bn[int.parse(m.group(0)!)]);

  static String _toAsciiDigits(String s) => s.replaceAllMapped(
      RegExp('[০-৯]'), (m) => _bn.indexOf(m.group(0)!).toString());

  @override
  int compareTo(Money other) => poisha.compareTo(other.poisha);

  @override
  bool operator ==(Object other) => other is Money && other.poisha == poisha;

  @override
  int get hashCode => poisha.hashCode;

  @override
  String toString() => 'Money($poisha)';
}
