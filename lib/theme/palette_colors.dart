import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Paleta unificada para seletores de cor de etiquetas e projetos.
class PaletteColors {
  PaletteColors._();

  /// Hex strings persistidos no Supabase (`labels.cor`, `projects.cor`).
  static const labelHex = [
    // ── Tons suaves (originais) ─────────────────────────────────────────────
    '#63C7D8', // Ocean Mist
    '#6F8FB8', // Slate Blue
    '#84B98E', // Sage Green
    '#789C6B', // Moss
    '#C58D97', // Dusty Rose
    '#C58A72', // Terracotta Soft
    '#A496C8', // Lavender Grey
    '#6F79B6', // Muted Indigo
    '#C7B38A', // Sand
    '#D3B36A', // Soft Amber
    '#7F99A8', // Steel Blue
    '#9CA3AF', // Mist Grey
    // ── Tons fortes (design system) ─────────────────────────────────────────
    '#5FD3DC', // Accent
    '#4D9FEC', // Priority Low
    '#B18CF5', // Tag Purple
    '#8FD46B', // Tag Green
    '#F5A623', // Priority Medium
    '#EF5A5F', // Priority High
    '#FF85A1', // Pink
    '#64D8A0', // Mint
    '#FFD166', // Gold
    '#E07B54', // Coral
    // ── Vibrantes ───────────────────────────────────────────────────────────
    '#F43F5E', // Rose
    '#EC4899', // Hot Pink
    '#D946EF', // Fuchsia
    '#06B6D4', // Cyan
    '#10B981', // Emerald
    '#84CC16', // Lime
    '#F59E0B', // Amber
    '#F97316', // Orange
    // ── Variantes escuras ───────────────────────────────────────────────────
    '#0E7490', // Teal escuro
    '#1D4ED8', // Azul escuro
    '#6D28D9', // Roxo escuro
    '#15803D', // Verde escuro
    '#B45309', // Âmbar escuro
    '#B91C1C', // Vermelho escuro
    '#BE185D', // Rosa escuro
    '#047857', // Esmeralda escuro
    '#0F766E', // Teal profundo
    '#1E40AF', // Azul profundo
    '#5B21B6', // Violeta profundo
    '#166534', // Verde profundo
    '#92400E', // Marrom-dourado
    '#7F1D1D', // Vinho
    '#831843', // Magenta escuro
    '#134E4A', // Petróleo
  ];

  static List<Color> get projectColors =>
      labelHex.map(AppColors.parseHex).toList(growable: false);

  static String get defaultHex => labelHex[12]; // Accent #5FD3DC
}
