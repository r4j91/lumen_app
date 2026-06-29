import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/project_repository.dart';
import '../services/task_repository.dart';
import '../services/task_sync.dart';
import '../services/supabase_client.dart';
import '../theme/app_layout.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_sheet.dart';
import '../widgets/pressable.dart';
import '../widgets/swipeable_task_tile.dart';
import '../widgets/task_tile.dart';
import 'task_detail_sheet.dart';
import '../widgets/scroll_fade_overlay.dart';
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
  State<FiltersScreen> createState() => _FiltersScreenState();
}

class _FiltersScreenState extends State<FiltersScreen> {
  static const _repo = TaskRepository();
  static const _projectRepo = ProjectRepository();
  // Dashboard stats
  bool _loading = true;
  int _overdueCount = 0;
  int _todayCount = 0;
  int _weekCount = 0;
  int _completedCount = 0;
  List<_ProjectStat> _projects = [];

  // Filter drill-down
  _FilterView _view = _FilterView.dashboard;
  List<Task> _filterTasks = [];
  bool _filterLoading = false;

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
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
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
        });
      }
    } catch (_) {
      if (mounted) setState(() => _filterLoading = false);
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
    final bottomInset = AppLayout.bottomListInset(context);

    return ScrollFadeOverlay(child: CustomScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl),
            child: Text(
              'Filtros',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
          ),
        ),

        // ── Stat grid ───────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: _loading
              ? SizedBox(
                  height: 160,
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  ),
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
                              color: AppColors.priorityHigh,
                              onTap: () => _loadFilter(_FilterView.overdue),
                            ),
                          ),
                          SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: _StatCard(
                              hugeIcon: HugeIcons.strokeRoundedCalendar01,
                              label: 'Hoje',
                              count: _todayCount,
                              color: AppColors.accent,
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
                              color: AppColors.tagPurple,
                              onTap: () => _loadFilter(_FilterView.week),
                            ),
                          ),
                          SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: _StatCard(
                              hugeIcon: HugeIcons.strokeRoundedTaskDone01,
                              label: 'Concluídas hoje',
                              count: _completedCount,
                              color: AppColors.tagGreen,
                              onTap: () => _loadFilter(_FilterView.completed),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 28)),

        // ── Projects section ─────────────────────────────────────────────────
        if (!_loading) ...[
          SliverToBoxAdapter(
            child: AppSectionLabel(
              'PROJETOS',
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
            ),
          ),
          if (_projects.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: Text(
                  'Nenhum projeto criado ainda.',
                  style: TextStyle(fontSize: 14, color: AppColors.textTertiary),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _ProjectStatRow(project: _projects[i]),
                childCount: _projects.length,
              ),
            ),
        ],

        SliverToBoxAdapter(child: SizedBox(height: bottomInset)),
      ],
    ));
  }

  // ── Filter list view ───────────────────────────────────────────────────────

  Widget _buildFilterView() {
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
      _FilterView.week => AppColors.tagPurple,
      _FilterView.completed => AppColors.tagGreen,
      _FilterView.dashboard => AppColors.accent,
    };
    final bottomInset = AppLayout.bottomListInset(context);

    return ScrollFadeOverlay(child: CustomScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
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
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(
                  child: CircularProgressIndicator(color: AppColors.accent)),
            ),
          )
        else if (_filterTasks.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Column(
                children: [
                  HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                      size: 44, color: AppColors.textTertiary),
                  const SizedBox(height: 12),
                  Text(
                    'Nenhuma tarefa aqui',
                    style: TextStyle(
                        fontSize: 15, color: AppColors.textTertiary),
                  ),
                ],
              ),
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

        SliverToBoxAdapter(child: SizedBox(height: bottomInset)),
      ],
    ));
  }
}

// ── Stat card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final List<List<dynamic>> hugeIcon;
  final String label;
  final int count;
  final Color color;
  final VoidCallback onTap;

  const _StatCard({
    required this.hugeIcon,
    required this.label,
    required this.count,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: count > 0 ? color.withValues(alpha: 0.2) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: HugeIcon(icon: hugeIcon, size: 17, color: color),
                ),
                const Spacer(),
                if (count > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              count == 0
                  ? 'Nenhuma'
                  : '$count ${count == 1 ? 'tarefa' : 'tarefas'}',
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Project stat row ──────────────────────────────────────────────────────────

class _ProjectStatRow extends StatelessWidget {
  final _ProjectStat project;
  const _ProjectStatRow({required this.project});

  @override
  Widget build(BuildContext context) {
    final color = project.color;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.cardSm,
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceVariant.withValues(alpha: 0.45),
                border: Border.all(color: color.withValues(alpha: 0.75), width: 2),
              ),
              child: Center(
                child: HugeIcon(
                  icon: ProjectIcons.resolve(project.icone),
                  size: 16,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: project.total == 0
                          ? 0
                          : (project.total - project.pending) / project.total,
                      minHeight: 4,
                      backgroundColor: AppColors.surfaceVariant,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.textTertiary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${project.pending}/${project.total}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
            const SizedBox(width: 14),
          ],
        ),
      ),
    );
  }
}
