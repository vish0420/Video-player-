import 'package:flutter/material.dart';

/// Base Material theme definitions. "Gradient" mode (see [ThemeService])
/// isn't a separate ThemeData - it layers a season gradient on top of the
/// dark theme's scaffold background so text and icons stay readable.
class AppTheme {
  static const _seed = Color(0xFF3D6A8A);

  static ThemeData light() {
    return ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      colorSchemeSeed: _seed,
      scaffoldBackgroundColor: const Color(0xFFF6F5F2),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorSchemeSeed: _seed,
      scaffoldBackgroundColor: const Color(0xFF101114),
    );
  }
}
