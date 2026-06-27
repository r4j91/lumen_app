import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/subtask.dart';
import '../models/task.dart';
import '../services/supabase_client.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_sheet.dart';
import '../widgets/modal_media_query.dart';
import '../widgets/empty_state.dart';
import '../widgets/pressable.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/swipeable_task_tile.dart';
import '../widgets/project_options_sheet.dart';
import '../widgets/task_tile.dart';
import 'task_detail_sheet.dart';
import 'package:hugeicons/hugeicons.dart';

class _ProjectMeta {
  final String id;
  final String name;
  final String? description;
  final int tasksDone;
  final int tasksTotal;
  const _ProjectMeta({required this.id, required this.name, this.description, required this.tasksDone, required this.tasksTotal});
}

// ── Projects list screen ───────────────────────────────────────────────────────

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  List<_ProjectMeta> _projects = [];
  bool _loading = true;
  _ProjectMeta? _selected; // quando != null, mostra detalhe inline

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    try {
      final rows = await supabase
          .from('projects')
          .select('id, nome, descricao, tasks(concluida)')
          .order('nome');
      final projects = (rows as List).map((r) {
        final tasks = (r['tasks'] as List?) ?? [];
        return _ProjectMeta(
          id: r['id'].toString(),
          name: r['nome'] as String,
          description: r['descricao'] as String?,
          tasksDone: tasks.where((t) => t['concluida'] == true).length,
          tasksTotal: tasks.length,
        );
      }).toList();
      if (mounted) setState(() { _projects = projects; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showAddProject() async {
    await Navigator.of(context, rootNavigator: true).push(
      ModalSheetRoute<void>(
        builder: (_) => _AddProjectSheet(onCreated: _loadProjects),
      ),
    );
  }

  void _showProjectOptions(_ProjectMeta project) {
    Navigator.of(context, rootNavigator: true).push(
      ModalSheetRoute<void>(
        builder: (_) => ProjectOptionsSheet(
          project: ProjectSheetData(id: project.id, name: project.name),
          onEdited: _loadProjects,
          onDeleted: _loadProjects,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Detalhe inline — sem push de rota, pill nav permanece visível
    if (_selected != null) {
      return _InlineProjectDetail(
        projectId: _selected!.id,
        projectName: _selected!.name,
        onBack: () => setState(() { _selected = null; _loadProjects(); }),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
          child: Row(
            children: [
              Expanded(child: Text('Projetos', style: Theme.of(context).textTheme.headlineLarge)),
              IconButton(
                icon: HugeIcon(icon: HugeIcons.strokeRoundedAdd01, color: AppColors.accent),
                tooltip: 'Adicionar projeto',
                onPressed: _showAddProject,
              ),
            ],
          ),
        ),
        if (_loading)
          const Expanded(child: SkeletonLoader(itemCount: 4))
        else if (_projects.isEmpty)
          const Expanded(
            child: EmptyState(
              icon: Icons.folder_open,
              title: 'Nenhum projeto ainda',
              subtitle: 'Crie projetos para organizar suas tarefas por contexto ou objetivo.',
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              padding: EdgeInsets.fromLTRB(12, 0, 12, MediaQuery.of(context).padding.bottom + 90),
              itemCount: _projects.length,
              itemBuilder: (ctx, i) => _ProjectCard(
                project: _projects[i],
                onTap: () => setState(() => _selected = _projects[i]),
                onLongPress: () => _showProjectOptions(_projects[i]),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Detalhe de projeto inline (sem Scaffold próprio) ──────────────────────────

class _InlineProjectDetail extends StatefulWidget {
  final String projectId;
  final String projectName;
  final VoidCallback onBack;

  const _InlineProjectDetail({
    required this.projectId,
    required this.projectName,
    required this.onBack,
  });

  @override
  State<_InlineProjectDetail> createState() => _InlineProjectDetailState();
}

class _InlineProjectDetailState extends State<_InlineProjectDetail> {
  List<Task> _tasks = [];
  List<Task> _completedTasks = [];
  bool _loading = true;
  bool _showCompleted = true;
  bool _completedExpanded = false;

  String get _prefsKey => 'proj_show_completed_${widget.projectId}';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _loadTasks();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _showCompleted = prefs.getBool(_prefsKey) ?? true);
  }

  Future<void> _setShowCompleted(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, value);
    if (mounted) setState(() => _showCompleted = value);
  }

  Future<void> _loadTasks() async {
    try {
      final rows = await supabase
          .from('tasks')
          .select('id, titulo, descricao, prioridade, hora, ordem, concluida, projects(nome), subtasks(titulo, descricao, concluida, ordem, prioridade), task_labels(labels(id, nome, cor))')
          .eq('project_id', widget.projectId)
          .order('concluida', ascending: true)
          .order('ordem');

      final tasks = (rows as List).map((r) {
        final sub = ((r['subtasks'] as List?) ?? [])
          ..sort((a, b) => (a['ordem'] as int? ?? 0).compareTo(b['ordem'] as int? ?? 0));
        final labels = ((r['task_labels'] as List?) ?? [])
            .map((tl) {
              final l = tl['labels'] as Map?;
              if (l == null) return null;
              final nome = l['nome'] as String? ?? '';
              if (nome.isEmpty) return null;
              return TaskLabel(
                id: l['id']?.toString() ?? '',
                name: nome,
                color: AppColors.parseHex(l['cor'] as String?),
                              );
            })
            .whereType<TaskLabel>()
            .toList();
        return Task(
          id: r['id'].toString(),
          title: r['titulo'] as String,
          project: (r['projects'] as Map?)?['nome'] as String? ?? widget.projectName,
          priority: switch (r['prioridade'] as String?) {
            'high' => Priority.high,
            'medium' => Priority.medium,
            _ => Priority.low,
          },
          time: r['hora'] as String?,
          description: r['descricao'] as String?,
          labels: labels,
          subtasks: sub.map((s) => Subtask(
            title: s['titulo'] as String,
            description: s['descricao'] as String?,
            done: s['concluida'] as bool? ?? false,
            priority: switch (s['prioridade'] as String?) { 'high' => SubtaskPriority.high, 'medium' => SubtaskPriority.medium, 'low' => SubtaskPriority.low, _ => null },
          )).toList(),
          done: r['concluida'] as bool? ?? false,
        );
      }).toList();
      if (mounted) {
        setState(() {
          _completedTasks = tasks.where((t) => t.done).toList();
          final pending = tasks.where((t) => !t.done).toList();
          if (_tasks.isEmpty) {
            _tasks = pending;
          } else {
            final byId = {for (final t in pending) t.id: t};
            final updated = _tasks.map((t) => byId[t.id]).whereType<Task>().toList();
            final existingIds = _tasks.map((t) => t.id).toSet();
            final added = pending.where((t) => !existingIds.contains(t.id)).toList();
            _tasks = [...updated, ...added];
          }
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
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
      } catch (e) {
        if (mounted) {
          setState(() => _tasks.insert(index.clamp(0, _tasks.length), task));
          messenger.showSnackBar(SnackBar(content: Text('Erro ao excluir: $e'), behavior: SnackBarBehavior.floating));
        }
      }
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
      await supabase.from('tasks').delete().eq('id', task.id);
    } catch (_) {
      if (mounted) setState(() => _completedTasks.insert(i.clamp(0, _completedTasks.length), task));
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
      if (value == 'toggle_completed') _setShowCompleted(!_showCompleted);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header com botão voltar
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 20, 8),
          child: Row(
            children: [
              IconButton(
                icon: HugeIcon(icon: HugeIcons.strokeRoundedArrowLeft01, size: 18, color: AppColors.textSecondary),
                onPressed: widget.onBack,
              ),
              Expanded(
                child: Text(widget.projectName, style: Theme.of(context).textTheme.headlineLarge),
              ),
              IconButton(
                icon: HugeIcon(icon: HugeIcons.strokeRoundedAdd01, color: AppColors.accent),
                onPressed: () => showNewTaskSheet(context, onSaved: _loadTasks),
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
        if (_loading)
          const Expanded(child: SkeletonLoader())
        else if (_tasks.isEmpty && _completedTasks.isEmpty)
          const Expanded(
            child: EmptyState(
              icon: Icons.task_alt,
              title: 'Nenhuma tarefa ainda',
              subtitle: 'Adicione tarefas a este projeto usando o botão acima.',
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              padding: EdgeInsets.fromLTRB(0, 4, 0, MediaQuery.of(context).padding.bottom + 90),
              itemCount: _tasks.length
                  + (_showCompleted && _completedTasks.isNotEmpty ? 1 : 0)
                  + (_showCompleted && _completedExpanded ? _completedTasks.length : 0),
              itemBuilder: (ctx, i) {
                if (i < _tasks.length) {
                  return RepaintBoundary(
                    key: ValueKey('rb_${_tasks[i].id}'),
                    child: SwipeableTaskTile(
                      key: ValueKey(_tasks[i].id),
                      task: _tasks[i],
                      onCompleted: () => _toggleDone(i),
                      onDeleteRequested: () => _deleteTask(i),
                      onEdit: () => showTaskDetailSheet(ctx, _tasks[i], onSaved: _loadTasks),
                      onRefresh: _loadTasks,
                      child: TaskTile(
                        task: _tasks[i],
                        showProject: false,
                        onSubtaskToggled: (_) {},
                        onCompleted: () => _toggleDone(i),
                        onTap: () => showTaskDetailSheet(ctx, _tasks[i], onSaved: _loadTasks),
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
                  );
                }
                // Completed section header
                if (_showCompleted && _completedTasks.isNotEmpty && i == _tasks.length) {
                  return CompletedSectionHeader(
                    count: _completedTasks.length,
                    expanded: _completedExpanded,
                    onTap: () => setState(() => _completedExpanded = !_completedExpanded),
                  );
                }
                // Completed tasks
                final ci = i - _tasks.length - 1;
                if (ci >= 0 && ci < _completedTasks.length) {
                  return RepaintBoundary(
                    key: ValueKey('rb_done_${_completedTasks[ci].id}'),
                    child: SwipeableTaskTile(
                      task: _completedTasks[ci],
                      onDeleteRequested: () => _deleteCompletedTask(ci),
                      onEdit: () => showTaskDetailSheet(ctx, _completedTasks[ci], onSaved: _loadTasks),
                      onRefresh: _loadTasks,
                      child: TaskTile(
                        task: _completedTasks[ci],
                        showProject: false,
                        onSubtaskToggled: (_) {},
                        onCompleted: () => _toggleUndone(ci),
                        onTap: () => showTaskDetailSheet(ctx, _completedTasks[ci], onSaved: _loadTasks),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
      ],
    );
  }
}

// ── Project card ──────────────────────────────────────────────────────────────

class _ProjectCard extends StatelessWidget {
  final _ProjectMeta project;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const _ProjectCard({required this.project, required this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final progress = project.tasksTotal == 0
        ? 0.0
        : project.tasksDone / project.tasksTotal;
    final complete = project.tasksTotal > 0 &&
        project.tasksDone == project.tasksTotal;

    return PressableCard(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.cardMd,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: AppColors.navBar.computeLuminance() > 0.5 ? 0.06 : 0.18,
              ),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    complete
                        ? Icons.folder_off_rounded
                        : Icons.folder_rounded,
                    size: 18,
                    color: AppColors.accent,
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
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (project.description != null &&
                          project.description!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          project.description!,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${project.tasksDone}/${project.tasksTotal}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: complete
                        ? AppColors.tagGreen
                        : AppColors.textTertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: AppColors.surfaceVariant,
                valueColor: AlwaysStoppedAnimation(
                  complete ? AppColors.tagGreen : AppColors.accent,
                ),
                minHeight: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Text field helper ─────────────────────────────────────────────────────────

class _SheetField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  const _SheetField({required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.surfaceVariant,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

// ── Add project sheet ─────────────────────────────────────────────────────────

class _AddProjectSheet extends StatefulWidget {
  final VoidCallback onCreated;
  const _AddProjectSheet({required this.onCreated});

  @override
  State<_AddProjectSheet> createState() => _AddProjectSheetState();
}

class _AddProjectSheetState extends State<_AddProjectSheet> {
  static const _colors = [
    Color(0xFF63C7D8), Color(0xFF6F8FB8), Color(0xFF84B98E), Color(0xFF789C6B),
    Color(0xFFC58D97), Color(0xFFC58A72), Color(0xFFA496C8), Color(0xFF6F79B6),
    Color(0xFFC7B38A), Color(0xFFD3B36A), Color(0xFF7F99A8), Color(0xFF9CA3AF),
  ];

  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  Color _selectedColor = _colors.first;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _descCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    final hex = '#${_selectedColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
    Navigator.of(context, rootNavigator: true).pop();
    await supabase.from('projects').insert({
      'nome': _nameCtrl.text.trim(),
      'descricao': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      'cor': hex,
      'user_id': userId,
    });
    widget.onCreated();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        clipBehavior: Clip.antiAlias,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF242529),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF6B6E76).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom > 0 ? 20 : 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Novo projeto', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 16),
                  _SheetField(controller: _nameCtrl, label: 'Nome'),
                  const SizedBox(height: 12),
                  _SheetField(controller: _descCtrl, label: 'Descrição (opcional)'),
                  const SizedBox(height: 16),
                  Text('Cor', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textTertiary, letterSpacing: 0.5)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _colors.map((c) {
                      final isSelected = c == _selectedColor;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedColor = c),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.transparent,
                              width: 2.5,
                            ),
                            boxShadow: isSelected ? [BoxShadow(color: c.withValues(alpha: 0.6), blurRadius: 8)] : [],
                          ),
                          child: isSelected ? const HugeIcon(icon: HugeIcons.strokeRoundedTick01, size: 16, color: Colors.white) : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: _submit,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          HugeIcon(icon: HugeIcons.strokeRoundedFolderOpen, size: 18, color: AppColors.background),
                          const SizedBox(width: 8),
                          Text('Criar projeto', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.background)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}
