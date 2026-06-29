import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/supabase_client.dart';
import '../services/task_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/app_sheet.dart';
import '../widgets/empty_state.dart';
import '../widgets/task_tile.dart';
import 'task_detail_sheet.dart';
import 'package:hugeicons/hugeicons.dart';

class LogbookScreen extends StatefulWidget {
  const LogbookScreen({super.key});
  @override State<LogbookScreen> createState() => _LogbookScreenState();
}

class _LogbookScreenState extends State<LogbookScreen> {
  List<Task> _tasks = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final rows = await supabase
          .from('tasks')
          .select('id, titulo, descricao, prioridade, hora, ordem, concluida, data_vencimento, recorrencia, projects(nome), subtasks(id, titulo, descricao, concluida, ordem, prioridade, data_vencimento, label_ids, valor), task_labels(labels(id, nome, cor))')
          .eq('concluida', true)
          .order('data_vencimento', ascending: false, nullsFirst: false)
          .order('ordem', ascending: false)
          .limit(200);
      if (mounted) {
        setState(() {
          _tasks = (rows as List).map((r) => TaskRepository.mapRow(r as Map<String, dynamic>)).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Group tasks by "Hoje", "Ontem", formatted date, or "Sem data"
  Map<String, List<Task>> get _grouped {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    const months = ['Janeiro','Fevereiro','Março','Abril','Maio','Junho','Julho','Agosto','Setembro','Outubro','Novembro','Dezembro'];
    // Use LinkedHashMap insertion order — tasks with dates come first (sorted by query),
    // then "Sem data" at the end.
    final result = <String, List<Task>>{};
    final noDate = <Task>[];

    for (final task in _tasks) {
      if (task.dueDate == null) {
        noDate.add(task);
        continue;
      }
      final date = task.dueDate!;
      final day = DateTime(date.year, date.month, date.day);
      String label;
      if (day == today) {
        label = 'Hoje';
      } else if (day == yesterday) {
        label = 'Ontem';
      } else {
        label = '${date.day} de ${months[date.month - 1]}';
        if (date.year != now.year) label += ' de ${date.year}';
      }
      result.putIfAbsent(label, () => []).add(task);
    }
    if (noDate.isNotEmpty) result['Sem data'] = noDate;
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final groups = _grouped;
    final keys = groups.keys.toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Registro', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2))
          : _tasks.isEmpty
              ? const Center(child: EmptyState(hugeIcon: HugeIcons.strokeRoundedClock02, title: 'Nenhuma tarefa concluída', subtitle: 'As tarefas concluídas aparecerão aqui'))
              : RefreshIndicator(
                  color: AppColors.accent,
                  backgroundColor: AppColors.surface,
                  onRefresh: _load,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      for (final key in keys) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                            child: AppSectionLabel(key),
                          ),
                        ),
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) {
                              final task = groups[key]![i];
                              final globalIndex = _tasks.indexOf(task);
                              return RepaintBoundary(
                                key: ValueKey('rb_logbook_${task.id}'),
                                child: _AnimatedLogbookTile(
                                  index: globalIndex,
                                  child: TaskTile(
                                    task: task,
                                    onSubtaskToggled: (_) {},
                                    onTap: () => showTaskDetailSheet(ctx, task, onSaved: _load),
                                  ),
                                ),
                              );
                            },
                            childCount: groups[key]!.length,
                          ),
                        ),
                      ],
                      const SliverToBoxAdapter(child: SizedBox(height: 120)),
                    ],
                  ),
                ),
    );
  }
}

class _AnimatedLogbookTile extends StatefulWidget {
  final int index;
  final Widget child;
  const _AnimatedLogbookTile({required this.index, required this.child});
  @override State<_AnimatedLogbookTile> createState() => _AnimatedLogbookTileState();
}

class _AnimatedLogbookTileState extends State<_AnimatedLogbookTile> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    final delay = (widget.index * 40).clamp(0, 500);
    Future.delayed(Duration(milliseconds: delay), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
