import 'package:flutter/material.dart';

import 'theme_service.dart';

/// Named gradient palettes for each season, used when the app is in
/// "gradient" theme mode.
class SeasonGradients {
  static LinearGradient gradientFor(Season season) {
    switch (season) {
      case Season.spring:
        return const LinearGradient(
          colors: [Color(0xFF6FBF8B), Color(0xFFEFA9C4), Color(0xFFFCEBC5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case Season.summer:
        return const LinearGradient(
          colors: [Color(0xFF1E88A8), Color(0xFFF2B134), Color(0xFFED6A5A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case Season.autumn:
        return const LinearGradient(
          colors: [Color(0xFF5E3A28), Color(0xFFB5541D), Color(0xFFE0A339)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case Season.winter:
        return const LinearGradient(
          colors: [Color(0xFF0B1E33), Color(0xFF35577A), Color(0xFF9AC0D9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }
}
