// PROJECT-ICONS-V1
import 'package:hugeicons/hugeicons.dart';

/// Mapa de lookup entre a string salva na coluna 'icone' (tabela 'projects'
/// no Supabase) e o ícone Hugeicons correspondente. As chaves são as strings
/// REAIS já salvas para projetos existentes (ver project_options_sheet.dart
/// _projectIcons) — não renomeadas, pra não quebrar compatibilidade.
class ProjectIcons {
  static const Map<String, List<List<dynamic>>> iconMap = {
    'folder': HugeIcons.strokeRoundedFolder01,
    'work': HugeIcons.strokeRoundedBriefcase01,
    'home': HugeIcons.strokeRoundedHome01,
    'school': HugeIcons.strokeRoundedMortarboard01,
    'fitness': HugeIcons.strokeRoundedDumbbell01,
    'shopping': HugeIcons.strokeRoundedShoppingCart01,
    'favorite': HugeIcons.strokeRoundedFavourite,
    'star': HugeIcons.strokeRoundedStar,
    'rocket': HugeIcons.strokeRoundedRocket01,
    'lightbulb': HugeIcons.strokeRoundedIdea01,
    'music': HugeIcons.strokeRoundedMusicNote01,
    'travel': HugeIcons.strokeRoundedGlobe02,
    'money': HugeIcons.strokeRoundedMoney01,
    'health': HugeIcons.strokeRoundedShield01,
    'code': HugeIcons.strokeRoundedCode,
    'art': HugeIcons.strokeRoundedPaintBrush01,
  };

  /// Ícone padrão quando a string salva não existe no mapa.
  static const List<List<dynamic>> fallback = HugeIcons.strokeRoundedFolder01;

  /// Resolve uma string salva no Supabase para o ícone Hugeicons.
  static List<List<dynamic>> resolve(String? iconKey) {
    if (iconKey == null) return fallback;
    return iconMap[iconKey] ?? fallback;
  }

  /// Lista ordenada para o seletor (mesma ordem do grid atual).
  static final List<MapEntry<String, List<List<dynamic>>>> iconList =
      iconMap.entries.toList();
}
