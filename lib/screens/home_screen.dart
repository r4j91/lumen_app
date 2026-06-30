import 'package:flutter/material.dart';
import '../services/haptic_service.dart';
import '../services/project_repository.dart';
import '../services/supabase_client.dart';
import '../services/task_repository.dart';
import '../services/task_sync.dart';
import '../theme/app_layout.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../widgets/modal_media_query.dart' show ModalSheetRoute;
import '../widgets/project_options_sheet.dart';
import 'productivity_screen.dart' show showProductivitySheet;
import 'project_detail_screen.dart';
import '../widgets/settings/settings.dart';
import '../widgets/load_error_view.dart';
import '../widgets/scroll_fade_overlay.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/empty_state.dart';
import '../widgets/pressable.dart';
import '../widgets/app_button.dart';
import '../widgets/new_project_sheet.dart';
import 'package:hugeicons/hugeicons.dart';
import '../utils/project_icons.dart';

class _HomeProject {
  final String id;
  final String name;
  final int taskCount;
  final Color color;
  // ICON-OLD: sem campo de ícone.
  final String? iconName;
  const _HomeProject({
    required this.id,
    required this.name,
    required this.taskCount,
    required this.color,
    this.iconName,
  });
}

// PROJECT-ICONS-OLD: _iconFromName(name) -> IconData Material, switch local
// — movido pra ProjectIcons.resolve(name) (lib/utils/project_icons.dart),
// mesmas chaves, agora resolvendo pra Hugeicons.

class HomeScreen extends StatefulWidget {
  // Callback pra trocar de tab no RootScreen (main.dart) — mesmo padrão
  // já usado por onTaskCreated. Índices: 1=Inbox, 2=Today, 3=Upcoming,
  // 4=Filters (ver main.dart:125-131).
  final void Function(int)? onNavigateToTab;
  final void Function(TaskFilterKind)? onNavigateToFilter;
  const HomeScreen({super.key, this.onNavigateToTab, this.onNavigateToFilter});
  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  static const _projectRepo = ProjectRepository();
  static const _taskRepo = TaskRepository();

  bool _loading = true;

  // Próxima tarefa prioritária do dia + agregados do card "Hoje". Não há
  // método de TaskRepository que sirva direto aqui: fetchTodayTasks()
  // filtra concluida=false e usa .lte (hoje+atrasadas), e o card precisa
  // do total (feitas+pendentes) restrito a exatamente hoje.
  int _overdueCount = 0;
  int _todayTotal = 0;
  int _todayDone = 0;
  bool _loadingTasks = true;

  // Contadores dos atalhos. _filterCount fica sempre 0: não existe tabela
  // 'filters' no Supabase — FiltersScreen é um dashboard de categorias
  // fixas (atrasadas/hoje/semana/completas), não linhas de uma tabela.
  // Consultar uma tabela inexistente lançaria exceção e abortaria o resto
  // de _loadProjects() (projetos/inbox/upcoming também ficariam sem
  // carregar), então esse fetch foi omitido.
  int _inboxCount = 0;
  int _upcomingCount = 0;

  List<_HomeProject> _projects = [];
  bool _loadingProjects = true;
  String? _loadError;
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _loadTasks();
    _loadProjects();
    TaskSync.instance.addListener(reload);
  }

  @override
  void dispose() {
    TaskSync.instance.removeListener(reload);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void reload() {
    _loadTasks();
    _loadProjects();
  }

  int get _todayPending => (_todayTotal - _todayDone).clamp(0, _todayTotal);

  static final _navIconColor = AppColors.textSecondary;
  static final _countStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.textTertiary,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  String get _firstName {
    final user = supabase.auth.currentUser;
    final meta = user?.userMetadata ?? {};
    final apelido = (meta['apelido'] as String? ?? '').trim();
    final nome = (meta['nome'] as String? ?? '').trim();
    if (apelido.isNotEmpty) return apelido.split(' ').first;
    if (nome.isNotEmpty) return nome.split(' ').first;
    final email = user?.email ?? '';
    if (email.isEmpty) return '';
    final local = email.split('@').first;
    final part = local.split('.').first;
    if (part.isEmpty) return local;
    return part[0].toUpperCase() + part.substring(1);
  }

  Future<void> _loadProjects() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) setState(() => _loadingProjects = false);
        return;
      }
      final now = DateTime.now();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final projRows = await _projectRepo.fetchProjectRowsForUser(userId);
      final taskRows = await _taskRepo.fetchPendingTaskProjectIds(userId);
      final upcomingCount = await _taskRepo.countUpcomingTasks(userId, todayStr);

      final countMap = <String, int>{};
      var inboxCount = 0;
      for (final t in taskRows) {
        final pid = t['project_id'] as String?;
        if (pid == null) {
          inboxCount++;
        } else {
          countMap[pid] = (countMap[pid] ?? 0) + 1;
        }
      }

      final projects = projRows.map((r) {
        final id = r['id'].toString();
        final name = r['nome'] as String? ?? '';
        return _HomeProject(
          id: id,
          name: name,
          taskCount: countMap[id] ?? 0,
          color: r['cor'] != null
              ? AppColors.parseHex(r['cor'] as String?)
              : _folderColorFromName(name),
          iconName: r['icone'] as String?,
        );
      }).toList();

      if (mounted) {
        setState(() {
          _projects = projects;
          _inboxCount = inboxCount;
          _upcomingCount = upcomingCount;
          _loadingProjects = false;
          _loadError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingProjects = false;
          if (_projects.isEmpty) _loadError ??= e.toString();
        });
      }
    }
  }

  // Mesmo algoritmo de _folderColorFromName em browse_screen.dart.
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

  Future<void> _loadTasks() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) setState(() => _loadingTasks = false);
        return;
      }
      final now = DateTime.now();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final summary = await _taskRepo.fetchHomeTaskSummary(userId: userId, todayStr: todayStr);

      if (mounted) {
        setState(() {
          _todayTotal = summary.todayTotal;
          _todayDone = summary.todayDone;
          _overdueCount = summary.overdueCount;
          _loadingTasks = false;
          _loadError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingTasks = false;
          if (_todayTotal == 0 && _inboxCount == 0) _loadError ??= e.toString();
        });
      }
    }
  }

  // Mesmo padrão usado em browse_screen.dart/productivity_screen.dart:
  // apelido > primeiro nome > parte local do email — lido direto de
  // userMetadata (síncrono, sem fetch a tabela profiles).
  Future<void> _loadUserName() async {
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = AppLayout.homeDockBottomInset(context);

    if (_loadError != null &&
        !_loadingTasks &&
        !_loadingProjects &&
        _projects.isEmpty &&
        _todayTotal == 0 &&
        _inboxCount == 0) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: LoadErrorView(onRetry: () {
          setState(() => _loadError = null);
          reload();
        }),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: _loading
          ? const Center(child: SkeletonLoader(itemCount: 3))
          : RefreshIndicator(
              onRefresh: () async {
                await Future.wait([
                  _loadTasks(),
                  _loadProjects(),
                ]);
              },
              color: AppColors.accent,
              child: ScrollFadeOverlay(
                scrollController: _scrollCtrl,
                child: CustomScrollView(
                  controller: _scrollCtrl,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeader(),
                          _buildGreeting(context),
                          if (_loadingTasks)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                              child: SkeletonLoader(itemCount: 3),
                            )
                          else ...[
                            if (_overdueCount > 0)
                              _buildOverdueBanner(context)
                            else
                              _buildAllClearHint(),
                            _buildNavSection(),
                          ],
                          _buildProjectsSection(context),
                        ],
                      ),
                    ),
                    SliverToBoxAdapter(child: SizedBox(height: bottomInset)),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    final user = supabase.auth.currentUser;
    final email = user?.email ?? '';
    final meta = user?.userMetadata ?? {};
    final apelido = (meta['apelido'] as String? ?? '').trim();
    final nome = (meta['nome'] as String? ?? '').trim();
    final avatarPath = meta['avatar_url'] as String?;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm,
      ),
      child: Row(
        children: [
          Pressable(
            onTap: () => showProductivitySheet(context),
            child: Semantics(
              button: true,
              label: 'Relatório de produtividade',
              child: UserPill(
                email: email,
                apelido: apelido,
                nome: nome,
                avatarPath: avatarPath,
                showName: false,
              ),
            ),
          ),
          const Spacer(),
          HeaderLiquidPill(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _HeaderIconButton(
                  label: 'Notificações',
                  icon: HugeIcons.strokeRoundedNotification01,
                  onTap: () => NotificationsSheet.show(context),
                ),
                Container(
                  width: 1,
                  height: AppLayout.headerControlSize * 0.5,
                  color: AppColors.textTertiary.withValues(alpha: 0.2),
                ),
                _HeaderIconButton(
                  label: 'Configurações',
                  icon: HugeIcons.strokeRoundedSettings01,
                  onTap: () => SettingsSheet.show(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Bom dia';
    if (hour < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  Widget _buildGreeting(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final name = _firstName;
    final greetingLine = name.isNotEmpty ? '$_greeting, $name' : _greeting;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            greetingLine,
            style: textTheme.headlineMedium?.copyWith(letterSpacing: -0.3),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Vamos focar no que realmente importa hoje.',
            style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xs,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  // ── ALL CLEAR HINT ─────────────────────────────────
  Widget _buildAllClearHint() {
    const label = 'Tudo em dia';
    final color = AppColors.onTrackMuted;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.sm,
      ),
      child: Semantics(
        label: label,
        child: Row(
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedTick01,
              size: 16,
              color: color,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── OVERDUE BANNER ─────────────────────────────────
  Widget _buildOverdueBanner(BuildContext context) {
    final label = _overdueCount == 1
        ? '1 tarefa atrasada'
        : '$_overdueCount tarefas atrasadas';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.sm,
      ),
      child: Semantics(
        button: true,
        label: label,
        child: Pressable(
          onTap: () => widget.onNavigateToFilter?.call(TaskFilterKind.overdue),
          child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md + 2,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: AppColors.overdue.withValues(alpha: isDark ? 0.18 : 0.12),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: AppColors.overdue.withValues(alpha: 0.28),
            ),
          ),
          child: Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedAlert01,
                size: 18,
                color: AppColors.overdue,
              ),
              const SizedBox(width: AppSpacing.sm + 2),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.overdue,
                  ),
                ),
              ),
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                size: 16,
                color: AppColors.overdue.withValues(alpha: 0.85),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  // ── NAV ROWS (Inbox / Hoje / Em breve) ─────────────
  Widget _buildNavSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionLabel('VISÃO GERAL'),
        _buildNavRow(
          leading: HugeIcon(
            icon: HugeIcons.strokeRoundedInbox,
            size: 22,
            color: _navIconColor,
          ),
          label: 'Inbox',
          count: _inboxCount,
          semanticsLabel: 'Inbox, $_inboxCount tarefas',
          onTap: () => widget.onNavigateToTab?.call(1),
        ),
        _buildNavRow(
          leading: HugeIcon(
            icon: HugeIcons.strokeRoundedCalendar02,
            size: 22,
            color: _navIconColor,
          ),
          label: 'Hoje',
          count: _todayPending,
          semanticsLabel: 'Hoje, $_todayPending tarefas pendentes',
          onTap: () => widget.onNavigateToTab?.call(2),
        ),
        _buildNavRow(
          leading: HugeIcon(
            icon: HugeIcons.strokeRoundedCalendar03,
            size: 22,
            color: _navIconColor,
          ),
          label: 'Em breve',
          count: _upcomingCount,
          semanticsLabel: 'Em breve, $_upcomingCount tarefas',
          onTap: () => widget.onNavigateToTab?.call(3),
        ),
      ],
    );
  }

  Widget _buildNavRow({
    required Widget leading,
    required String label,
    required int count,
    required String semanticsLabel,
    VoidCallback? onTap,
  }) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: Pressable(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: 13,
          ),
          child: Row(
            children: [
              SizedBox(width: 28, height: 28, child: Center(child: leading)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text('$count', style: _countStyle),
              const SizedBox(width: AppSpacing.sm),
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                size: 16,
                color: AppColors.textTertiary.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── PROJETOS ─────────────────────────────────────────
  Widget _buildProjectsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm,
          ),
          child: Divider(
            height: 1,
            thickness: 1,
            color: AppColors.textTertiary.withValues(alpha: 0.15),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm,
          ),
          child: Text(
            'PROJETOS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        if (_loadingProjects)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: SkeletonLoader(itemCount: 3),
          )
        else if (_projects.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const EmptyState(
                  hugeIcon: HugeIcons.strokeRoundedFolder01,
                  title: 'Nenhum projeto ainda',
                  subtitle: 'Organize suas tarefas por contexto',
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Criar projeto',
                  fullWidth: false,
                  onPressed: () => showNewProjectSheet(
                    context,
                    onCreated: _loadProjects,
                  ),
                ),
              ],
            ),
          )
        else
          Column(
            children: [
              for (final p in _projects) _buildProjectRow(p),
            ],
          ),
      ],
    );
  }

  Widget _buildProjectRow(_HomeProject p) {
    final countLabel = p.taskCount == 1 ? '1 tarefa' : '${p.taskCount} tarefas';
    return Semantics(
      button: true,
      label: 'Projeto ${p.name}, $countLabel',
      child: Pressable(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProjectDetailScreen(projectId: p.id, projectName: p.name),
          ),
        ),
        onLongPress: () {
          HapticService().selectionClick();
          Navigator.of(context, rootNavigator: true).push(
            ModalSheetRoute<void>(
              builder: (_) => ProjectOptionsSheet(
                project: ProjectSheetData(
                  id: p.id,
                  name: p.name,
                  color: p.color,
                  iconName: p.iconName,
                ),
                onEdited: () {
                  if (mounted) _loadProjects();
                },
                onDeleted: () {
                  if (mounted) _loadProjects();
                },
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 13),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: Center(
                  child: HugeIcon(
                    icon: ProjectIcons.resolve(p.iconName),
                    size: 22,
                    color: p.color,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  p.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text('${p.taskCount}', style: _countStyle),
              const SizedBox(width: AppSpacing.sm),
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                size: 16,
                color: AppColors.textTertiary.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ícone do header — alinhado ao avatar compacto ([AppLayout.headerControlSize]).
class _HeaderIconButton extends StatelessWidget {
  final String label;
  final List<List<dynamic>> icon;
  final VoidCallback onTap;

  const _HeaderIconButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Pressable(
        onTap: onTap,
        child: SizedBox(
          width: AppLayout.headerControlSize,
          height: AppLayout.headerControlSize,
          child: Center(
            child: HugeIcon(
              icon: icon,
              size: AppLayout.headerIconSize,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
