import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_khata/app/theme.dart';
import 'package:parcel_khata/features/settings/domain/shop_settings.dart';
import 'package:parcel_khata/shared/status_chip.dart';

Widget _host(ThemeData theme) => MaterialApp(
      theme: theme,
      home: const Scaffold(
        body: StatusChip(label: 'Delivered', icon: Icons.check, tone: StatusTone.success),
      ),
    );

BoxDecoration _decoration(WidgetTester t) {
  final box = t.widget<Container>(find
      .descendant(of: find.byType(StatusChip), matching: find.byType(Container))
      .first);
  return box.decoration! as BoxDecoration;
}

void main() {
  test('high contrast defaults off and survives a JSON round trip', () {
    expect(const ShopSettings().highContrast, isFalse);
    final s = ShopSettings.decode(const ShopSettings(highContrast: true).encode());
    expect(s.highContrast, isTrue);
    expect(ShopSettings.decode('{}').highContrast, isFalse);
  });

  testWidgets('standard chips are tinted with a hairline border', (t) async {
    await t.pumpWidget(_host(AppTheme.light()));
    final border = _decoration(t).border! as Border;
    expect(border.top.width, 1);
  });

  testWidgets('high contrast chips use a 2px border and a solid ground', (t) async {
    await t.pumpWidget(_host(AppTheme.light(highContrast: true)));
    final d = _decoration(t);
    expect((d.border! as Border).top.width, 2);
    expect(d.color!.a, 1);
  });

  test('high contrast status colours are darker than standard on light', () {
    final std = AppTheme.light().extension<StatusColors>()!;
    final hc = AppTheme.light(highContrast: true).extension<StatusColors>()!;
    expect(hc.warning.computeLuminance(), lessThan(std.warning.computeLuminance()));
    expect(hc.danger.computeLuminance(), lessThan(std.danger.computeLuminance()));
  });
}
