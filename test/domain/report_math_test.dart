import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_khata/features/reports/domain/report_math.dart';

void main() {
  group('DatePeriod presets', () {
    final now = DateTime(2026, 10, 15, 14, 30);

    test('today / yesterday', () {
      final t = DatePeriod.resolve(PeriodPreset.today, now);
      expect(t.from, DateTime(2026, 10, 15));
      expect(t.to, DateTime(2026, 10, 16));
      final y = DatePeriod.resolve(PeriodPreset.yesterday, now);
      expect(y.from, DateTime(2026, 10, 14));
      expect(y.to, DateTime(2026, 10, 15));
    });

    test('last 7 days is 7 calendar days including today', () {
      final p = DatePeriod.resolve(PeriodPreset.last7Days, now);
      expect(p.days, 7);
      expect(p.from, DateTime(2026, 10, 9));
      expect(p.contains(DateTime(2026, 10, 15, 23, 59)), isTrue);
      expect(p.contains(DateTime(2026, 10, 8, 23, 59)), isFalse);
    });

    test('this month / last month incl. year wrap', () {
      final m = DatePeriod.resolve(PeriodPreset.thisMonth, now);
      expect(m.from, DateTime(2026, 10));
      expect(m.to, DateTime(2026, 11));
      final jan = DateTime(2026, 1, 20);
      final last = DatePeriod.resolve(PeriodPreset.lastMonth, jan);
      expect(last.from, DateTime(2025, 12));
      expect(last.to, DateTime(2026, 1));
      final dec = DatePeriod.resolve(PeriodPreset.thisMonth, DateTime(2026, 12, 5));
      expect(dec.to, DateTime(2027, 1));
    });

    test('custom passes through', () {
      final c = DatePeriod(DateTime(2026, 9), DateTime(2026, 9, 10));
      expect(DatePeriod.resolve(PeriodPreset.custom, now, custom: c), c);
    });
  });

  group('ReportMath', () {
    test('delivery success and return rate', () {
      expect(ReportMath.deliverySuccessRate(delivered: 8, failed: 2), 0.8);
      expect(ReportMath.deliverySuccessRate(delivered: 0, failed: 0), isNull);
      expect(ReportMath.returnRate(returned: 1, dispatched: 4), 0.25);
      expect(ReportMath.returnRate(returned: 0, dispatched: 0), isNull);
    });

    test('margin bp rounds half away from zero, handles loss and zero', () {
      expect(ReportMath.marginBp(profit: 400, revenue: 1000), 4000);
      expect(ReportMath.marginBp(profit: -100, revenue: 1000), -1000);
      expect(ReportMath.marginBp(profit: 1, revenue: 3), 3333);
      expect(ReportMath.marginBp(profit: 5, revenue: 0), isNull);
    });

    test('average per order', () {
      expect(ReportMath.averagePerOrder(total: 1000, count: 3), 333);
      expect(ReportMath.averagePerOrder(total: 1000, count: 0), isNull);
    });
  });
}
