import 'package:flutter/material.dart';

import 'design/sc_metrics.dart';
import 'design/sc_typography.dart';
import 'design/sportcut_tokens.dart';

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
  final typography = brightness == Brightness.dark
      ? SportcutTypography.dark
      : SportcutTypography.light;

  final textTheme = TextTheme(
    displayLarge: typography.display64,
    displayMedium: typography.display44,
    displaySmall: typography.display32,
    headlineLarge: typography.display44,
    headlineMedium: typography.display32,
    headlineSmall: typography.title24,
    titleLarge: typography.title20,
    titleMedium: typography.body16.copyWith(fontWeight: FontWeight.w600),
    titleSmall: typography.sm14.copyWith(fontWeight: FontWeight.w600),
    bodyLarge: typography.body16,
    bodyMedium: typography.body16,
    bodySmall: typography.sm14,
    labelLarge: typography.sm14.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: 0.01,
    ),
    labelMedium: typography.xs12.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: 0.02,
    ),
    labelSmall: typography.micro10,
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
    onError: brightness == Brightness.light ? palette.surface : palette.bg,
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

  // The focus treatment lives on component styles, not `ThemeData.focusColor`:
  // a ring needs a border, and focusColor is only a fill.
  WidgetStateProperty<BorderSide?> focusSide({BorderSide? base}) {
    return WidgetStateProperty.resolveWith<BorderSide?>((states) {
      if (states.contains(WidgetState.focused)) {
        return BorderSide(color: palette.accent, width: 2);
      }
      return base;
    });
  }

  // Keyboard focus is always the ring from `focusSide`; Material's fill tint
  // would paint a second, weaker focus state (FR-SHL-33).
  WidgetStateProperty<Color?> focusOverlay(Color hover) {
    return WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.disabled) ||
          states.contains(WidgetState.focused)) {
        return Colors.transparent;
      }
      if (states.contains(WidgetState.pressed) ||
          states.contains(WidgetState.hovered)) {
        return hover;
      }
      return Colors.transparent;
    });
  }

  final filledStyle = FilledButton.styleFrom(
    foregroundColor: palette.accentOn,
    minimumSize: const Size(0, ScMetrics.button),
    padding: EdgeInsets.symmetric(horizontal: tokens.space4),
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
    side: focusSide(),
  );

  final outlinedStyle = OutlinedButton.styleFrom(
    foregroundColor: palette.fg,
    minimumSize: const Size(0, ScMetrics.button),
    padding: EdgeInsets.symmetric(horizontal: tokens.space4),
    side: BorderSide(color: palette.controlBorder),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(tokens.radiusMd),
    ),
    textStyle: textTheme.labelLarge,
  ).copyWith(
    overlayColor: focusOverlay(palette.surfaceWarm),
    side: focusSide(base: BorderSide(color: palette.controlBorder)),
  );

  final textStyle = TextButton.styleFrom(
    foregroundColor: palette.fg2,
    minimumSize: const Size(0, ScMetrics.button),
    padding: EdgeInsets.symmetric(horizontal: tokens.space3),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(tokens.radiusSm),
    ),
    textStyle: textTheme.labelLarge,
  ).copyWith(
    overlayColor: focusOverlay(palette.surfaceWarm),
    side: focusSide(),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: palette.bg,
    canvasColor: palette.bg,
    fontFamily: 'IBMPlexSans',
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
    materialTapTargetSize: MaterialTapTargetSize.padded,
    hoverColor: palette.surfaceWarm,
    highlightColor: palette.surfaceWarm,
    disabledColor: palette.muted,
    extensions: <ThemeExtension<dynamic>>[palette, tokens, typography],
    appBarTheme: AppBarTheme(
      backgroundColor: palette.surface,
      foregroundColor: palette.fg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      toolbarHeight: ScMetrics.toolbarHeight,
      titleTextStyle: typography.title20,
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
      titleTextStyle: typography.title20,
      contentTextStyle: typography.body16.copyWith(color: palette.fg2),
    ),
    filledButtonTheme: FilledButtonThemeData(style: filledStyle),
    outlinedButtonTheme: OutlinedButtonThemeData(style: outlinedStyle),
    textButtonTheme: TextButtonThemeData(style: textStyle),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll<Color>(palette.fg2),
        overlayColor: focusOverlay(palette.surfaceWarm),
        // The visual square is 36; `tapTargetSize` keeps the hit area at or
        // above the 44 px floor.
        minimumSize: const WidgetStatePropertyAll<Size>(
          Size(ScMetrics.iconButtonVisual, ScMetrics.iconButtonVisual),
        ),
        fixedSize: const WidgetStatePropertyAll<Size>(
          Size(ScMetrics.iconButtonVisual, ScMetrics.iconButtonVisual),
        ),
        padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
          EdgeInsets.all(tokens.space1),
        ),
        iconSize: const WidgetStatePropertyAll<double>(ScMetrics.toolbarIcon),
        tapTargetSize: MaterialTapTargetSize.padded,
        side: focusSide(),
      ),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: palette.surface,
      isDense: true,
      constraints: const BoxConstraints(minHeight: ScMetrics.field),
      contentPadding: EdgeInsets.symmetric(
        horizontal: tokens.space3,
        vertical: tokens.space1,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        borderSide: BorderSide(color: palette.controlBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        borderSide: BorderSide(color: palette.controlBorder),
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
      labelStyle: typography.xs12.copyWith(color: palette.muted),
      floatingLabelStyle: typography.xs12.copyWith(color: palette.accent),
      hintStyle: typography.sm14.copyWith(color: palette.muted),
      helperStyle: typography.xs12.copyWith(color: palette.muted),
      errorStyle: typography.xs12.copyWith(color: palette.danger),
    ),
    dividerTheme: DividerThemeData(
      color: palette.borderSoft,
      thickness: 1,
      space: 1,
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(
        horizontal: tokens.space3,
        vertical: tokens.space1,
      ),
      minLeadingWidth: 0,
      horizontalTitleGap: tokens.space2,
      iconColor: palette.fg2,
      textColor: palette.fg,
      titleTextStyle: textTheme.titleSmall,
      subtitleTextStyle: typography.sm14.copyWith(color: palette.muted),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusMd),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: palette.surface,
      contentTextStyle: typography.sm14.copyWith(color: palette.fg),
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
      textStyle: typography.xs12.copyWith(
        color: palette.bg,
        fontWeight: FontWeight.w500,
      ),
      waitDuration: const Duration(milliseconds: 400),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: palette.accent,
      inactiveTrackColor: palette.surfaceWarm,
      thumbColor: palette.accent,
      // Material's slider paints its focus state as a fill; the studio's
      // controls draw a ring instead, so this legacy slider keeps no tint.
      overlayColor: Colors.transparent,
      trackHeight: 3,
      showValueIndicator: ShowValueIndicator.never,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: palette.accent,
      linearTrackColor: palette.surfaceWarm,
      circularTrackColor: palette.surfaceWarm,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.disabled)) {
          return palette.muted;
        }
        return states.contains(WidgetState.selected)
            ? palette.accentOn
            : palette.fg2;
      }),
      trackColor: WidgetStateProperty.resolveWith<Color?>((states) {
        return states.contains(WidgetState.selected)
            ? palette.accent
            : palette.surfaceWarm;
      }),
      trackOutlineColor: WidgetStatePropertyAll<Color>(
        palette.controlBorder,
      ),
      materialTapTargetSize: MaterialTapTargetSize.padded,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll<Size>(
          Size(0, ScMetrics.buttonCompact),
        ),
        padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
          EdgeInsets.symmetric(horizontal: tokens.space3),
        ),
        backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
          return states.contains(WidgetState.selected)
              ? palette.surfaceWarm
              : Colors.transparent;
        }),
        foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
          return states.contains(WidgetState.selected)
              ? palette.fg
              : palette.fg2;
        }),
        overlayColor: focusOverlay(palette.surfaceWarm),
        side: WidgetStatePropertyAll<BorderSide>(
          BorderSide(color: palette.controlBorder),
        ),
        shape: WidgetStatePropertyAll<OutlinedBorder>(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radiusSm),
          ),
        ),
        textStyle: WidgetStatePropertyAll<TextStyle>(
          typography.xs12.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    ),
    bannerTheme: MaterialBannerThemeData(
      backgroundColor: palette.surface,
      surfaceTintColor: Colors.transparent,
      contentTextStyle: typography.sm14.copyWith(color: palette.fg),
      elevation: 0,
      padding: EdgeInsets.all(tokens.space3),
      dividerColor: palette.borderSoft,
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith<Color?>((states) {
        return states.contains(WidgetState.selected)
            ? palette.accent
            : Colors.transparent;
      }),
      checkColor: WidgetStatePropertyAll<Color>(palette.accentOn),
      overlayColor: focusOverlay(palette.surfaceWarm),
      side: BorderSide(color: palette.controlBorder),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: palette.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      textStyle: typography.sm14,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusMd),
        side: BorderSide(color: palette.borderSoft),
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: palette.accent,
      selectionColor: palette.accent.withValues(alpha: 0.19),
      selectionHandleColor: palette.accent,
    ),
  );
}
