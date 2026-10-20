import 'package:flutter/material.dart';

/// Status colors are always paired with an icon and text, never color alone.
@immutable
class StatusColors extends ThemeExtension<StatusColors> {
  const StatusColors({
    required this.success,
    required this.warning,
    required this.danger,
    required this.neutral,
    this.info = const Color(0xFF416180),
  });

  final Color success;
  final Color warning;
  final Color danger;
  final Color neutral;

  /// Confirmed / in-progress states (steel accent).
  final Color info;

  @override
  StatusColors copyWith(
          {Color? success, Color? warning, Color? danger, Color? neutral, Color? info}) =>
      StatusColors(
        success: success ?? this.success,
        warning: warning ?? this.warning,
        danger: danger ?? this.danger,
        neutral: neutral ?? this.neutral,
        info: info ?? this.info,
      );

  @override
  StatusColors lerp(StatusColors? other, double t) {
    if (other == null) return this;
    return StatusColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      neutral: Color.lerp(neutral, other.neutral, t)!,
      info: Color.lerp(info, other.info, t)!,
    );
  }
}

/// "Industry" design system (Claude Design): steel-blue accent on a light
/// technical ground, square corners, hairline borders, Barlow type.
abstract final class AppTheme {
  static const minTouchTarget = 48.0;
  static const spacing = 8.0;

  // Light tokens.
  static const _bg = Color(0xFFF2F2F3);
  static const _text = Color(0xFF1D1F20);
  static const _accent = Color(0xFF416180); // accent-700
  static const _accentLo = Color(0xFFD6EBFF); // accent-200
  static const _surface = Color(0xFFE9E9EA);

  // Dark tokens.
  static const _bgDark = Color(0xFF16191B);
  static const _textDark = Color(0xFFE9EAEB);
  static const _accentDark = Color(0xFF94BCE3); // accent-400
  static const _surfaceDark = Color(0xFF202427);

  static const fontBody = 'Barlow';
  static const fontHeading = 'BarlowCondensed';
  static const _bnFallback = ['NotoSansBengali'];

  static ThemeData light() => _build(
        Brightness.light,
        const StatusColors(
          success: Color(0xFF1B7F3B),
          warning: Color(0xFFB26A00),
          danger: Color(0xFFC62828),
          neutral: Color(0xFF5F6368),
          info: Color(0xFF416180),
        ),
      );

  static ThemeData dark() => _build(
        Brightness.dark,
        const StatusColors(
          success: Color(0xFF66D18A),
          warning: Color(0xFFFFB74D),
          danger: Color(0xFFFF8A80),
          neutral: Color(0xFFB0B4BA),
          info: Color(0xFF94BCE3),
        ),
      );

  static ThemeData _build(Brightness b, StatusColors status) {
    final dark = b == Brightness.dark;
    final text = dark ? _textDark : _text;
    final bg = dark ? _bgDark : _bg;
    final accent = dark ? _accentDark : _accent;
    final divider = text.withValues(alpha: 0.16);
    final scheme = ColorScheme.fromSeed(
      seedColor: _accent,
      brightness: b,
    ).copyWith(
      primary: accent,
      onPrimary: dark ? const Color(0xFF1D2D3D) : _bg,
      primaryContainer: dark ? const Color(0xFF2C455D) : _accentLo,
      onPrimaryContainer: dark ? const Color(0xFFD6EBFF) : const Color(0xFF1D2D3D),
      secondary: accent,
      secondaryContainer: dark ? const Color(0xFF2C455D) : const Color(0xFFDBE5EF),
      onSecondaryContainer: dark ? const Color(0xFFD6EBFF) : const Color(0xFF1D2D3D),
      surface: bg,
      onSurface: text,
      surfaceContainerLowest: bg,
      surfaceContainerLow: bg,
      surfaceContainer: dark ? _surfaceDark : _surface,
      surfaceContainerHigh: dark ? _surfaceDark : _surface,
      surfaceContainerHighest: dark ? _surfaceDark : _surface,
      outline: text.withValues(alpha: 0.55),
      outlineVariant: divider,
      error: status.danger,
      errorContainer: Color.alphaBlend(status.danger.withValues(alpha: 0.12), bg),
      onErrorContainer: dark ? const Color(0xFFFFB4AB) : const Color(0xFF8E1515),
    );

    TextStyle heading(double size, {double? height}) => TextStyle(
          fontFamily: fontHeading,
          fontFamilyFallback: _bnFallback,
          fontWeight: FontWeight.w600,
          fontSize: size,
          height: height,
        );

    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: fontBody,
      fontFamilyFallback: _bnFallback,
    );
    final t = base.textTheme.apply(bodyColor: text, displayColor: text);
    final textTheme = t.copyWith(
      displayLarge: t.displayLarge?.merge(heading(40)),
      displayMedium: t.displayMedium?.merge(heading(34)),
      displaySmall: t.displaySmall?.merge(heading(30)),
      headlineLarge: t.headlineLarge?.merge(heading(28)),
      headlineMedium: t.headlineMedium?.merge(heading(26)),
      headlineSmall: t.headlineSmall?.merge(heading(24)),
      titleLarge: t.titleLarge?.merge(heading(22)),
      titleMedium: t.titleMedium?.merge(heading(18)),
      titleSmall: t.titleSmall?.merge(heading(16)),
      labelLarge: t.labelLarge?.merge(heading(17)),
      bodyLarge: t.bodyLarge?.copyWith(fontSize: 16),
      bodyMedium: t.bodyMedium?.copyWith(fontSize: 16),
      bodySmall: t.bodySmall?.copyWith(fontSize: 13),
    );

    const square = RoundedRectangleBorder();
    final hairline = BorderSide(color: divider);
    final inkLine = BorderSide(color: text);
    const minSize = Size(minTouchTarget, minTouchTarget);

    return base.copyWith(
      extensions: [status],
      textTheme: textTheme,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      dividerColor: divider,
      dividerTheme: DividerThemeData(color: divider, space: 1, thickness: 1),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      splashFactory: InkRipple.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: text,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        toolbarHeight: 56,
        titleTextStyle: heading(22).copyWith(color: text),
        shape: Border(bottom: hairline),
      ),
      cardTheme: CardThemeData(
        color: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(side: hairline),
      ),
      listTileTheme: ListTileThemeData(
        shape: const Border(),
        iconColor: text,
        minVerticalPadding: 8,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: minSize,
          shape: square,
          backgroundColor: accent,
          foregroundColor: scheme.onPrimary,
          textStyle: heading(17),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: minSize,
          shape: square,
          elevation: 0,
          backgroundColor: accent,
          foregroundColor: scheme.onPrimary,
          textStyle: heading(17),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: minSize,
          shape: square,
          side: inkLine,
          foregroundColor: text,
          textStyle: heading(17),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: minSize,
          shape: square,
          foregroundColor: accent,
          textStyle: heading(17),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: minSize,
          shape: square,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: square,
        backgroundColor: accent,
        foregroundColor: scheme.onPrimary,
        elevation: 3,
        extendedTextStyle: heading(17),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: hairline.copyWith(color: text.withValues(alpha: 0.55)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: hairline.copyWith(color: text.withValues(alpha: 0.55)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: status.danger, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: status.danger, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(side: hairline),
        side: hairline,
        backgroundColor: Colors.transparent,
        selectedColor: scheme.primaryContainer,
        labelStyle: TextStyle(fontFamily: fontBody, fontWeight: FontWeight.w500, color: text),
        showCheckmark: true,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          shape: square,
          side: inkLine,
          minimumSize: minSize,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: Colors.transparent,
        indicatorShape: square,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontFamily: fontBody,
            fontSize: 13,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? accent : text,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(side: inkLine),
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        titleTextStyle: heading(22).copyWith(color: text),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        shape: RoundedRectangleBorder(side: hairline),
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
      ),
      snackBarTheme: SnackBarThemeData(
        shape: square,
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? _surfaceDark : _text,
        contentTextStyle: TextStyle(
          fontFamily: fontBody,
          fontFamilyFallback: _bnFallback,
          color: dark ? _textDark : _bg,
        ),
        actionTextColor: dark ? _accentDark : _accentLo,
      ),
      tabBarTheme: TabBarThemeData(
        labelStyle: heading(17),
        unselectedLabelStyle: heading(17),
        indicatorColor: accent,
        labelColor: accent,
        unselectedLabelColor: text,
        dividerColor: divider,
      ),
      switchTheme: SwitchThemeData(
        trackOutlineColor: WidgetStatePropertyAll(text.withValues(alpha: 0.55)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: accent),
      focusColor: accent.withValues(alpha: 0.2),
    );
  }
}
