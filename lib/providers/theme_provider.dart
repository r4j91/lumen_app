import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme_data.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeProvider._();
  static final ThemeProvider instance = ThemeProvider._();

  static const _key = 'selected_theme';

  AppThemeId _id = AppThemeId.graphite;
  AppThemeId get themeId => _id;
  AppThemeColors get colors => AppThemeColors.forId(_id);

  Future<void> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null) {
      final id = AppThemeId.values.where((e) => e.name == saved).firstOrNull;
      if (id != null && id != _id) {
        _id = id;
        // No notifyListeners here — called before the app renders.
      }
    }
  }

  Future<void> setTheme(AppThemeId id) async {
    if (_id == id) return;
    _id = id;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, id.name);
  }
}
