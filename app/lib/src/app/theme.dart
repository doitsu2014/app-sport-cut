import 'dart:ui' show FontFeature, FontVariation;

import 'package:flutter/material.dart';

import 'design/sportcut_tokens.dart';

/// Court green. Kept as the brand color for callers that need one value.
const sportcutSeedColor = Color(0xFF0E6E45);

const String _displayFamily = 'Archivo';
const String _bodyFamily = 'IBMPlexSans';
const String _monoFamily = 'IBMPlexMono';

const List<FontFeature> _tabularFigures = <FontFeature>[
  FontFeature.tabularFigures(),
];

/// The Sportcut theme for one system appearance.
///
/// The palette is explicit rather than a single seed: the light theme is cool
/// chalk, the dark theme is a graphite editing booth, and both share the same
/// court-green signal, type scale, shape, and motion tokens.
ThemeData buildSportcutTheme(Brightness brightness) {
  final palette = brightness == Brightness.dark
      ? SportcutPalette.dark
      : SportcutPalette.light;
  final tokens = brightness == Brightness.dark
      ? SportcutTokens.dark
      : SportcutTokens.light;

  TextStyle display(
    double size,
    double height,
    FontWeight weight, {
    double tracking = -0.025,
  }) {
    return TextStyle(
      fontFamily: _displayFamily,
      fontSize: size,
      height: height,
      fontWeight: weight,
      letterSpacing: size * tracking,
      fontFeatures: _tabularFigures,
      fontVariations: <FontVariation>[
        FontVariation('wght', weight.value.toDouble()),
      ],
      color: palette.fg,
    );
  }

  TextStyle body(
    double size,
    double height,
    FontWeight weight, {
    double letterSpacing = 0,
  }) {
    return TextStyle(
      fontFamily: _bodyFamily,
      fontSize: size,
      height: height,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      fontVariations: <FontVariation>[
        FontVariation('wght', weight.value.toDouble()),
      ],
      color: palette.fg,
    );
  }

  TextStyle mono(
    double size,
    double height,
    FontWeight weight, {
    double letterSpacing = 0,
  }) {
    return TextStyle(
      fontFamily: _monoFamily,
      fontSize: size,
      height: height,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      fontFeatures: _tabularFigures,
      color: palette.fg,
    );
  }

  final textTheme = TextTheme(
    displayLarge: display(64, 1.0, FontWeight.w700, tracking: -0.035),
    displayMedium: display(44, 1.06, FontWeight.w700, tracking: -0.03),
    displaySmall: display(32, 1.12, FontWeight.w700),
    headlineLarge: display(44, 1.06, FontWeight.w700, tracking: -0.03),
    headlineMedium: display(32, 1.12, FontWeight.w700),
    headlineSmall: display(24, 1.2, FontWeight.w600),
    titleLarge: display(20, 1.2, FontWeight.w700, tracking: -0.02),
    titleMedium: body(16, 1.4, FontWeight.w600),
    titleSmall: body(14, 1.4, FontWeight.w600),
    bodyLarge: body(16, 1.55, FontWeight.w400),
    bodyMedium: body(16, 1.55, FontWeight.w400),
    bodySmall: body(14, 1.45, FontWeight.w400),
    labelLarge: body(14, 1.2, FontWeight.w600, letterSpacing: 0.01),
    labelMedium: body(12, 1.3, FontWeight.w600, letterSpacing: 0.02),
    labelSmall: mono(10, 1.35, FontWeight.w500, letterSpacing: 0.08),
  );

  final scheme = ColorScheme.fromSeed(
    seedColor: palette.accent,
    brightness: brightness,
  ).copyWith(
    primary: palette.accent,
    onPrimary: palette.accentOn,
    primaryContainer: palette.accent,
    onPrimaryContainer: palette.accentOn,
    secondary: palette.fg2,
    onSecondary: palette.bg,
    secondaryContainer: palette.surfaceWarm,
    onSecondaryContainer: palette.fg,
    tertiary: palette.accent,
    onTertiary: palette.accentOn,
    error: palette.danger,
    onError: brightness == Brightness.light ? Colors.white : palette.bg,
    surface: palette.surface,
    onSurface: palette.fg,
    onSurfaceVariant: palette.fg2,
    outline: palette.border,
    outlineVariant: palette.borderSoft,
    surfaceTint: Colors.transparent,
    surfaceContainerLowest: palette.bg,
    surfaceContainerLow: palette.surface,
    surfaceContainer: palette.surfaceWarm,
    surfaceContainerHigh: palette.surfaceWarm,
    surfaceContainerHighest: palette.surfaceWarm,
    inverseSurface: palette.fg,
    onInverseSurface: palette.bg,
    inversePrimary: palette.accent,
  );

  final filledStyle = FilledButton.styleFrom(
    foregroundColor: palette.accentOn,
    minimumSize: const Size(0, 40),
    padding: const EdgeInsets.symmetric(horizontal: 16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(tokens.radiusMd),
    ),
    textStyle: textTheme.labelLarge,
    elevation: 0,
  ).copyWith(
    backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.disabled)) {
        return palette.borderSoft;
      }
      if (states.contains(WidgetState.pressed)) {
        return palette.accentActive;
      }
      if (states.contains(WidgetState.hovered)) {
        return palette.accentHover;
      }
      return palette.accent;
    }),
    foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.disabled)) {
        return palette.muted;
      }
      return palette.accentOn;
    }),
    overlayColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
  );

  final outlinedStyle = OutlinedButton.styleFrom(
    foregroundColor: palette.fg,
    minimumSize: const Size(0, 40),
    padding: const EdgeInsets.symmetric(horizontal: 16),
    side: BorderSide(color: palette.border),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(tokens.radiusMd),
    ),
    textStyle: textTheme.labelLarge,
  ).copyWith(
    overlayColor: WidgetStatePropertyAll<Color>(palette.surfaceWarm),
  );

  final textStyle = TextButton.styleFrom(
    foregroundColor: palette.fg2,
    minimumSize: const Size(0, 36),
    padding: const EdgeInsets.symmetric(horizontal: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(tokens.radiusSm),
    ),
    textStyle: textTheme.labelLarge,
  ).copyWith(
    overlayColor: WidgetStatePropertyAll<Color>(palette.surfaceWarm),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: palette.bg,
    canvasColor: palette.bg,
    fontFamily: _bodyFamily,
    textTheme: textTheme,
    primaryTextTheme: textTheme.apply(
      displayColor: palette.accentOn,
      bodyColor: palette.accentOn,
    ),
    iconTheme: IconThemeData(color: palette.fg2, size: 20),
    primaryIconTheme: IconThemeData(color: palette.accentOn, size: 20),
    dividerColor: palette.borderSoft,
    splashFactory: NoSplash.splashFactory,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    hoverColor: palette.surfaceWarm,
    highlightColor: palette.surfaceWarm,
    focusColor: palette.accent.withAlpha(30),
    disabledColor: palette.muted,
    extensions: <ThemeExtension<dynamic>>[tokens],
    appBarTheme: AppBarTheme(
      backgroundColor: palette.surface,
      foregroundColor: palette.fg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      toolbarHeight: tokens.chromeHeight,
      titleTextStyle: display(18, 1.2, FontWeight.w700),
      iconTheme: IconThemeData(color: palette.fg2, size: 20),
    ),
    cardTheme: CardThemeData(
      color: palette.surface,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusMd),
        side: BorderSide(color: palette.borderSoft),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: palette.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusLg),
        side: BorderSide(color: palette.borderSoft),
      ),
      titleTextStyle: display(18, 1.2, FontWeight.w700),
      contentTextStyle: body(16, 1.55, FontWeight.w400).copyWith(
        color: palette.fg2,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(style: filledStyle),
    outlinedButtonTheme: OutlinedButtonThemeData(style: outlinedStyle),
    textButtonTheme: TextButtonThemeData(style: textStyle),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll<Color>(palette.fg2),
        overlayColor: WidgetStatePropertyAll<Color>(palette.surfaceWarm),
        minimumSize: const WidgetStatePropertyAll<Size>(Size(32, 32)),
      ),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: palette.surface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        borderSide: BorderSide(color: palette.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        borderSide: BorderSide(color: palette.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        borderSide: BorderSide(color: palette.accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        borderSide: BorderSide(color: palette.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        borderSide: BorderSide(color: palette.danger, width: 1.5),
      ),
      labelStyle: textTheme.labelMedium?.copyWith(color: palette.muted),
      floatingLabelStyle: textTheme.labelMedium?.copyWith(
        color: palette.accent,
      ),
      hintStyle: textTheme.bodySmall?.copyWith(color: palette.muted),
      helperStyle: textTheme.bodySmall?.copyWith(color: palette.muted),
      errorStyle: textTheme.bodySmall?.copyWith(color: palette.danger),
    ),
    dividerTheme: DividerThemeData(
      color: palette.borderSoft,
      thickness: 1,
      space: 1,
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      minLeadingWidth: 0,
      horizontalTitleGap: 8,
      iconColor: palette.fg2,
      textColor: palette.fg,
      titleTextStyle: textTheme.titleSmall,
      subtitleTextStyle: textTheme.bodySmall?.copyWith(color: palette.muted),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusMd),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: palette.surface,
      contentTextStyle: body(13, 1.4, FontWeight.w400).copyWith(
        color: palette.fg,
      ),
      actionTextColor: palette.accent,
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusMd),
        side: BorderSide(color: palette.border),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: palette.fg,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
      ),
      textStyle: body(11, 1.3, FontWeight.w500).copyWith(color: palette.bg),
      waitDuration: const Duration(milliseconds: 400),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: palette.accent,
      inactiveTrackColor: palette.surfaceWarm,
      thumbColor: palette.accent,
      overlayColor: palette.accent.withAlpha(31),
      trackHeight: 3,
      showValueIndicator: ShowValueIndicator.never,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: palette.accent,
      linearTrackColor: palette.surfaceWarm,
      circularTrackColor: palette.surfaceWarm,
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith<Color?>((states) {
        return states.contains(WidgetState.selected)
            ? palette.accent
            : Colors.transparent;
      }),
      checkColor: WidgetStatePropertyAll<Color>(palette.accentOn),
      side: BorderSide(color: palette.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: palette.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      textStyle: textTheme.bodySmall,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusMd),
        side: BorderSide(color: palette.borderSoft),
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: palette.accent,
      selectionColor: palette.accent.withAlpha(48),
      selectionHandleColor: palette.accent,
    ),
  );
}