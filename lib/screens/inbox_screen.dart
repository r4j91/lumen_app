import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';
import '../services/notification_service.dart';
import '../services/task_repository.dart';
import '../services/task_sync.dart';
import '../services/supabase_client.dart';
import '../screens/task_detail_sheet.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_sheet.dart';
import '../widgets/empty_state.dart';
import '../widgets/swipeable_task_tile.dart';
import '../widgets/task_tile.dart';
import '../widgets/scroll_fade_overlay.dart';
import 'package:hugeicons/hugeicons.dart';

const _kInboxShowCompletedKey = 'inbox_show_completed';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => InboxScreenState();
}

class InboxScreenState extends State<InboxScreen> {
  final _repo = TaskRepository();
  List<Task> _tasks = [];
  List<Task> _completedTasks = [];
  bool _loading = true;
  bool _showCompleted = true;
  bool _completedExpanded = false;
  late final ScrollController _scrollCtrl;

  @override
  void initState() {
    super.initState();
    _scrollCtrl = ScrollController();
    _loadPrefs();
    loadTasks();
    TaskSync.instance.addListener(loadTasks);
  }

  @override
  void dispose() {
    TaskSync.instance.removeListener(loadTasks);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void scrollToTop() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
    }
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _showCompleted = prefs.getBool(_kInboxShowCompletedKey) ?? true);
    }
  }

  Future<void> _setShowCompleted(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kInboxShowCompletedKey, value);
    if (mounted) setState(() => _showCompleted = value);
  }

  Future<void> loadTasks() async {
    final results = await Future.wait([
      _repo.fetchInboxTasks(),
      _repo.fetchCompletedInboxTasks(),
    ]);
    if (mounted) {
      setState(() {
        _tasks = results[0];
        _completedTasks = results[1];
        _loading = false;
      });
    }
  }

  void _toggleDone(int i) {
    final task = _tasks[i];
    if (task.done) return;
    final updated = task.copyWith(done: true);
    setState(() => _tasks[i] = updated);
    supabase.from('tasks').update({'concluida': true}).eq('id', task.id).catchError((_) {
      if (mounted) setState(() => _tasks[i] = task);
    });
    NotificationService().cancelTaskNotification(task.id);
  }

  Future<void> _deleteTask(int i) async {
    final task = _tasks[i];
    setState(() => _tasks.removeAt(i));
    try {
      await _repo.deleteTask(task.id);
    } catch (_) {
      if (mounted) setState(() => _tasks.insert(i.clamp(0, _tasks.length), task));
    }
  }

  void _toggleUndone(int i) {
    final task = _completedTasks[i];
    final updated = task.copyWith(done: false);
    setState(() {
      _completedTasks.removeAt(i);
      _tasks.add(updated);
    });
    supabase.from('tasks').update({'concluida': false}).eq('id', task.id).catchError((_) {
      if (mounted) {
        setState(() {
          _tasks.removeWhere((t) => t.id == task.id);
          _completedTasks.insert(i.clamp(0, _completedTasks.length), task);
        });
      }
    });
  }

  Future<void> _deleteCompletedTask(int i) async {
    final task = _completedTasks[i];
    setState(() => _completedTasks.removeAt(i));
    try {
      await _repo.deleteTask(task.id);
    } catch (_) {
      if (mounted) setState(() => _completedTasks.insert(i.clamp(0, _completedTasks.length), task));
    }
  }

  Future<void> _toggleSubtask(int ti, int si) async {
    final t = _tasks[ti];
    final allSubs = await supabase
        .from('subtasks')
        .select()
        .eq('task_id', t.id)
        .order('ordem');
    if (si < allSubs.length) {
      final newDone = !(allSubs[si]['concluida'] as bool? ?? false);
      await supabase
          .from('subtasks')
          .update({'concluida': newDone})
          .eq('id', allSubs[si]['id']);
      loadTasks();
    }
  }

  void _showOptionsMenu(BuildContext ctx) {
    final renderBox = ctx.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    showMenu<String>(
      context: ctx,
      color: AppColors.surfaceVariant,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      position: RelativeRect.fromLTRB(
        offset.dx + size.width - 180,
        offset.dy + size.height + 4,
        16,
        0,
      ),
      items: [
        PopupMenuItem(
          value: 'toggle_completed',
          child: Row(
            children: [
              HugeIcon(
                icon: _showCompleted
                    ? HugeIcons.strokeRoundedViewOff
                    : HugeIcons.strokeRoundedView,
                size: 17,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 10),
              Text(
                _showCompleted ? 'Ocultar concluídas' : 'Mostrar concluídas',
                style: TextStyle(fontSize: 13.5, color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'toggle_completed') _setShowCompleted(!_showCompleted);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom + 88;

    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: AppColors.surface,
      onRefresh: loadTasks,
      child: ScrollFadeOverlay(child: CustomScrollView(
      controller: _scrollCtrl,
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.sm, AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Caixa de entrada', style: Theme.of(context).textTheme.headlineLarge),
                      const SizedBox(height: 2),
                      Text(
                        '${_tasks.length} ${_tasks.length == 1 ? 'tarefa' : 'tarefas'}',
                        style: TextStyle(fontSize: 12.5, color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ),
                Builder(
                  builder: (ctx) => IconButton(
                    icon: HugeIcon(icon: HugeIcons.strokeRoundedMoreHorizontal, color: AppColors.textSecondary),
                    onPressed: () => _showOptionsMenu(ctx),
                    tooltip: 'Opções',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),

        if (_loading)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2)),
            ),
          )
        else if (_tasks.isEmpty && _completedTasks.isEmpty)
          const SliverToBoxAdapter(
            child: EmptyState(
              hugeIcon: HugeIcons.strokeRoundedInbox,
              title: 'Inbox limpo',
              subtitle: 'Nenhuma tarefa sem data ou projeto',
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => RepaintBoundary(
                key: ValueKey('rb_${_tasks[i].id}'),
                child: SwipeableTaskTile(
                  key: ValueKey(_tasks[i].id),
                  task: _tasks[i],
                  onCompleted: () => _toggleDone(i),
                  onDeleteRequested: () => _deleteTask(i),
                  onEdit: () => showTaskDetailSheet(context, _tasks[i], onSaved: loadTasks),
                  onRefresh: loadTasks,
                  child: TaskTile(
                    task: _tasks[i],
                    onSubtaskToggled: (si) => _toggleSubtask(i, si),
                    onCompleted: () => _toggleDone(i),
                    onTap: () => showTaskDetailSheet(context, _tasks[i], onSaved: loadTasks),
                    onDismissed: () {
                      if (!mounted) return;
                      final t = _tasks[i];
                      setState(() {
                        _tasks.removeWhere((x) => x.id == t.id);
                        if (!_completedTasks.any((x) => x.id == t.id)) {
                          _completedTasks = [t.copyWith(done: true), ..._completedTasks];
                        }
                      });
                    },
                  ),
                ),
              ),
              findChildIndexCallback: (key) {
                final id = (key as ValueKey<String>).value.replaceFirst('rb_', '');
                final i = _tasks.indexWhere((t) => t.id == id);
                return i == -1 ? null : i;
              },
              childCount: _tasks.length,
            ),
          ),

        // ── Completed section ────────────────────────────────────────────────
        if (_showCompleted && _completedTasks.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: CompletedSectionHeader(
              count: _completedTasks.length,
              expanded: _completedExpanded,
              onTap: () => setState(() => _completedExpanded = !_completedExpanded),
            ),
          ),
          if (_completedExpanded)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => RepaintBoundary(
                  key: ValueKey('rb_done_${_completedTasks[i].id}'),
                  child: SwipeableTaskTile(
                    task: _completedTasks[i],
                    onDeleteRequested: () => _deleteCompletedTask(i),
                    onEdit: () => showTaskDetailSheet(context, _completedTasks[i], onSaved: loadTasks),
                    onRefresh: loadTasks,
                    child: TaskTile(
                      task: _completedTasks[i],
                      onSubtaskToggled: (_) {},
                      onCompleted: () => _toggleUndone(i),
                      onTap: () => showTaskDetailSheet(context, _completedTasks[i], onSaved: loadTasks),
                    ),
                  ),
                ),
                childCount: _completedTasks.length,
              ),
            ),
        ],

        SliverToBoxAdapter(child: SizedBox(height: bottomInset)),
      ],
    )));
  }
}
