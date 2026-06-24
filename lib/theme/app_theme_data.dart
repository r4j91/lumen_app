import 'package:flutter/material.dart';

enum AppThemeId { graphite, moonstone, midnight, obsidian, slate }

@immutable
class AppThemeColors {
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color accent;
  final Color navBar;
  final Brightness brightness;

  const AppThemeColors({
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.navBar,
    required this.brightness,
  });

  bool get isDark => brightness == Brightness.dark;

  static const graphite = AppThemeColors(
    background:    Color(0xFF1A1B1E),
    surface:       Color(0xFF242529),
    surfaceVariant: Color(0xFF2C2D33),
    textPrimary:   Color(0xFFF2F3F5),
    textSecondary: Color(0xFF9296A0),
    textTertiary:  Color(0xFF6B6E76),
    accent:        Color(0xFF5FD3DC),
    navBar:        Color(0xFF242529),
    brightness:    Brightness.dark,
  );

  static const moonstone = AppThemeColors(
    background:    Color(0xFFF2F4F7),
    surface:       Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFE8ECF2),
    textPrimary:   Color(0xFF1C2033),
    textSecondary: Color(0xFF52596E),
    textTertiary:  Color(0xFF9097AB),
    accent:        Color(0xFF3B485B),
    navBar:        Color(0xFFFFFFFF),
    brightness:    Brightness.light,
  );

  static const midnight = AppThemeColors(
    background:    Color(0xFF0A0A0F),
    surface:       Color(0xFF12121A),
    surfaceVariant: Color(0xFF1E1E2E),
    textPrimary:   Color(0xFFE8E8F0),
    textSecondary: Color(0xFF7070A0),
    textTertiary:  Color(0xFF4A4A6A),
    accent:        Color(0xFF6C63FF),
    navBar:        Color(0xFF0F0F18),
    brightness:    Brightness.dark,
  );

  static const obsidian = AppThemeColors(
    background:    Color(0xFF0D0D0D),
    surface:       Color(0xFF161616),
    surfaceVariant: Color(0xFF222222),
    textPrimary:   Color(0xFFF0F0F0),
    textSecondary: Color(0xFF888888),
    textTertiary:  Color(0xFF555555),
    accent:        Color(0xFF00D4D4),
    navBar:        Color(0xFF111111),
    brightness:    Brightness.dark,
  );

  static const slate = AppThemeColors(
    background:     Color(0xFF16161A),
    surface:        Color(0xFF1C1C20),
    surfaceVariant: Color(0xFF2C2C32),
    textPrimary:    Color(0xFFF2F2F4),
    textSecondary:  Color(0xFF9A9AA2),
    textTertiary:   Color(0xFF65656D),
    accent:         Color(0xFFE8E8EC),
    navBar:         Color(0xFF16161A),
    brightness:     Brightness.dark,
  );

  static AppThemeColors forId(AppThemeId id) => switch (id) {
    AppThemeId.graphite  => graphite,
    AppThemeId.moonstone => moonstone,
    AppThemeId.midnight  => midnight,
    AppThemeId.obsidian  => obsidian,
    AppThemeId.slate     => slate,
  };
}

extension AppThemeIdMeta on AppThemeId {
  String get displayName => switch (this) {
    AppThemeId.graphite  => 'Graphite',
    AppThemeId.moonstone => 'Moonstone',
    AppThemeId.midnight  => 'Midnight',
    AppThemeId.obsidian  => 'Obsidian',
    AppThemeId.slate     => 'Slate',
  };

  String get subtitle => switch (this) {
    AppThemeId.graphite  => 'Escuro',
    AppThemeId.moonstone => 'Claro',
    AppThemeId.midnight  => 'Escuro premium',
    AppThemeId.obsidian  => 'Preto puro',
    AppThemeId.slate     => 'Monocromático',
  };
}
