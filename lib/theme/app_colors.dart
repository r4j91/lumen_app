import 'package:flutter/material.dart';
import '../providers/theme_provider.dart';
import 'app_theme_data.dart';

// Theme-sensitive colors are getters — they always reflect the active theme.
// Semantic colors (priorities, tags) are constants — they never change.
class AppColors {
  AppColors._();

  static AppThemeColors get _t => ThemeProvider.instance.colors;

  static Color get background     => _t.background;
  static Color get surface        => _t.surface;
  static Color get surfaceVariant => _t.surfaceVariant;
  static Color get textPrimary    => _t.textPrimary;
  static Color get textSecondary  => _t.textSecondary;
  static Color get textTertiary   => _t.textTertiary;
  static Color get accent         => _t.accent;
  static Color get navBar         => _t.navBar;

  // Semantic — unchanged across themes
  static const priorityHigh   = Color(0xFFEF5A5F);
  static const priorityMedium = Color(0xFFF5A623);
  static const priorityLow    = Color(0xFF4D9FEC);
  static const tagPurple      = Color(0xFFB18CF5);
  static const tagGreen       = Color(0xFF8FD46B);

  static Color parseHex(String? hex) {
    if (hex == null || hex.isEmpty) return textTertiary;
    final clean = hex.replaceFirst('#', '');
    try {
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return textTertiary;
    }
  }
}
