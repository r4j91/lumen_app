import 'package:flutter/material.dart';
import 'app_theme_data.dart';

class AppTheme {
  AppTheme._();

  static ThemeData buildFrom(AppThemeColors c) {
    return ThemeData(
      useMaterial3: true,
      brightness: c.brightness,
      scaffoldBackgroundColor: c.background,
      colorScheme: ColorScheme(
        brightness: c.brightness,
        primary: c.accent,
        onPrimary: c.brightness == Brightness.dark ? const Color(0xFF0A0A0A) : Colors.white,
        secondary: c.accent,
        onSecondary: c.brightness == Brightness.dark ? const Color(0xFF0A0A0A) : Colors.white,
        error: const Color(0xFFEF5A5F),
        onError: Colors.white,
        surface: c.surface,
        onSurface: c.textPrimary,
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(fontSize: 38, fontWeight: FontWeight.w800, color: c.textPrimary, letterSpacing: -1.0, height: 1.1),
        headlineLarge: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: c.textPrimary, letterSpacing: -0.5, height: 1.15),
        headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: c.textPrimary, letterSpacing: -0.3),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.textPrimary, letterSpacing: -0.2),
        titleMedium: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: c.textPrimary),
        titleSmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: c.textPrimary, height: 1.5),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: c.textSecondary, height: 1.5),
        bodySmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: c.textSecondary),
        labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: c.textSecondary),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.textTertiary, letterSpacing: 0.2),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: c.textTertiary, letterSpacing: 0.3),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        hintStyle: TextStyle(color: c.textTertiary, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.accent, width: 1.5)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: c.brightness == Brightness.dark ? const Color(0xFF0A0A0A) : Colors.white,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          minimumSize: const Size(double.infinity, 50),
        ),
      ),
      iconTheme: IconThemeData(color: c.textSecondary, size: 22),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.navBar,
        // For light accents (Slate), use surfaceVariant as indicator so it's visible
        indicatorColor: c.accent.computeLuminance() > 0.5
            ? c.surfaceVariant
            : c.accent.withValues(alpha: 0.14),
        height: 68,
      ),
      dividerTheme: DividerThemeData(color: c.surfaceVariant, thickness: 1, space: 0),
    );
  }
}
