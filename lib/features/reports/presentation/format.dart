import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/features/reports/application/dashboard_service.dart';

String formatRate(num? v) => v == null ? '—' : '${(v * 100).toStringAsFixed(0)}%';

String formatBp(int? bp) => bp == null ? '—' : '${(bp / 100).toStringAsFixed(1)}%';

String formatMoneyOrDash(num? v) => v == null ? '—' : Money(v.round()).format();

/// Display string for a tile / drill-down header value of [m].
String formatMeasure(Measure m, num? v) => switch (m) {
      Measure.count => v == null ? '0' : '${v.round()}',
      Measure.outstanding ||
      Measure.codExpected ||
      Measure.revenue ||
      Measure.profitFinal ||
      Measure.profitProvisional ||
      Measure.avgProfit =>
        formatMoneyOrDash(v),
      Measure.margin => formatBp(v?.round()),
      Measure.deliverySuccess || Measure.returnRate => formatRate(v),
    };
