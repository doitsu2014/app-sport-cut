import 'package:flutter/material.dart';

/// Court green, used as the seed for both themes.
const sportcutSeedColor = Color(0xFF157A4A);

/// Material 3 theme for the application.
ThemeData buildSportcutTheme(Brightness brightness) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: sportcutSeedColor,
    brightness: brightness,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      centerTitle: false,
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
  );
}
