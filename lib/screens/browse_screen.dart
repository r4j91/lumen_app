import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/haptic_service.dart';
import '../services/supabase_client.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_sheet.dart';
import '../widgets/modal_media_query.dart';
import '../widgets/pressable.dart';
import '../widgets/project_options_sheet.dart';
import 'labels_screen.dart';
import 'appearance_screen.dart';
import 'logbook_screen.dart';
import 'notifications_settings_screen.dart';
import 'productivity_screen.dart';
import 'profile_screen.dart';
import 'project_detail_screen.dart';
import 'search_screen.dart';
import 'package:hugeicons/hugeicons.dart';

// ── Public entry-point ────────────────────────────────────────────────────────

class BrowseScreen extends StatefulWidget {
  const BrowseScreen({super.key});

  @override
  State<BrowseScreen> createState() => BrowseScreenState();
}

class BrowseScreenState extends State<BrowseScreen> {
  final _navKey = GlobalKey<NavigatorState>();

  /// Allow Android back / system pop to go back inside the nested navigator.
  Future<bool> maybePop() =>
      _navKey.currentState?.maybePop() ?? Future.value(false);

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: _navKey,
      onGenerateRoute: (_) => _IOSSlideRoute(
        builder: (_) => const _BrowseHome(),
      ),
    );
  }
}

// ── Main browse content ───────────────────────────────────────────────────────

class _Project {
  final String id;
  final String name;
  final bool favorite;
  final int taskCount;
  final Color color;
  const _Project({
    required this.id,
    required this.name,
    required this.favorite,
    required this.taskCount,
    this.color = const Color(0xFF5FD3DC),
  });
}

Color _folderColorFromName(String name) {
  final palette = [
    AppColors.accent,
    AppColors.priorityHigh,
    AppColors.priorityMedium,
    AppColors.priorityLow,
    AppColors.tagPurple,
    AppColors.tagGreen,
  ];
  return palette[name.codeUnits.fold(0, (a, b) => a + b) % palette.length];
}

class _BrowseHome extends StatefulWidget {
  const _BrowseHome();

  @override
  State<_BrowseHome> createState() => _BrowseHomeState();
}

class _BrowseHomeState extends State<_BrowseHome> {
  List<_Project> _projects = [];
  bool _loading = true;
  StreamSubscription? _authSub;

  @override
  void initState() {
    super.initState();
    _load();
    // Rebuild when user metadata changes (profile saved from settings)
    _authSub = supabase.auth.onAuthStateChange.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Fetch projects + pending task counts in parallel
      final results = await Future.wait([
        supabase
            .from('projects')
            .select('id, nome, favorito, cor')
            .eq('user_id', userId)
            .order('nome'),
        supabase
            .from('tasks')
            .select('project_id')
            .eq('user_id', userId)
            .eq('concluida', false)
            .not('project_id', 'is', null),
      ]);

      final projectRows = results[0] as List;
      final taskRows = results[1] as List;

      // Build count map
      final countMap = <String, int>{};
      for (final t in taskRows) {
        final pid = t['project_id']?.toString() ?? '';
        countMap[pid] = (countMap[pid] ?? 0) + 1;
      }

      if (!mounted) return;
      setState(() {
        _projects = projectRows.map((r) {
          final id = r['id'].toString();
          final name = r['nome'] as String;
          return _Project(
            id: id,
            name: name,
            favorite: r['favorito'] as bool? ?? false,
            taskCount: countMap[id] ?? 0,
            color: r['cor'] != null ? AppColors.parseHex(r['cor'] as String?) : _folderColorFromName(name),
          );
        }).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFavorite(_Project p) async {
    final idx = _projects.indexWhere((x) => x.id == p.id);
    if (idx == -1) return;
    HapticService().projectFavorited();
    final newVal = !p.favorite;
    setState(() {
      _projects[idx] = _Project(
        id: p.id, name: p.name, favorite: newVal,
        taskCount: p.taskCount, color: p.color,
      );
    });
    try {
      await supabase.from('projects').update({'favorito': newVal}).eq('id', p.id);
    } catch (_) {
      if (mounted) {
        setState(() {
          _projects[idx] = _Project(
            id: p.id, name: p.name, favorite: p.favorite,
            taskCount: p.taskCount, color: p.color,
          );
        });
      }
    }
  }

  static const _colorPalette = [
    Color(0xFF5FD3DC), Color(0xFF4D9FEC), Color(0xFFB18CF5), Color(0xFF8FD46B),
    Color(0xFFF5A623), Color(0xFFEF5A5F), Color(0xFFFF85A1), Color(0xFF64D8A0),
    Color(0xFFFFD166), Color(0xFF9B8EA8), Color(0xFF6EC6CA), Color(0xFFE07B54),
  ];

  Future<void> _createProject() async {
    await Navigator.of(context, rootNavigator: true).push(
      ModalSheetRoute<void>(
        builder: (_) => _NewProjectSheet(
          colorPalette: _colorPalette,
          onCreated: _load,
        ),
      ),
    );
  }

  void _openProject(_Project p) {
    Navigator.of(context).push(
      _IOSSlideRoute(
        builder: (_) => ProjectDetailScreen(
          projectId: p.id,
          projectName: p.name,
        ),
      ),
    );
  }

  void _showProjectOptions(_Project p) {
    HapticService().selectionClick();
    Navigator.of(context, rootNavigator: true).push(
      ModalSheetRoute<void>(
        builder: (_) => ProjectOptionsSheet(
          project: ProjectSheetData(id: p.id, name: p.name),
          onEdited: _load,
          onDeleted: _load,
        ),
      ),
    );
  }

  void _showSettings() => SettingsSheet.show(context);

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    final email = user?.email ?? '';
    final meta = user?.userMetadata ?? {};
    final apelido = (meta['apelido'] as String? ?? '').trim();
    final nome = (meta['nome'] as String? ?? '').trim();
    final avatarPath = meta['avatar_url'] as String?;
    final bottomInset = MediaQuery.of(context).viewPadding.bottom + 96;
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    final favorites = _projects.where((p) => p.favorite).toList();

    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: AppColors.surface,
      onRefresh: _load,
      child: CustomScrollView(
      slivers: [
        // ── Header ─────────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 16, 0),
            child: Row(
              children: [
                // User pill
                GestureDetector(
                  onTap: () => showProductivitySheet(context),
                  child: UserPill(email: email, apelido: apelido, nome: nome, avatarPath: avatarPath),
                ),
                const Spacer(),
                // Bell + Gear — only on mobile (desktop has sidebar settings)
                if (!isDesktop)
                  HeaderLiquidPill(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 11),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () => NotificationsSheet.show(context),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: HugeIcon(icon: HugeIcons.strokeRoundedNotification01, size: 22, color: AppColors.textSecondary),
                          ),
                        ),
                        Container(width: 1, height: 18, color: AppColors.textTertiary.withValues(alpha: 0.2)),
                        GestureDetector(
                          onTap: _showSettings,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: HugeIcon(icon: HugeIcons.strokeRoundedSettings01, size: 22, color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 24)),

        // ── Quick action cards ──────────────────────────────────────────────
        SliverToBoxAdapter(
          child: isDesktop
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(child: _QuickCard(icon: Icons.search, label: 'Buscar', subtitle: 'Tarefas e projetos', onTap: () => showSearchScreen(context))),
                      const SizedBox(width: 10),
                      Expanded(child: _QuickCard(icon: Icons.history_rounded, label: 'Registro', subtitle: 'Tarefas concluídas', onTap: () => Navigator.of(context).push(_IOSSlideRoute(builder: (_) => const LogbookScreen())))),
                      const SizedBox(width: 10),
                      Expanded(child: _QuickCard(icon: Icons.bar_chart_rounded, label: 'Relatórios', subtitle: 'Produtividade', onTap: () => showProductivitySheet(context))),
                    ],
                  ),
                )
              : SizedBox(
                  height: 86,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      _QuickCard(icon: Icons.search, label: 'Buscar', subtitle: 'Tarefas e projetos', onTap: () => showSearchScreen(context)),
                      const SizedBox(width: 10),
                      _QuickCard(icon: Icons.history_rounded, label: 'Registro', subtitle: 'Tarefas concluídas', onTap: () => Navigator.of(context).push(_IOSSlideRoute(builder: (_) => const LogbookScreen()))),
                      const SizedBox(width: 10),
                      _QuickCard(icon: Icons.bar_chart_rounded, label: 'Relatórios', subtitle: 'Produtividade', onTap: () => showProductivitySheet(context)),
                    ],
                  ),
                ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 28)),

        // ── Favorites ──────────────────────────────────────────────────────
        if (!_loading) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
              child: Text(
                'FAVORITOS',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textTertiary,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
          if (favorites.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Row(
                  children: [
                    HugeIcon(icon: HugeIcons.strokeRoundedStar, size: 15, color: AppColors.textTertiary),
                    SizedBox(width: 8),
                    Text(
                      'Toque na ⭐ de um projeto para favoritá-lo',
                      style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _ProjectRow(
                  project: favorites[i],
                  onTap: () => _openProject(favorites[i]),
                  onFavoriteTap: () => _toggleFavorite(favorites[i]),
                  onLongPress: () => _showProjectOptions(favorites[i]),
                ),
                childCount: favorites.length,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ],

        // ── My Projects header ──────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
            child: Text(
              'MEUS PROJETOS',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textTertiary,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ),

        // ── Projects list ───────────────────────────────────────────────────
        if (_loading)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: 32),
              child: Center(
                child: CircularProgressIndicator(
                  color: AppColors.accent,
                  strokeWidth: 2,
                ),
              ),
            ),
          )
        else if (_projects.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: _EmptyProjects(onCreate: _createProject),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => _ProjectRow(
                project: _projects[i],
                onTap: () => _openProject(_projects[i]),
                onFavoriteTap: () => _toggleFavorite(_projects[i]),
                onLongPress: () => _showProjectOptions(_projects[i]),
              ),
              childCount: _projects.length,
            ),
          ),

        SliverToBoxAdapter(child: SizedBox(height: bottomInset)),
        // Fill remaining space so CanvasKit doesn't show WebGL default grey
        SliverFillRemaining(
          hasScrollBody: false,
          child: ColoredBox(color: AppColors.background),
        ),
      ],
    ));
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

BoxShadow _cardShadow() => BoxShadow(
  color: Colors.black.withValues(
    alpha: AppColors.navBar.computeLuminance() > 0.5 ? 0.06 : 0.18,
  ),
  blurRadius: 8,
  offset: const Offset(0, 2),
);

/// Liquid Glass treatment for the header pills (avatar pill, bell+gear
/// pill) — same blur/fill/border/shadow recipe as the bottom nav's
/// `_LiquidGlassPill` (responsive_layout.dart), reused here so both header
/// pills match the nav bar's already-correct visual language.
class HeaderLiquidPill extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const HeaderLiquidPill({required this.child, required this.padding});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: AppColors.navBar.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: AppColors.textPrimary.withValues(alpha: 0.06),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.20),
                blurRadius: 20,
                spreadRadius: -2,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class UserPill extends StatelessWidget {
  final String email;
  final String apelido;
  final String nome;
  final String? avatarPath;
  const UserPill({required this.email, this.apelido = '', this.nome = '', this.avatarPath});

  String get _initials {
    final display = apelido.isNotEmpty ? apelido : nome.isNotEmpty ? nome : email.split('@').first;
    final parts = display.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return display.substring(0, display.length.clamp(0, 2)).toUpperCase();
  }

  String get _displayName {
    if (apelido.isNotEmpty) return apelido;
    if (nome.isNotEmpty) return nome.split(' ').first;
    final local = email.split('@').first;
    return local
        .split('.')
        .map((s) => s.isEmpty ? '' : s[0].toUpperCase() + s.substring(1))
        .join(' ');
  }

  bool get _hasPhoto => avatarPath != null && avatarPath!.startsWith('http');

  @override
  Widget build(BuildContext context) {
    return HeaderLiquidPill(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent.withValues(alpha: 0.18),
              image: _hasPhoto
                  ? DecorationImage(image: NetworkImage(avatarPath!), fit: BoxFit.cover)
                  : null,
            ),
            child: _hasPhoto
                ? null
                : Center(
                    child: Text(
                      _initials,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          Text(
            _displayName,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  const _QuickCard({required this.icon, required this.label, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressableCard(
      onTap: onTap,
      child: Container(
        width: 110,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [_cardShadow()],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, size: 22, color: AppColors.accent),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectRow extends StatelessWidget {
  final _Project project;
  final VoidCallback onTap;
  final VoidCallback onFavoriteTap;
  final VoidCallback? onLongPress;
  const _ProjectRow({
    required this.project,
    required this.onTap,
    required this.onFavoriteTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final color = project.color;
    return PressableCard(
      onTap: onTap,
      onLongPress: onLongPress,
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            // Faixa lateral colorida
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Container(
                width: 3,
                height: 30,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Ícone container neutro
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.07),
                  width: 1,
                ),
              ),
              child: HugeIcon(icon: HugeIcons.strokeRoundedPackage,
                size: 16,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(width: 12),
            // Nome
            Expanded(
              child: Text(
                project.name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Badge de contagem discreto
            if (project.taskCount > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${project.taskCount}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            // Estrela favorito
            GestureDetector(
              onTap: onFavoriteTap,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Icon(
                  project.favorite ? Icons.star_rounded : Icons.star_border_rounded,
                  size: 17,
                  color: project.favorite
                      ? const Color(0xFFF4C95D)
                      : AppColors.textTertiary.withValues(alpha: 0.5),
                ),
              ),
            ),
            // Chevron
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01,
                size: 15,
                color: AppColors.textTertiary.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyProjects extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyProjects({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [_cardShadow()],
      ),
      child: Column(
        children: [
          HugeIcon(icon: HugeIcons.strokeRoundedFolderOpen, size: 36, color: AppColors.textTertiary),
          const SizedBox(height: 10),
          Text(
            'Nenhum projeto ainda',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            'Organize suas tarefas criando um projeto.',
            style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const HugeIcon(icon: HugeIcons.strokeRoundedAdd01, size: 16),
            label: const Text('Criar projeto'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.background,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Settings sheet ────────────────────────────────────────────────────────────

class SettingsSheet extends StatelessWidget {
  const SettingsSheet();

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true, // renderiza acima do bottom nav e FAB
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(ctx, rootNavigator: true).pop(),
        child: const SettingsSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final view = View.of(context);
    // Com useRootNavigator: true, o sheet cobre o nav bar → só safe area
    final bottomClearance = view.padding.bottom / view.devicePixelRatio + 24.0;
    return DraggableScrollableSheet(
      initialChildSize: 0.68,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      snap: true,
      snapSizes: [0.68],
      builder: (_, ctrl) => GestureDetector(
        // Absorb taps on the sheet so they don't propagate to the outer dismiss detector
        onTap: () {},
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: ctrl,
            padding: EdgeInsets.fromLTRB(20, 0, 20, bottomClearance),
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Configurações',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 20),

              // Profile card
              _ProfileCard(onTap: () {
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(builder: (_) => const ProfileEditScreen()),
                );
              }),
              const SizedBox(height: 24),

              // Preferences
              _settingSection('Preferências'),
              _settingsCard([
                _SettingItem(icon: Icons.notifications_outlined, label: 'Notificações', onTap: () {
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(builder: (_) => const NotificationsSettingsScreen()),
                  );
                }),
                _SettingItem(icon: Icons.palette_outlined, label: 'Aparência', onTap: () {
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(builder: (_) => const AppearanceScreen()),
                  );
                }),
                _SettingItem(icon: Icons.language_outlined, label: 'Idioma', onTap: () {}),
              ]),
              const SizedBox(height: 20),

              // Organisation
              _settingSection('Organização'),
              _settingsCard([
                _SettingItem(
                  icon: Icons.label_outline,
                  label: 'Gerenciar Etiquetas',
                  onTap: () {
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(builder: (_) => const LabelsScreen()),
                    );
                  },
                ),
              ]),
              const SizedBox(height: 28),

              // Logout
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context, rootNavigator: true).pop();
                    AuthService().signOut();
                  },
                  icon: const HugeIcon(icon: HugeIcons.strokeRoundedLogout01, size: 16),
                  label: const Text('Sair da conta'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.priorityHigh,
                    side: BorderSide(color: AppColors.priorityHigh),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _settingSection(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textTertiary,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  static Widget _settingsCard(List<_SettingItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            items[i],
            if (i < items.length - 1)
              Divider(height: 1, indent: 46, color: AppColors.surface),
          ],
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final VoidCallback onTap;
  const _ProfileCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    final email = user?.email ?? '';
    final meta = user?.userMetadata ?? {};
    final apelido = (meta['apelido'] as String? ?? '').trim();
    final nome = (meta['nome'] as String? ?? '').trim();
    final avatarPath = meta['avatar_url'] as String?;
    final hasPhoto = avatarPath != null && avatarPath.startsWith('http');
    final displayName = apelido.isNotEmpty
        ? apelido
        : nome.isNotEmpty
            ? nome
            : email.split('@').first.split('.').map((s) => s.isEmpty ? '' : s[0].toUpperCase() + s.substring(1)).join(' ');
    final display = apelido.isNotEmpty ? apelido : nome.isNotEmpty ? nome : email.split('@').first;
    final parts = display.trim().split(' ');
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : display.substring(0, display.length.clamp(0, 2)).toUpperCase();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withValues(alpha: 0.15),
                image: hasPhoto
                    ? DecorationImage(image: NetworkImage(avatarPath!), fit: BoxFit.cover)
                    : null,
              ),
              child: hasPhoto
                  ? null
                  : Center(
                      child: Text(initials, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.accent)),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayName, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(email, style: TextStyle(fontSize: 12, color: AppColors.textTertiary), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, size: 18, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _SettingItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _SettingItem({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
              ),
            ),
            HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, size: 16, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}


// ── iOS-style slide transition ────────────────────────────────────────────────

class _IOSSlideRoute<T> extends PageRouteBuilder<T> {
  _IOSSlideRoute({required WidgetBuilder builder})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 280),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final slideIn = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            final slideOut = CurvedAnimation(
              parent: secondaryAnimation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return Stack(
              children: [
                // Outgoing page: parallax slide left
                SlideTransition(
                  position: Tween<Offset>(
                    begin: Offset.zero,
                    end: const Offset(-0.3, 0),
                  ).animate(slideOut),
                  child: AnimatedBuilder(
                    animation: slideOut,
                    builder: (_, Widget? c) => ColorFiltered(
                      colorFilter: ColorFilter.mode(
                        Colors.black.withValues(alpha: slideOut.value * 0.3),
                        BlendMode.srcATop,
                      ),
                      child: c,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
                // Incoming page: slide in from right with left-edge shadow
                SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(1.0, 0),
                    end: Offset.zero,
                  ).animate(slideIn),
                  child: DecoratedBoxTransition(
                    decoration: DecorationTween(
                      begin: const BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x44000000),
                            blurRadius: 24,
                            offset: Offset(-8, 0),
                          ),
                        ],
                      ),
                      end: const BoxDecoration(boxShadow: []),
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: const Interval(0.0, 0.6),
                    )),
                    child: child,
                  ),
                ),
              ],
            );
          },
        );
}

// ── Bell / Notifications Sheet ─────────────────────────────────────────────

class NotificationsSheet extends StatefulWidget {
  const NotificationsSheet();

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const NotificationsSheet(),
    );
  }

  @override
  State<NotificationsSheet> createState() => NotificationsSheetState();
}

class NotificationsSheetState extends State<NotificationsSheet> {
  List<Map<String, dynamic>> _upcoming = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) { setState(() => _loading = false); return; }
      final now = DateTime.now().toIso8601String().substring(0, 10);
      final rows = await supabase
          .from('tasks')
          .select('id, titulo, data_vencimento')
          .eq('user_id', userId)
          .eq('concluida', false)
          .gte('data_vencimento', now)
          .order('data_vencimento')
          .limit(20);
      if (mounted) setState(() { _upcoming = List<Map<String, dynamic>>.from(rows); _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final view = View.of(context);
    final topPad = view.padding.top / view.devicePixelRatio;
    final botPad = view.padding.bottom / view.devicePixelRatio;
    return Container(
      margin: EdgeInsets.only(top: topPad + 60),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 36, height: 4,
            decoration: BoxDecoration(color: AppColors.textTertiary.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(children: [
              Text('Próximas', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const Spacer(),
              IconButton(
                icon: HugeIcon(icon: HugeIcons.strokeRoundedCancel01, color: AppColors.textSecondary, size: 20),
                onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                visualDensity: VisualDensity.compact,
              ),
            ]),
          ),
          Expanded(child: _loading
            ? Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2))
            : _upcoming.isEmpty
              ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  HugeIcon(icon: HugeIcons.strokeRoundedNotification01, size: 48, color: AppColors.textTertiary),
                  const SizedBox(height: 12),
                  Text('Nenhuma notificação agendada', style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
                ])
              : ListView.builder(
                  padding: EdgeInsets.only(bottom: botPad + 16),
                  itemCount: _upcoming.length,
                  itemBuilder: (_, i) {
                    final item = _upcoming[i];
                    final due = DateTime.tryParse(item['data_vencimento'] ?? '');
                    final today = DateTime.now();
                    final diff = due == null ? null : DateTime(due.year, due.month, due.day)
                        .difference(DateTime(today.year, today.month, today.day)).inDays;
                    final label = diff == null ? '' : diff == 0 ? 'Hoje' : diff == 1 ? 'Amanhã' : 'Em $diff dias';
                    return ListTile(
                      leading: HugeIcon(icon: HugeIcons.strokeRoundedNotification01, color: AppColors.accent, size: 20),
                      title: Text(item['titulo'] ?? '', style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
                      subtitle: label.isNotEmpty ? Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)) : null,
                      dense: true,
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}

// ── New project sheet ─────────────────────────────────────────────────────────

class _NewProjectSheet extends StatefulWidget {
  final List<Color> colorPalette;
  final VoidCallback onCreated;
  const _NewProjectSheet({required this.colorPalette, required this.onCreated});

  @override
  State<_NewProjectSheet> createState() => _NewProjectSheetState();
}

class _NewProjectSheetState extends State<_NewProjectSheet> {
  late final TextEditingController _ctrl;
  late Color _selectedColor;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
    _selectedColor = widget.colorPalette.first;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _ctrl.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop();
    final userId = supabase.auth.currentUser?.id;
    final hexColor = '#${_selectedColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
    try {
      await supabase.from('projects').insert({
        'nome': name,
        if (userId != null) 'user_id': userId,
        'favorito': false,
        'cor': hexColor,
      });
      widget.onCreated();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final kh = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: kh),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF242529),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.fromLTRB(20, 16, 20, kh > 0 ? 16 : 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF6B6E76).withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Novo projeto', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            TextField(
              controller: _ctrl,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
              cursorColor: AppColors.accent,
              decoration: InputDecoration(
                hintText: 'Nome do projeto',
                hintStyle: TextStyle(color: AppColors.textTertiary),
                filled: true,
                fillColor: AppColors.surfaceVariant,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            Text('Cor', style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: widget.colorPalette.map((c) {
                final selected = c == _selectedColor;
                return GestureDetector(
                  onTap: () {
                    HapticService().selectionClick();
                    setState(() => _selectedColor = c);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c,
                      border: selected ? Border.all(color: Colors.white, width: 2.5) : null,
                      boxShadow: selected ? [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 8)] : null,
                    ),
                    child: selected ? const HugeIcon(icon: HugeIcons.strokeRoundedTick01, size: 16, color: Colors.white) : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.background,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Criar projeto', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
