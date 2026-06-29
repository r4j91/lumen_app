import 'dart:async';
import 'package:flutter/material.dart';
import '../services/haptic_service.dart';
import '../services/project_repository.dart';
import '../services/supabase_client.dart';
import '../services/task_repository.dart';
import '../theme/app_layout.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/modal_media_query.dart';
import '../widgets/new_project_sheet.dart';
import '../widgets/pressable.dart';
import '../widgets/project_options_sheet.dart';
import '../widgets/settings/settings.dart';
import 'logbook_screen.dart';
import 'productivity_screen.dart';
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
    // FIXED-COLOR: default param precisa ser const — AppColors.accent é
    // getter (não-const), não pode ser usado aqui. Valor duplicado de
    // propósito (igual ao accent do tema graphite), mantido fixo.
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
  static const _projectRepo = ProjectRepository();
  static const _taskRepo = TaskRepository();

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

      final projectRows = await _projectRepo.fetchProjectRowsForUser(userId);
      final taskRows = await _taskRepo.fetchPendingTaskProjectIds(userId);

      final countMap = <String, int>{};
      for (final t in taskRows) {
        final pid = t['project_id']?.toString();
        if (pid == null || pid.isEmpty) continue;
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
            color: r['cor'] != null
                ? AppColors.parseHex(r['cor'] as String?)
                : _folderColorFromName(name),
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
        id: p.id,
        name: p.name,
        favorite: newVal,
        taskCount: p.taskCount,
        color: p.color,
      );
    });
    try {
      await _projectRepo.toggleFavorite(p.id, newVal);
    } catch (_) {
      if (mounted) {
        setState(() {
          _projects[idx] = _Project(
            id: p.id,
            name: p.name,
            favorite: p.favorite,
            taskCount: p.taskCount,
            color: p.color,
          );
        });
      }
    }
  }

  Future<void> _createProject() async {
    await showNewProjectSheet(context, onCreated: _load);
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
    final bottomInset = AppLayout.bottomListInset(context);
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
                      Expanded(child: _QuickCard(hugeIcon: HugeIcons.strokeRoundedSearch01, label: 'Buscar', subtitle: 'Tarefas e projetos', onTap: () => showSearchScreen(context))),
                      const SizedBox(width: 10),
                      Expanded(child: _QuickCard(hugeIcon: HugeIcons.strokeRoundedClock01, label: 'Registro', subtitle: 'Tarefas concluídas', onTap: () => Navigator.of(context).push(_IOSSlideRoute(builder: (_) => const LogbookScreen())))),
                      const SizedBox(width: 10),
                      Expanded(child: _QuickCard(hugeIcon: HugeIcons.strokeRoundedAnalytics01, label: 'Relatórios', subtitle: 'Produtividade', onTap: () => showProductivitySheet(context))),
                    ],
                  ),
                )
              : SizedBox(
                  height: 86,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      _QuickCard(hugeIcon: HugeIcons.strokeRoundedSearch01, label: 'Buscar', subtitle: 'Tarefas e projetos', onTap: () => showSearchScreen(context)),
                      const SizedBox(width: 10),
                      _QuickCard(hugeIcon: HugeIcons.strokeRoundedClock01, label: 'Registro', subtitle: 'Tarefas concluídas', onTap: () => Navigator.of(context).push(_IOSSlideRoute(builder: (_) => const LogbookScreen()))),
                      const SizedBox(width: 10),
                      _QuickCard(hugeIcon: HugeIcons.strokeRoundedAnalytics01, label: 'Relatórios', subtitle: 'Produtividade', onTap: () => showProductivitySheet(context)),
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
                (_, i) => RepaintBoundary(
                  key: ValueKey('rb_fav_${favorites[i].id}'),
                  child: _ProjectRow(
                    project: favorites[i],
                    onTap: () => _openProject(favorites[i]),
                    onFavoriteTap: () => _toggleFavorite(favorites[i]),
                    onLongPress: () => _showProjectOptions(favorites[i]),
                  ),
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
              (_, i) => RepaintBoundary(
                key: ValueKey('rb_proj_${_projects[i].id}'),
                child: _ProjectRow(
                  project: _projects[i],
                  onTap: () => _openProject(_projects[i]),
                  onFavoriteTap: () => _toggleFavorite(_projects[i]),
                  onLongPress: () => _showProjectOptions(_projects[i]),
                ),
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

class _QuickCard extends StatelessWidget {
  final List<List<dynamic>> hugeIcon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  const _QuickCard({required this.hugeIcon, required this.label, required this.subtitle, required this.onTap});

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
            HugeIcon(icon: hugeIcon, size: 22, color: AppColors.accent),
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
                color: AppColors.surfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.textTertiary.withValues(alpha: 0.12),
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
                  color: AppColors.textTertiary.withValues(alpha: 0.12),
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
                // FIXED-COLOR: dourado decorativo único de "favorito"
                child: HugeIcon(
                  icon: project.favorite
                      ? HugeIcons.strokeRoundedFavourite
                      : HugeIcons.strokeRoundedStar,
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
