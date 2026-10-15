import 'package:flutter/material.dart';

/// Status colors are always paired with an icon and text, never color alone.
@immutable
class StatusColors extends ThemeExtension<StatusColors> {
  const StatusColors({
    required this.success,
    required this.warning,
    required this.danger,
    required this.neutral,
  });

  final Color success;
  final Color warning;
  final Color danger;
  final Color neutral;

  @override
  StatusColors copyWith({Color? success, Color? warning, Color? danger, Color? neutral}) =>
      StatusColors(
        success: success ?? this.success,
        warning: warning ?? this.warning,
        danger: danger ?? this.danger,
        neutral: neutral ?? this.neutral,
      );

  @override
  StatusColors lerp(StatusColors? other, double t) {
    if (other == null) return this;
    return StatusColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      neutral: Color.lerp(neutral, other.neutral, t)!,
    );
  }
}

abstract final class AppTheme {
  static const _seed = Color(0xFF1B7F5C);
  static const minTouchTarget = 48.0;
  static const spacing = 8.0;

  static ThemeData light() => _build(Brightness.light, const StatusColors(
        success: Color(0xFF1B7F3B),
        warning: Color(0xFFB26A00),
        danger: Color(0xFFC62828),
        neutral: Color(0xFF5F6368),
      ));

  static ThemeData dark() => _build(Brightness.dark, const StatusColors(
        success: Color(0xFF66D18A),
        warning: Color(0xFFFFB74D),
        danger: Color(0xFFFF8A80),
        neutral: Color(0xFFB0B4BA),
      ));

  static ThemeData _build(Brightness b, StatusColors status) {
    final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: b);
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);
    return base.copyWith(
      extensions: [status],
      textTheme: base.textTheme.copyWith(
        bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 16),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: 16),
      ),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size(minTouchTarget, minTouchTarget)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: const Size(minTouchTarget, minTouchTarget)),
      ),
      inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
    );
  }
}
