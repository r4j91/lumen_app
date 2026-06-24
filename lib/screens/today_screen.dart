import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';
import '../models/subtask.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_sheet.dart';
import '../widgets/empty_state.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/swipeable_task_tile.dart';
import '../widgets/task_tile.dart';
import '../services/notification_service.dart';
import '../services/task_repository.dart';
import '../services/supabase_client.dart';
import 'task_detail_sheet.dart';

const _kShowCompletedKey = 'today_show_completed';

// Top-level constants — avoids allocating new lists on every _formatDate call.
const _kWeekdays = [
  'Segunda-feira', 'Terça-feira', 'Quarta-feira',
  'Quinta-feira', 'Sexta-feira', 'Sábado', 'Domingo',
];
const _kMonths = [
  'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
  'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
];

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => TodayScreenState();
}

class TodayScreenState extends State<TodayScreen> {
  List<Task> _tasks = [];
  List<Task> _completedTasks = [];
  bool _loading = true;
  String? _error;
  late final ScrollController _scrollCtrl;

  // SharedPreferences-backed preferences
  bool _showCompleted = true;   // section visible (toggle from menu)
  bool _completedExpanded = false; // section collapsed/expanded

  @override
  void initState() {
    super.initState();
    _scrollCtrl = ScrollController();
    _loadPrefs();
    _loadTasks();
  }

  void scrollToTop() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
    }
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _showCompleted = prefs.getBool(_kShowCompletedKey) ?? true;
      });
    }
  }

  Future<void> _setShowCompleted(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kShowCompletedKey, value);
    if (mounted) setState(() => _showCompleted = value);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> loadTasks() => _loadTasks();

  Future<void> _loadTasks() async {
    try {
      final repo = TaskRepository();
      final results = await Future.wait([
        repo.fetchTodayTasks(),
        repo.fetchCompletedTodayTasks(),
      ]);
      if (mounted) {
        setState(() {
          _tasks = results[0];
          _completedTasks = results[1];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _toggleDone(int taskIndex) {
    final task = _tasks[taskIndex];
    if (task.done) return; // already completing via animation, ignore
    final newDone = !task.done;
    setState(() => _tasks[taskIndex] = task.copyWith(done: newDone));
    supabase.from('tasks').update({'concluida': newDone}).eq('id', task.id).catchError((_) {
      if (mounted) setState(() => _tasks[taskIndex] = task);
    });
    if (newDone) {
      NotificationService().cancelTaskNotification(task.id);
      if (task.recurrence != null && task.dueDate != null) {
        _createNextOccurrence(task);
      }
      // Removal is handled by TaskTile.onDismissed after animation completes.
    }
  }

  Future<void> _createNextOccurrence(Task task) async {
    final nextDate = task.recurrence!.nextDate(task.dueDate!);
    if (nextDate == null) return;

    final userId = supabase.auth.currentUser?.id;
    final dateStr =
        '${nextDate.year}-${nextDate.month.toString().padLeft(2, '0')}-${nextDate.day.toString().padLeft(2, '0')}';

    final prioStr = switch (task.priority) {
      Priority.high => 'high',
      Priority.medium => 'medium',
      Priority.low => 'low',
      null => null,
    };

    try {
      final inserted = await supabase
          .from('tasks')
          .insert({
            'titulo': task.title,
            'descricao': task.description,
            'prioridade': prioStr,
            'hora': task.time,
            'concluida': false,
            'data_vencimento': dateStr,
            'recorrencia': jsonEncode(task.recurrence!.toJson()),
            if (userId != null) 'user_id': userId,
          })
          .select('id')
          .single();

      final newId = inserted['id'].toString();

      if (task.labels.isNotEmpty) {
        await supabase.from('task_labels').insert(
          task.labels.map((l) => {'task_id': newId, 'label_id': l.id}).toList(),
        );
      }

      if (mounted) _loadTasks();
    } catch (e) {
      debugPrint('[Recurrence] erro ao criar próxima ocorrência: $e');
    }
  }

  Future<void> _deleteTask(int index) async {
    if (!mounted) return;
    final task = _tasks[index];
    setState(() => _tasks.removeAt(index));

    bool undone = false;
    final messenger = ScaffoldMessenger.of(context);
    final ctrl = messenger.showSnackBar(SnackBar(
      content: Text('"${task.title}" excluída'),
      duration: const Duration(seconds: 5),
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.surfaceVariant,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      action: SnackBarAction(
        label: 'Desfazer',
        textColor: AppColors.accent,
        onPressed: () {
          undone = true;
          if (mounted) setState(() => _tasks.insert(index.clamp(0, _tasks.length), task));
        },
      ),
    ));

    await ctrl.closed;
    if (!undone) {
      try {
        await supabase.from('tasks').delete().eq('id', task.id);
        NotificationService().cancelTaskNotification(task.id);
      } catch (e) {
        if (mounted) {
          setState(() => _tasks.insert(index.clamp(0, _tasks.length), task));
          messenger.showSnackBar(SnackBar(
            content: Text('Erro ao excluir: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.priorityHigh,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ));
        }
      }
    }
  }

  void _toggleUndone(int index) {
    final task = _completedTasks[index];
    final updated = task.copyWith(done: false);
    setState(() {
      _completedTasks.removeAt(index);
      _tasks.add(updated);
    });
    supabase.from('tasks').update({'concluida': false}).eq('id', task.id).catchError((_) {
      if (mounted) {
        setState(() {
          _tasks.removeWhere((t) => t.id == task.id);
          _completedTasks.insert(index.clamp(0, _completedTasks.length), task);
        });
      }
    });
  }

  Future<void> _deleteCompletedTask(int index) async {
    if (!mounted) return;
    final task = _completedTasks[index];
    setState(() => _completedTasks.removeAt(index));

    bool undone = false;
    final messenger = ScaffoldMessenger.of(context);
    final ctrl = messenger.showSnackBar(SnackBar(
      content: Text('"${task.title}" excluída'),
      duration: const Duration(seconds: 5),
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.surfaceVariant,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      action: SnackBarAction(
        label: 'Desfazer',
        textColor: AppColors.accent,
        onPressed: () {
          undone = true;
          if (mounted) setState(() => _completedTasks.insert(index.clamp(0, _completedTasks.length), task));
        },
      ),
    ));

    await ctrl.closed;
    if (!undone) {
      try {
        await supabase.from('tasks').delete().eq('id', task.id);
      } catch (e) {
        if (mounted) {
          setState(() => _completedTasks.insert(index.clamp(0, _completedTasks.length), task));
          messenger.showSnackBar(SnackBar(
            content: Text('Erro ao excluir: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.priorityHigh,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ));
        }
      }
    }
  }

  void _toggleSubtask(int taskIndex, int subtaskIndex) {
    final task = _tasks[taskIndex];
    final updated = List<Subtask>.from(task.subtasks);
    updated[subtaskIndex] = updated[subtaskIndex].copyWith(done: !updated[subtaskIndex].done);
    // copyWith preserves all fields (done, recurrence, projectId, createdAt, updatedAt)
    setState(() {
      _tasks[taskIndex] = task.copyWith(subtasks: updated);
    });
    final sub = updated[subtaskIndex];
    supabase
        .from('subtasks')
        .select('id')
        .eq('task_id', task.id)
        .order('ordem')
        .then((rows) {
      if (subtaskIndex < rows.length) {
        supabase
            .from('subtasks')
            .update({'concluida': sub.done})
            .eq('id', rows[subtaskIndex]['id']);
      }
    }).catchError((_) {});
  }

  void _showOptionsMenu(BuildContext context) {
    final renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    showMenu<String>(
      context: context,
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
              Icon(
                _showCompleted ? Icons.visibility_off_outlined : Icons.visibility_outlined,
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
      if (value == 'toggle_completed') {
        _setShowCompleted(!_showCompleted);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SkeletonLoader();

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceVariant,
                ),
                child: Icon(Icons.wifi_off_outlined, size: 34, color: AppColors.textTertiary),
              ),
              const SizedBox(height: 20),
              Text(
                'Sem conexão',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary, height: 1.3),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Verifique sua conexão e tente novamente.',
                style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () { setState(() { _loading = true; _error = null; }); _loadTasks(); },
                style: TextButton.styleFrom(foregroundColor: AppColors.accent),
                child: const Text('Tentar novamente', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      );
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateLabel = _formatDate(now);
    final bottomInset = MediaQuery.of(context).padding.bottom + 88;

    // Split into overdue (before today) and today.
    // Precompute index map to avoid O(n) indexOf inside the SliverList builder.
    final overdue = <Task>[];
    final todayTasks = <Task>[];
    final taskIndexMap = <String, int>{};
    for (var i = 0; i < _tasks.length; i++) {
      final t = _tasks[i];
      taskIndexMap[t.id] = i;
      if (t.dueDate != null && t.dueDate!.isBefore(today)) {
        overdue.add(t);
      } else if (t.dueDate != null) {
        todayTasks.add(t);
      }
    }

    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: AppColors.surface,
      onRefresh: _loadTasks,
      child: CustomScrollView(
      controller: _scrollCtrl,
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        // ── Header ──────────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hoje', style: Theme.of(context).textTheme.headlineLarge),
                      const SizedBox(height: 2),
                      Text(dateLabel, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                Builder(
                  builder: (ctx) => IconButton(
                    icon: Icon(Icons.more_horiz, color: AppColors.textSecondary),
                    onPressed: () => _showOptionsMenu(ctx),
                    tooltip: 'Opções',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),

        // ── Empty state ───────────────────────────────────────────────────────
        if (_tasks.isEmpty && _completedTasks.isEmpty)
          const SliverToBoxAdapter(
            child: EmptyState(
              icon: Icons.wb_sunny_outlined,
              title: 'Nenhuma tarefa para hoje',
              subtitle: 'Aproveite o dia livre',
            ),
          ),

        // ── Atrasadas ─────────────────────────────────────────────────────────
        if (overdue.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: AppSectionLabel(
              'ATRASADAS',
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.sm),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final task = overdue[i];
                final idx = taskIndexMap[task.id]!;
                return RepaintBoundary(
                  key: ValueKey('rb_${task.id}'),
                  child: SwipeableTaskTile(
                    key: ValueKey(task.id),
                    task: task,
                    onCompleted: () => _toggleDone(idx),
                    onDeleteRequested: () => _deleteTask(idx),
                    onEdit: () => showTaskDetailSheet(context, task, onSaved: _loadTasks),
                    onRefresh: _loadTasks,
                    child: TaskTile(
                      task: task,
                      onSubtaskToggled: (si) => _toggleSubtask(idx, si),
                      onCompleted: () => _toggleDone(idx),
                      onTap: () => showTaskDetailSheet(context, task, onSaved: _loadTasks),
                      onDismissed: () {
                        if (!mounted) return;
                        final t = task;
                        setState(() {
                          _tasks.removeWhere((x) => x.id == t.id);
                          if (!_completedTasks.any((x) => x.id == t.id)) {
                            _completedTasks = [t.copyWith(done: true), ..._completedTasks];
                          }
                        });
                      },
                    ),
                  ),
                );
              },
              findChildIndexCallback: (key) {
                final id = (key as ValueKey<String>).value;
                final i = overdue.indexWhere((t) => t.id == id);
                return i == -1 ? null : i;
              },
              childCount: overdue.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
        ],

        // ── Hoje ─────────────────────────────────────────────────────────────
        if (todayTasks.isNotEmpty) ...[
          if (overdue.isNotEmpty)
            SliverToBoxAdapter(
              child: AppSectionLabel(
                'HOJE',
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.sm),
              ),
            ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final task = todayTasks[i];
                final idx = taskIndexMap[task.id]!;
                return RepaintBoundary(
                  key: ValueKey('rb_${task.id}'),
                  child: SwipeableTaskTile(
                    key: ValueKey(task.id),
                    task: task,
                    onCompleted: () => _toggleDone(idx),
                    onDeleteRequested: () => _deleteTask(idx),
                    onEdit: () => showTaskDetailSheet(context, task, onSaved: _loadTasks),
                    onRefresh: _loadTasks,
                    child: TaskTile(
                      task: task,
                      onSubtaskToggled: (si) => _toggleSubtask(idx, si),
                      onCompleted: () => _toggleDone(idx),
                      onTap: () => showTaskDetailSheet(context, task, onSaved: _loadTasks),
                      onDismissed: () {
                        if (!mounted) return;
                        final t = task;
                        setState(() {
                          _tasks.removeWhere((x) => x.id == t.id);
                          if (!_completedTasks.any((x) => x.id == t.id)) {
                            _completedTasks = [t.copyWith(done: true), ..._completedTasks];
                          }
                        });
                      },
                    ),
                  ),
                );
              },
              findChildIndexCallback: (key) {
                final id = (key as ValueKey<String>).value;
                final i = todayTasks.indexWhere((t) => t.id == id);
                return i == -1 ? null : i;
              },
              childCount: todayTasks.length,
            ),
          ),
        ],

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
                  key: ValueKey('rb_${_completedTasks[i].id}'),
                  child: SwipeableTaskTile(
                    task: _completedTasks[i],
                    onDeleteRequested: () => _deleteCompletedTask(i),
                    onEdit: () => showTaskDetailSheet(context, _completedTasks[i], onSaved: _loadTasks),
                    onRefresh: _loadTasks,
                    child: TaskTile(
                      task: _completedTasks[i],
                      onSubtaskToggled: (_) {},
                      onCompleted: () => _toggleUndone(i),
                      onTap: () => showTaskDetailSheet(context, _completedTasks[i], onSaved: _loadTasks),
                    ),
                  ),
                ),
                childCount: _completedTasks.length,
              ),
            ),
        ],

        SliverToBoxAdapter(child: SizedBox(height: bottomInset)),
      ],
    ));
  }

  String _formatDate(DateTime date) =>
      '${_kWeekdays[date.weekday - 1]}, ${date.day} de ${_kMonths[date.month - 1]}';
}

