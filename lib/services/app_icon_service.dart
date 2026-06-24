import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dynamic_icon/flutter_dynamic_icon.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class AppIconOption {
  final String id;
  final String label;
  final String assetPath;

  // iOS: null = primary icon (Oceano); non-null = CFBundleAlternateIcons key
  final String? iosIconName;

  // Android: null = default (MainActivity); non-null = activity-alias suffix
  final String? androidAlias;

  const AppIconOption({
    required this.id,
    required this.label,
    required this.assetPath,
    this.iosIconName,
    this.androidAlias,
  });

  bool get isDefault => iosIconName == null;

  // Pacote "Camadas Empilhadas" (assets/lumen_icones_completo/) — substitui o
  // pacote colorido antigo. Grafite é a variante oficial/padrão do app.
  static const List<AppIconOption> all = [
    AppIconOption(
      id: 'grafite',
      label: 'Grafite',
      assetPath: 'assets/icon/lumen_new_grafite.png',
      iosIconName: null,
      androidAlias: null,
    ),
    AppIconOption(
      id: 'cinza_escuro',
      label: 'Cinza Escuro',
      assetPath: 'assets/icon/lumen_new_cinza_escuro.png',
      iosIconName: 'cinza_escuro',
      androidAlias: 'cinzaEscuroAlias',
    ),
    AppIconOption(
      id: 'cinza_medio',
      label: 'Cinza Médio',
      assetPath: 'assets/icon/lumen_new_cinza_medio.png',
      iosIconName: 'cinza_medio',
      androidAlias: 'cinzaMedioAlias',
    ),
    AppIconOption(
      id: 'cinza_claro',
      label: 'Cinza Claro',
      assetPath: 'assets/icon/lumen_new_cinza_claro.png',
      iosIconName: 'cinza_claro',
      androidAlias: 'cinzaClaroAlias',
    ),
    AppIconOption(
      id: 'branco',
      label: 'Branco',
      assetPath: 'assets/icon/lumen_new_branco.png',
      iosIconName: 'branco',
      androidAlias: 'brancoAlias',
    ),
    AppIconOption(
      id: 'carvao',
      label: 'Carvão',
      assetPath: 'assets/icon/lumen_new_carvao.png',
      iosIconName: 'carvao',
      androidAlias: 'carvaoAlias',
    ),
    AppIconOption(
      id: 'azul_nevoa',
      label: 'Azul Névoa',
      assetPath: 'assets/icon/lumen_new_azul_nevoa.png',
      iosIconName: 'azul_nevoa',
      androidAlias: 'azulNevoaAlias',
    ),
    AppIconOption(
      id: 'azul_oceano',
      label: 'Azul Oceano',
      assetPath: 'assets/icon/lumen_new_azul_oceano.png',
      iosIconName: 'azul_oceano',
      androidAlias: 'azulOceanoAlias',
    ),
    AppIconOption(
      id: 'titanio',
      label: 'Titânio',
      assetPath: 'assets/icon/lumen_new_titanio.png',
      iosIconName: 'titanio',
      androidAlias: 'titanioAlias',
    ),
    AppIconOption(
      id: 'fosco',
      label: 'Fosco',
      assetPath: 'assets/icon/lumen_new_fosco.png',
      iosIconName: 'fosco',
      androidAlias: 'foscoAlias',
    ),
  ];
}

// ── Service ───────────────────────────────────────────────────────────────────

class AppIconService {
  static const _prefKey = 'selected_app_icon_id';

  static bool get _nativeSupport =>
      !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  Future<bool> get isSupported async {
    if (!_nativeSupport) return false;
    try {
      return await FlutterDynamicIcon.supportsAlternateIcons;
    } catch (_) {
      return false;
    }
  }

  List<AppIconOption> getAvailableIcons() => AppIconOption.all;

  Future<AppIconOption> getCurrentIcon() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString(_prefKey) ?? 'grafite';
      return AppIconOption.all.firstWhere(
        (o) => o.id == id,
        orElse: () => AppIconOption.all.first,
      );
    } catch (_) {
      return AppIconOption.all.first;
    }
  }

  Future<bool> changeIcon(AppIconOption option) async {
    if (!_nativeSupport) return false;
    try {
      final supported = await FlutterDynamicIcon.supportsAlternateIcons;
      if (!supported) return false;

      // iOS uses iosIconName; Android uses the same string (alias suffix)
      final name = Platform.isAndroid ? option.androidAlias : option.iosIconName;
      await FlutterDynamicIcon.setAlternateIconName(name);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, option.id);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> resetIcon() => changeIcon(AppIconOption.all.first);
}
