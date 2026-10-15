import 'package:meta/meta.dart';

enum PeriodPreset { today, yesterday, last7Days, thisMonth, lastMonth, custom }

@immutable
class DatePeriod {
  const DatePeriod(this.from, this.to);

  /// Inclusive start, exclusive end.
  final DateTime from;
  final DateTime to;

  int get days => to.difference(from).inDays;

  bool contains(DateTime t) => !t.isBefore(from) && t.isBefore(to);

  static DatePeriod resolve(PeriodPreset p, DateTime now, {DatePeriod? custom}) {
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    switch (p) {
      case PeriodPreset.today:
        return DatePeriod(today, tomorrow);
      case PeriodPreset.yesterday:
        return DatePeriod(today.subtract(const Duration(days: 1)), today);
      case PeriodPreset.last7Days:
        // Today plus the six days before it.
        return DatePeriod(today.subtract(const Duration(days: 6)), tomorrow);
      case PeriodPreset.thisMonth:
        return DatePeriod(DateTime(now.year, now.month), DateTime(now.year, now.month + 1));
      case PeriodPreset.lastMonth:
        return DatePeriod(DateTime(now.year, now.month - 1), DateTime(now.year, now.month));
      case PeriodPreset.custom:
        return custom ?? DatePeriod(today, tomorrow);
    }
  }

  @override
  bool operator ==(Object other) =>
      other is DatePeriod && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}

/// Rates shown on the dashboard and reports (feature spec F9).
abstract final class ReportMath {
  /// delivered / (delivered + failed/returned); null when nothing resolved.
  static double? deliverySuccessRate({required int delivered, required int failed}) {
    final resolved = delivered + failed;
    return resolved == 0 ? null : delivered / resolved;
  }

  /// returned or failed / dispatched; null when nothing was dispatched.
  static double? returnRate({required int returned, required int dispatched}) =>
      dispatched == 0 ? null : returned / dispatched;

  /// Margin in basis points rounded half away from zero; null if no revenue.
  static int? marginBp({required int profit, required int revenue}) {
    if (revenue == 0) return null;
    final n = profit * 10000;
    final q = (n.abs() * 2 + revenue.abs()) ~/ (2 * revenue.abs());
    return (n < 0) == (revenue < 0) ? q : -q;
  }

  static int? averagePerOrder({required int total, required int count}) =>
      count == 0 ? null : (total / count).round();
}
