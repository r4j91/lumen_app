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

  // COLORS-OLD: consolidação de Color(0xFF...) hardcoded espalhados —
  // ver auditoria. Conceitos mantidos separados mesmo quando o hex
  // coincide, conforme escopo de uso original.
  static const success = Color(0xFF22C55E); // concluído / hoje em dia
  static const overdue = Color(0xFFEF4444); // tarefa atrasada (badge/texto)

  // Escala própria de prioridade de subtarefa — paralela a priorityHigh/
  // Medium/Low, valores diferentes por design original (task_tile.dart).
  static const subtaskPriorityHigh   = Color(0xFFDC4C3E);
  static const subtaskPriorityMedium = Color(0xFFEB8909);
  static const subtaskPriorityLow    = Color(0xFF246FE0);

  // Escala de proximidade de data de subtarefa (hoje/atrasada/futura) —
  // conceito distinto da prioridade, mesmo quando o hex de "atrasada"
  // coincide com subtaskPriorityHigh.
  static const dateDueToday    = Color(0xFF7ECC49);
  static const dateOverdue     = Color(0xFFDC4C3E);
  static const dateUpcoming    = Color(0xFFF0A830);

  // Cor fixa por atalho da Home — independe de tema, igual priorityHigh etc.
  static const shortcutInbox    = Color(0xFF246FE0);
  static const shortcutToday    = Color(0xFF22C55E);
  static const shortcutUpcoming = Color(0xFFEB8909);
  static const shortcutFilters  = Color(0xFF884DFF);

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
