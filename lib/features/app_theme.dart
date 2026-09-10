import 'package:flutter/material.dart';

/// Client asked for a choice between two theme directions:
///   "Theme red and white, red and white blue ad white and blue and black"
/// Interpreted as two selectable themes:
///   1) Red & White
///   2) Blue, White & Black
/// Exposed as a simple enum so Settings can toggle between them; both use
/// Material 3 with high-contrast text for outdoor/field readability.
enum AppThemeChoice { redWhite, blueBlackWhite }

class AppTheme {
  static ThemeData build(AppThemeChoice choice) {
    switch (choice) {
      case AppThemeChoice.redWhite:
        return _themeFrom(
          seed: const Color(0xFFC62828), // strong red
          surface: Colors.white,
          brightness: Brightness.light,
        );
      case AppThemeChoice.blueBlackWhite:
        return _themeFrom(
          seed: const Color(0xFF1565C0), // strong blue
          surface: const Color(0xFF0D1117), // near-black
          brightness: Brightness.dark,
        );
    }
  }

  static ThemeData _themeFrom({
    required Color seed,
    required Color surface,
    required Brightness brightness,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: brightness == Brightness.light ? Colors.white : surface,
      appBarTheme: AppBarTheme(
        backgroundColor: seed,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: const CardThemeData(
        elevation: 1,
        margin: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      ),
      navigationRailTheme: NavigationRailThemeData(
        selectedIconTheme: IconThemeData(color: seed),
        indicatorColor: seed.withValues(alpha: 0.15),
      ),
    );
  }
}
