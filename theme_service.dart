import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The four theme options the app offers.
enum AppThemeMode { light, dark, system, gradient }

/// A season, used to pick a gradient palette.
enum Season { spring, summer, autumn, winter }

/// What drives [Season] selection: either auto-detected from today's date,
/// or pinned by the user.
enum SeasonOverride { auto, spring, summer, autumn, winter }

class ThemeService extends ChangeNotifier {
  static const _modeKey = 'app_theme_mode';
  static const _seasonKey = 'season_override';

  AppThemeMode _mode = AppThemeMode.system;
  SeasonOverride _seasonOverride = SeasonOverride.auto;

  AppThemeMode get mode => _mode;
  SeasonOverride get seasonOverride => _seasonOverride;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final modeIndex = prefs.getInt(_modeKey);
    final seasonIndex = prefs.getInt(_seasonKey);
    if (modeIndex != null && modeIndex < AppThemeMode.values.length) {
      _mode = AppThemeMode.values[modeIndex];
    }
    if (seasonIndex != null && seasonIndex < SeasonOverride.values.length) {
      _seasonOverride = SeasonOverride.values[seasonIndex];
    }
    notifyListeners();
  }

  Future<void> setMode(AppThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_modeKey, mode.index);
  }

  Future<void> setSeasonOverride(SeasonOverride season) async {
    _seasonOverride = season;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_seasonKey, season.index);
  }

  /// The season currently in effect: the manual override if one is set,
  /// otherwise whatever [detectSeasonFromDate] says about today.
  Season get activeSeason {
    if (_seasonOverride != SeasonOverride.auto) {
      // SeasonOverride.spring/summer/autumn/winter line up 1:1 with Season.
      return Season.values[_seasonOverride.index - 1];
    }
    return detectSeasonFromDate(DateTime.now());
  }

  /// Simple month-based season detection (assumes Northern Hemisphere -
  /// use the manual override in [SeasonOverride] if that doesn't match
  /// where you are).
  static Season detectSeasonFromDate(DateTime date) {
    final month = date.month;
    if (month == 12 || month <= 2) return Season.winter;
    if (month <= 5) return Season.spring;
    if (month <= 8) return Season.summer;
    return Season.autumn;
  }
}
