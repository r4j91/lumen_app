import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/haptic_service.dart';
import '../services/project_repository.dart';
import '../services/task_repository.dart';
import '../services/task_sync.dart';
import '../services/supabase_client.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../widgets/empty_state.dart';
import '../widgets/pressable.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/swipeable_task_tile.dart';
import '../widgets/task_tile.dart';
import 'task_detail_sheet.dart';
import 'project_detail_screen.dart';
import '../widgets/load_error_view.dart';
import '../widgets/task_list_scaffold.dart';
import '../widgets/screen_header.dart';
import '../utils/project_icons.dart';
import 'package:hugeicons/hugeicons.dart';

// ─────────────────────────────────────────────────────────────────────────────

enum _FilterView { dashboard, overdue, today, week, completed }

class _ProjectStat {
  final String id;
  final String name;
  final int pending;
  final int total;
  final Color color;
  // FILTERS-ICON-V1: campo novo, mesma chave salva por ProjectOptionsSheet
  final String? icone;
  const _ProjectStat(
      {required this.id,
      required this.name,
      required this.pending,
      required this.total,
      required this.color,
      this.icone});
}

// ─────────────────────────────────────────────────────────────────────────────

class FiltersScreen extends StatefulWidget {
  const FiltersScreen({super.key});

  @override
  FiltersScreenState createState() => FiltersScreenState();
}

class FiltersScreenState extends State<FiltersScreen> {
  static const _repo = TaskRepository();
  static const _projectRepo = ProjectRepository();
  // Dashboard stats
  bool _loading = true;
  String? _statsError;
  int _overdueCount = 0;
  int _todayCount = 0;
  int _weekCount = 0;
  int _completedCount = 0;
  List<_ProjectStat> _projects = [];

  // Filter drill-down
  _FilterView _view = _FilterView.dashboard;
  List<Task> _filterTasks = [];
  bool _filterLoading = false;
  String? _filterError;

  @override
  void initState() {
    super.initState();
    _loadStats();
    TaskSync.instance.addListener(_onTasksChanged);
  }

  @override
  void dispose() {
    TaskSync.instance.removeListener(_onTasksChanged);
    super.dispose();
  }

  void _onTasksChanged() {
    _loadStats();
    if (_view != _FilterView.dashboard) {
      _loadFilter(_view);
    }
  }

  static Color _parseProjectColor(String? hex) {
    if (hex == null || hex.isEmpty) return AppColors.accent;
    try {
      final clean = hex.replaceFirst('#', '');
      final value = int.parse(clean.length == 6 ? 'FF$clean' : clean, radix: 16);
      return Color(value);
    } catch (_) {
      return AppColors.accent;
    }
  }

  // ── Load dashboard counts ──────────────────────────────────────────────────

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final todayStr = _dateStr(today);
      final weekStr = _dateStr(today.add(const Duration(days: 7)));

      final counts = await _repo.fetchFilterDashboardCounts(
        todayStr: todayStr,
        weekStr: weekStr,
      );
      final projectStats = await _projectRepo.fetchProjectsWithTaskStats();

      final projects = projectStats
          .map((r) => _ProjectStat(
                id: r.id,
                name: r.name,
                pending: r.pending,
                total: r.total,
                color: _parseProjectColor(r.colorHex),
                icone: r.iconName,
              ))
          .toList();

      if (mounted) {
        setState(() {
          _overdueCount = counts.overdue;
          _todayCount = counts.today;
          _weekCount = counts.week;
          _completedCount = counts.completedToday;
          _projects = projects;
          _loading = false;
          _statsError = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _statsError = e.toString(); });
    }
  }

  // ── Load tasks for a filter view ───────────────────────────────────────────

  TaskFilterKind? _filterKindForView(_FilterView view) => switch (view) {
        _FilterView.overdue => TaskFilterKind.overdue,
        _FilterView.today => TaskFilterKind.today,
        _FilterView.week => TaskFilterKind.week,
        _FilterView.completed => TaskFilterKind.completedToday,
        _FilterView.dashboard => null,
      };

  /// Abre um filtro específico (usado pela sidebar desktop).
  void openFilter(TaskFilterKind kind) {
    final view = switch (kind) {
      TaskFilterKind.overdue => _FilterView.overdue,
      TaskFilterKind.today => _FilterView.today,
      TaskFilterKind.week => _FilterView.week,
      TaskFilterKind.completedToday => _FilterView.completed,
    };
    _loadFilter(view);
  }

  Future<void> _loadFilter(_FilterView view) async {
    setState(() {
      _view = view;
      _filterLoading = true;
    });

    try {
      final kind = _filterKindForView(view);
      if (kind == null) {
        if (mounted) setState(() => _filterLoading = false);
        return;
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final todayStr = _dateStr(today);
      final weekStr = _dateStr(today.add(const Duration(days: 7)));

      final tasks = await _repo.fetchFilteredTasks(
        kind: kind,
        todayStr: todayStr,
        weekStr: weekStr,
      );

      if (mounted) {
        setState(() {
          _filterTasks = tasks;
          _filterLoading = false;
          _filterError = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _filterLoading = false; _filterError = e.toString(); });
    }
  }

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ── Task actions ───────────────────────────────────────────────────────────

  Future<void> _toggleDone(int i) async {
    final t = _filterTasks[i];
    await _repo.toggleTaskDoneById(t.id, !t.done);
    _loadFilter(_view);
    _loadStats();
  }

  Future<void> _deleteTask(int i) async {
    await _repo.deleteTask(_filterTasks[i].id);
  }

  Future<void> _toggleSubtask(int ti, int si) async {
    final t = _filterTasks[ti];
    final sub = t.subtasks[si];
    final allSubs = await supabase
        .from('subtasks')
        .select()
        .eq('task_id', t.id)
        .order('ordem');
    if (si < allSubs.length) {
      await supabase
          .from('subtasks')
          .update({'concluida': !sub.done})
          .eq('id', allSubs[si]['id']);
      _loadFilter(_view);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDashboard = _view == _FilterView.dashboard;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: Offset(child.key == const ValueKey('dashboard') ? -0.06 : 0.06, 0),
            end: Offset.zero,
          ).animate(anim),
          child: child,
        ),
      ),
      child: KeyedSubtree(
        key: ValueKey(isDashboard ? 'dashboard' : _view.name),
        child: isDashboard ? _buildDashboard() : _buildFilterView(),
      ),
    );
  }

  // ── Dashboard ──────────────────────────────────────────────────────────────

  Widget _buildDashboard() {
    if (!_loading && _statsError != null && _projects.isEmpty) {
      return LoadErrorView(
        onRetry: () {
          setState(() {
            _loading = true;
            _statsError = null;
          });
          _loadStats();
        },
      );
    }

    return TaskListScaffold(
      onRefresh: _loadStats,
      slivers: [
        SliverToBoxAdapter(
          child: ScreenHeader(title: 'Filtros'),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),

        // ── Stat grid ───────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child:           _loading
              ? const SizedBox(
                  height: 160,
                  child: SkeletonLoader(itemCount: 2),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              hugeIcon: HugeIcons.strokeRoundedAlert01,
                              label: 'Atrasadas',
                              count: _overdueCount,
                              colored: true,
                              color: AppColors.priorityHigh,
                              onTap: () => _loadFilter(_FilterView.overdue),
                            ),
                          ),
                          SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: _StatCard(
                              hugeIcon: HugeIcons.strokeRoundedCalendar02,
                              label: 'Hoje',
                              count: _todayCount,
                              onTap: () => _loadFilter(_FilterView.today),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              hugeIcon: HugeIcons.strokeRoundedCalendar03,
                              label: 'Próximos 7 dias',
                              count: _weekCount,
                              onTap: () => _loadFilter(_FilterView.week),
                            ),
                          ),
                          SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: _StatCard(
                              hugeIcon: HugeIcons.strokeRoundedTick01,
                              label: 'Concluídas hoje',
                              count: _completedCount,
                              onTap: () => _loadFilter(_FilterView.completed),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),

        // ── Projects section (mesmo padrão visual da Home) ─────────────────
        if (!_loading) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm,
              ),
              child: Divider(
                height: 1,
                thickness: 1,
                color: AppColors.textTertiary.withValues(alpha: 0.15),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
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
          ),
          if (_projects.isEmpty)
            SliverToBoxAdapter(
              child: EmptyState(
                hugeIcon: HugeIcons.strokeRoundedFolder01,
                title: 'Nenhum projeto',
                subtitle: 'Organize suas tarefas por contexto',
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _ProjectStatRow(project: _projects[i]),
                childCount: _projects.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
        ],

      ],
    );
  }

  // ── Filter list view ───────────────────────────────────────────────────────

  Widget _buildFilterView() {
    if (!_filterLoading && _filterError != null && _filterTasks.isEmpty) {
      return LoadErrorView(
        onRetry: () {
          setState(() => _filterError = null);
          _loadFilter(_view);
        },
      );
    }

    final label = switch (_view) {
      _FilterView.overdue => 'Atrasadas',
      _FilterView.today => 'Hoje',
      _FilterView.week => 'Próximos 7 dias',
      _FilterView.completed => 'Concluídas hoje',
      _FilterView.dashboard => '',
    };
    final color = switch (_view) {
      _FilterView.overdue => AppColors.priorityHigh,
      _FilterView.today => AppColors.accent,
      _FilterView.week => AppColors.accent,
      _FilterView.completed => AppColors.accent,
      _FilterView.dashboard => AppColors.accent,
    };

    return TaskListScaffold(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 20, 8),
            child: Row(
              children: [
                Pressable(
                  onTap: () => setState(() {
                    _view = _FilterView.dashboard;
                  }),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: HugeIcon(icon: HugeIcons.strokeRoundedArrowLeft01,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          color: color,
                        ),
                  ),
                ),
                Text(
                  '${_filterTasks.length}',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 4)),

        if (_filterLoading)
          const SliverToBoxAdapter(
            child: SizedBox(height: 280, child: SkeletonLoader(itemCount: 4)),
          )
        else if (_filterTasks.isEmpty)
          SliverToBoxAdapter(
            child: EmptyState(
              hugeIcon: HugeIcons.strokeRoundedCheckmarkCircle02,
              title: 'Nenhuma tarefa aqui',
              subtitle: 'Tudo em dia nesta categoria',
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => RepaintBoundary(
                key: ValueKey('rb_${_filterTasks[i].id}'),
                child: SwipeableTaskTile(
                  key: ValueKey(_filterTasks[i].id),
                  task: _filterTasks[i],
                  onCompleted: () => _toggleDone(i),
                  onDeleteRequested: () => _deleteTask(i),
                  onEdit: () => showTaskDetailSheet(
                      ctx, _filterTasks[i],
                      onSaved: () => _loadFilter(_view)),
                  onRefresh: () => _loadFilter(_view),
                  child: TaskTile(
                    task: _filterTasks[i],
                    onSubtaskToggled: (si) => _toggleSubtask(i, si),
                    onCompleted: () => _toggleDone(i),
                    onTap: () => showTaskDetailSheet(
                        ctx, _filterTasks[i],
                        onSaved: () => _loadFilter(_view)),
                  ),
                ),
              ),
              findChildIndexCallback: (key) {
                final id = (key as ValueKey<String>).value;
                final i = _filterTasks.indexWhere((t) => t.id == id);
                return i == -1 ? null : i;
              },
              childCount: _filterTasks.length,
            ),
          ),

      ],
    );
  }
}

// ── Stat card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final List<List<dynamic>> hugeIcon;
  final String label;
  final int count;
  final bool colored;
  final Color color;
  final VoidCallback onTap;

  _StatCard({
    required this.hugeIcon,
    required this.label,
    required this.count,
    this.colored = false,
    Color? color,
    required this.onTap,
  }) : color = color ?? AppColors.accent;

  @override
  Widget build(BuildContext context) {
    final countLabel = count == 1 ? '1 tarefa' : '$count tarefas';
    final hasCount = count > 0;
    final iconColor = colored ? color : AppColors.textPrimary;
    final iconBg = colored
        ? color.withValues(alpha: 0.14)
        : AppColors.surfaceVariant.withValues(alpha: 0.45);

    return Semantics(
      button: true,
      label: '$label, $countLabel',
      child: Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md + 2),
          decoration: BoxDecoration(
            color: colored && hasCount
                ? color.withValues(alpha: 0.07)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: colored && hasCount
                  ? color.withValues(alpha: 0.22)
                  : AppColors.textTertiary.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: HugeIcon(icon: hugeIcon, size: 20, color: iconColor),
                    ),
                  ),
                  const Spacer(),
                  if (hasCount)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colored
                            ? color.withValues(alpha: 0.16)
                            : AppColors.textTertiary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: colored ? color : AppColors.textTertiary,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                hasCount ? countLabel : 'Nenhuma',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Project stat row ──────────────────────────────────────────────────────────

class _ProjectStatRow extends StatelessWidget {
  final _ProjectStat project;
  const _ProjectStatRow({required this.project});

  static final _countStyle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: AppColors.textTertiary,
  );

  @override
  Widget build(BuildContext context) {
    final color = project.color;
    final done = project.total - project.pending;
    final progress =
        project.total == 0 ? 0.0 : done / project.total;

    return Semantics(
      button: true,
      label:
          'Projeto ${project.name}, ${project.pending} pendentes de ${project.total}',
      child: Pressable(
        onTap: () {
          HapticService().selectionClick();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProjectDetailScreen(
                projectId: project.id,
                projectName: project.name,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: 13,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: Center(
                  child: HugeIcon(
                    icon: ProjectIcons.resolve(project.icone),
                    size: 22,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (project.total > 0) ...[
                      const SizedBox(height: 7),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 3,
                          backgroundColor:
                              AppColors.textTertiary.withValues(alpha: 0.12),
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text('${project.pending}', style: _countStyle),
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
