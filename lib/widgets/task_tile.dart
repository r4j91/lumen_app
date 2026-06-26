import 'dart:math' as math;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import '../models/task.dart';
import '../models/subtask.dart';
import '../services/haptic_service.dart';
import '../services/supabase_client.dart';
import '../theme/app_colors.dart';
import 'pressable.dart';
// ADICIONADO_ETAPA3B
import 'task_detail/subtask_item.dart';
// ADICIONADO_ETAPA3B
import 'task_detail/sheets/subtask_detail_sheet.dart';
// ADICIONADO_ETAPA3B
import 'task_detail/sheets/task_labels_picker_sheet.dart' show LabelOption;

class TaskTile extends StatefulWidget {
  final Task task;
  final void Function(int subtaskIndex) onSubtaskToggled;
  final VoidCallback? onCompleted;
  final VoidCallback? onTap;
  /// Called after exit animation fully completes (slide + collapse).
  final VoidCallback? onDismissed;
  final bool showProject;
  // CORRIGIDO_ETAPA3B: lista completa de labels (do projeto/workspace),
  // usada para resolver nome/cor das etiquetas das subtarefas — diferente
  // de `task.labels`, que só contém as labels já atribuídas à tarefa pai
  // e por isso não resolvia labelIds de subtarefa não compartilhados com
  // a tarefa (causava UUID cru aparecendo no chip).
  final List<TaskLabel>? allLabels;

  const TaskTile({
    super.key,
    required this.task,
    required this.onSubtaskToggled,
    this.onCompleted,
    this.onTap,
    this.onDismissed,
    this.showProject = true,
    this.allLabels,
  });

  @override
  State<TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends State<TaskTile> with TickerProviderStateMixin {
  bool _expanded = false;

  late final AnimationController _expandCtrl;
  late final Animation<double> _expandAnim;

  late List<bool> _subtasksDone;

  late final AnimationController _completionCtrl;
  late final Animation<double> _dotScale;
  bool _strikethrough = false;

  late final AnimationController _exitCtrl;
  late final Animation<Offset> _exitSlide;
  late final Animation<double> _exitFade;

  late final AnimationController _collapseCtrl;
  late final Animation<double> _collapseAnim;

  bool _animating = false;

  @override
  void initState() {
    super.initState();
    _subtasksDone = widget.task.subtasks.map((s) => s.done).toList();
    _strikethrough = widget.task.done;

    _expandCtrl = AnimationController(
      duration: const Duration(milliseconds: 220),
      vsync: this,
    );
    _expandAnim = CurvedAnimation(
        parent: _expandCtrl,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic);

    _collapseCtrl = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
      value: 1.0,
    );
    _collapseAnim =
        CurvedAnimation(parent: _collapseCtrl, curve: Curves.easeInCubic);

    _completionCtrl = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _dotScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.22)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.22, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 60,
      ),
    ]).animate(_completionCtrl);

    _exitCtrl = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _exitSlide = Tween<Offset>(begin: Offset.zero, end: const Offset(0.35, 0))
        .animate(CurvedAnimation(parent: _exitCtrl, curve: Curves.easeInCubic));
    _exitFade = Tween<double>(begin: 1.0, end: 0.0)
        .animate(CurvedAnimation(parent: _exitCtrl, curve: Curves.easeInCubic));
  }

  @override
  void didUpdateWidget(TaskTile old) {
    super.didUpdateWidget(old);
    final newStates = widget.task.subtasks.map((s) => s.done).toList();
    if (old.task.id != widget.task.id ||
        newStates.length != _subtasksDone.length ||
        !listEquals(newStates, _subtasksDone)) {
      _subtasksDone = newStates;
    }
    if (!old.task.done && widget.task.done) {
      if (!_animating) _runCompletionAnimation();
    } else if (old.task.done && !widget.task.done && !_animating) {
      _completionCtrl.reset();
      _exitCtrl.reset();
      _collapseCtrl.forward();
      if (mounted) setState(() => _strikethrough = false);
    }
  }

  Future<void> _runCompletionAnimation() async {
    if (_animating) return;
    _animating = true;

    HapticService().taskCompleted();
    _completionCtrl.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 80));
    if (!mounted) { _animating = false; return; }
    setState(() => _strikethrough = true);

    await Future.delayed(const Duration(milliseconds: 320));
    if (!mounted) { _animating = false; return; }

    _exitCtrl.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) { _animating = false; return; }

    _collapseCtrl.reverse();
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) { _animating = false; return; }

    _animating = false;
    widget.onDismissed?.call();
  }

  void _toggleExpand() {
    HapticService().selectionClick();
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {
        _expandCtrl.forward();
      } else {
        _expandCtrl.reverse();
      }
    });
  }

  @override
  void dispose() {
    _expandCtrl.dispose();
    _collapseCtrl.dispose();
    _completionCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  Color _priorityColor(Priority p) => switch (p) {
        Priority.high => AppColors.priorityHigh,
        Priority.medium => AppColors.priorityMedium,
        Priority.low => AppColors.priorityLow,
      };

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final isDark = AppColors.surface.computeLuminance() < 0.5;

    return SizeTransition(
      sizeFactor: _collapseAnim,
      alignment: Alignment.topCenter,
      child: SlideTransition(
        position: _exitSlide,
        child: FadeTransition(
          opacity: _exitFade,
          child: Container(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                      alpha: isDark ? 0.22 : 0.07),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Card body + expand chevron (siblings) ────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: PressableCard(
                        onTap: () {
                          HapticService().selectionClick();
                          widget.onTap?.call();
                        },
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                          child: _buildBody(task),
                        ),
                      ),
                    ),
                    // EXPAND-BTN-OLD: padding (4,16,14,16) — ~38x52, abaixo
                    // do mínimo 44x44 do HIG.
                    // Expand toggle (subtask tasks) or static affordance (others)
                    // if (task.hasSubtasks)
                    //   GestureDetector(
                    //     behavior: HitTestBehavior.opaque,
                    //     onTap: _toggleExpand,
                    //     child: Padding(
                    //       padding:
                    //           const EdgeInsets.fromLTRB(4, 16, 14, 16),
                    //       child: AnimatedRotation(
                    //         turns: _expanded ? 0.5 : 0,
                    //         duration: const Duration(milliseconds: 220),
                    //         curve: Curves.easeOutCubic,
                    //         child: Icon(
                    //           Icons.keyboard_arrow_down,
                    //           size: 20,
                    //           color: AppColors.textTertiary
                    //               .withValues(alpha: 0.55),
                    //         ),
                    //       ),
                    //     ),
                    //   )
                    if (task.hasSubtasks)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _toggleExpand,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: AnimatedRotation(
                            turns: _expanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 22,
                              color: Colors.white.withValues(alpha: 0.35),
                            ),
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(4, 18, 14, 16),
                        child: Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: AppColors.textTertiary
                              .withValues(alpha: 0.3),
                        ),
                      ),
                  ],
                ),
                // ── Inline subtask list ──────────────────────────────────
                if (task.hasSubtasks)
                  SizeTransition(
                    sizeFactor: _expandAnim,
                    alignment: Alignment.topCenter,
                    child: SubtaskList(
                      subtasks: task.subtasks,
                      doneStates: _subtasksDone,
                      // CORRIGIDO_ETAPA3B: antes usava task.labels (só as
                      // labels da tarefa pai, não resolvia labelIds de
                      // subtarefa fora desse conjunto → aparecia o UUID cru).
                      // Agora usa widget.allLabels (lista completa do
                      // projeto/workspace, ver TaskTile.allLabels), com
                      // fallback para task.labels caso não seja passada.
                      // projectLabels: task.labels
                      //     .map((l) => LabelOption(l.id, l.name, l.color))
                      //     .toList(),
                      projectLabels: (widget.allLabels ?? task.labels)
                          .map((l) => LabelOption(l.id, l.name, l.color))
                          .toList(),
                      parentTaskTitle: task.title, // ADICIONADO_REDESIGN_SUBTASK
                      onToggle: (i) {
                        final newDone = !_subtasksDone[i];
                        setState(() => _subtasksDone[i] = newDone);
                        widget.onSubtaskToggled(i);
                        supabase
                            .from('subtasks')
                            .update({'concluida': newDone})
                            .eq('task_id', widget.task.id)
                            .eq('ordem', i)
                            .catchError((_) {});
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(Task task) {
    final done = _subtasksDone.where((d) => d).length;
    final total = _subtasksDone.length;

    // BUG1: chip de data da tarefa pai no modo Balões.
    Widget? dateChip;
    if (task.dueDate != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final d = DateTime(task.dueDate!.year, task.dueDate!.month, task.dueDate!.day);
      final Color dateColor;
      if (d.isBefore(today)) {
        dateColor = const Color(0xFFEF4444);
      } else if (d == today) {
        dateColor = const Color(0xFF22C55E);
      } else {
        dateColor = Colors.white.withValues(alpha: 0.45);
      }
      const months = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];
      final label = d == today ? 'Hoje' : '${d.day} ${months[d.month - 1]}';
      dateChip = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_today_rounded, size: 11, color: dateColor),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(fontSize: 12, color: dateColor, fontWeight: FontWeight.w500)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Title row ─────────────────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _animating ? null : widget.onCompleted,
              onTapDown: (_) {},
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 2, 10, 2),
                child: AnimatedBuilder(
                  animation: _dotScale,
                  builder: (_, child) =>
                      Transform.scale(scale: _dotScale.value, child: child),
                  child: PriorityDot(
                      priority: task.priority, done: task.done),
                ),
              ),
            ),
            Expanded(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                  color: _strikethrough
                      ? AppColors.textTertiary
                      : AppColors.textPrimary,
                  decoration: _strikethrough
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                  decorationColor: AppColors.textTertiary,
                  height: 1.3,
                  letterSpacing: -0.2,
                ),
                child: Text(
                  task.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            // Time / recurrence badges (compact, in title row)
            if (task.time != null || task.recurrence != null) ...[
              const SizedBox(width: 6),
              if (task.time != null) ...[
                Icon(Icons.access_time,
                    size: 11, color: AppColors.textTertiary),
                const SizedBox(width: 2),
                Text(task.time!,
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textTertiary)),
              ],
              if (task.recurrence != null) ...[
                const SizedBox(width: 4),
                Icon(Icons.repeat, size: 11, color: AppColors.textTertiary),
              ],
            ],
          ],
        ),

        // ── Description ──────────────────────────────────────────────
        if (task.description != null && task.description!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 30),
            child: Text(
              task.description!,
              style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],

        // ── Labels ───────────────────────────────────────────────────
        if (task.labels.isNotEmpty) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 30),
            child: Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                ...task.labels.take(3).map((l) => TagChip(
                      label: l.name,
                      color: l.color,
                    )),
                if (task.labels.length > 3)
                  TagChip(
                    label: '+${task.labels.length - 3}',
                    color: AppColors.textTertiary,
                    showIcon: false,
                  ),
              ],
            ),
          ),
        ],

        // BUG1-OLD: task.dueDate nunca era exibido no modo Balões — só era
        // usado para gerar os chips de data das subtarefas.
        // ── Meta footer ──────────────────────────────────────────────
        if (widget.showProject && task.project != 'Sem projeto' || task.hasSubtasks || task.dueDate != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 30),
            child: Row(
              children: [
                if (widget.showProject && task.project != 'Sem projeto') ...[
                  Text(
                    task.project,
                    style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (task.hasSubtasks)
                    Text(' • ', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                ],
                // M3-OLD: contador sem ícone ao lado.
                // if (task.hasSubtasks)
                //   Text(
                //     '$done/$total',
                //     style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                //   ),
                if (task.hasSubtasks)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.checklist_rounded,
                        size: 13,
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '$done/$total',
                        style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                if (dateChip != null) ...[
                  if (task.hasSubtasks || (widget.showProject && task.project != 'Sem projeto'))
                    Text(' • ', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                  dateChip,
                ],
                // M2-OLD: ícone e separador sempre visíveis, mesmo com commentCount == 0.
                // Text(' • ', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                // Icon(Icons.chat_bubble_outline, size: 11, color: AppColors.textTertiary),
                // const SizedBox(width: 3),
                // Text('${task.commentCount}', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                if (task.commentCount > 0) ...[
                  Text(' • ', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 12,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${task.commentCount}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ── Subtask inline list ──────────────────────────────────────────────────────

class SubtaskList extends StatelessWidget {
  final List<Subtask> subtasks;
  final List<bool>? doneStates;
  final void Function(int) onToggle;
  // ADICIONADO_ETAPA3B: labels disponíveis para resolver nome/cor das
  // etiquetas das subtarefas (ver chips em _buildSubtaskChips).
  final List<LabelOption>? projectLabels;
  // ADICIONADO_REDESIGN_SUBTASK: título da tarefa pai, usado no breadcrumb
  // do SubtaskDetailSheet.
  final String? parentTaskTitle;

  const SubtaskList(
      {super.key,
      required this.subtasks,
      this.doneStates,
      required this.onToggle,
      this.projectLabels,
      this.parentTaskTitle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) {},
      child: _buildList(context),
    );
  }

  // SUBSTITUIDO_ETAPA3B: layout antigo (ícone check + título + descrição,
  // sem chips, sem hierarquia visual de indentação/tamanho). Substituído
  // pelo redesenho abaixo (_buildSubtaskRow). Mantido como referência:
  // Widget _buildList() {
  //   return DecoratedBox(
  //     decoration: BoxDecoration(
  //       color: AppColors.surfaceVariant.withValues(alpha: 0.45),
  //       borderRadius:
  //           const BorderRadius.vertical(bottom: Radius.circular(14)),
  //     ),
  //     child: Column(
  //       children: [
  //         Divider(height: 1, thickness: 1, color: AppColors.surfaceVariant),
  //         for (int i = 0; i < subtasks.length; i++)
  //           Builder(builder: (context) {
  //             final done = doneStates != null && i < doneStates!.length
  //                 ? doneStates![i]
  //                 : subtasks[i].done;
  //             final sub = subtasks[i];
  //             final priColor = switch (sub.priority) {
  //               SubtaskPriority.high => AppColors.priorityHigh,
  //               SubtaskPriority.medium => AppColors.priorityMedium,
  //               SubtaskPriority.low => AppColors.priorityLow,
  //               null => AppColors.textTertiary,
  //             };
  //             return GestureDetector(
  //               behavior: HitTestBehavior.opaque,
  //               onTap: () {
  //                 HapticService().selectionClick();
  //                 onToggle(i);
  //               },
  //               onLongPress: () {},
  //               child: Padding(
  //                 padding: const EdgeInsets.fromLTRB(40, 11, 16, 11),
  //                 child: Row(
  //                   children: [
  //                     AnimatedSwitcher(
  //                       duration: const Duration(milliseconds: 200),
  //                       transitionBuilder: (child, anim) => ScaleTransition(
  //                         scale: CurvedAnimation(
  //                             parent: anim, curve: Curves.easeOutBack),
  //                         child: FadeTransition(opacity: anim, child: child),
  //                       ),
  //                       child: Icon(
  //                         key: ValueKey(done),
  //                         done
  //                             ? Icons.check_circle
  //                             : Icons.radio_button_unchecked,
  //                         size: 17,
  //                         color: priColor,
  //                       ),
  //                     ),
  //                     const SizedBox(width: 10),
  //                     Expanded(
  //                       child: Column(
  //                         crossAxisAlignment: CrossAxisAlignment.start,
  //                         children: [
  //                           AnimatedDefaultTextStyle(
  //                             duration: const Duration(milliseconds: 180),
  //                             curve: Curves.easeOut,
  //                             style: TextStyle(
  //                               fontSize: 13,
  //                               color: done
  //                                   ? AppColors.textTertiary
  //                                   : AppColors.textSecondary,
  //                               decoration: done
  //                                   ? TextDecoration.lineThrough
  //                                   : TextDecoration.none,
  //                               decorationColor: AppColors.textTertiary,
  //                             ),
  //                             child: Text(subtasks[i].title),
  //                           ),
  //                           if (sub.description != null &&
  //                               sub.description!.isNotEmpty)
  //                             Padding(
  //                               padding: const EdgeInsets.only(top: 2),
  //                               child: Text(
  //                                 sub.description!,
  //                                 style: TextStyle(
  //                                   fontSize: 11.5,
  //                                   color: AppColors.textTertiary.withValues(
  //                                       alpha: done ? 0.5 : 0.8),
  //                                 ),
  //                                 maxLines: 2,
  //                                 overflow: TextOverflow.ellipsis,
  //                               ),
  //                             ),
  //                         ],
  //                       ),
  //                     ),
  //                   ],
  //                 ),
  //               ),
  //             );
  //           }),
  //         const SizedBox(height: 4),
  //       ],
  //     ),
  //   );
  // }

  // ADICIONADO_ETAPA3B
  bool _doneAt(int i) =>
      doneStates != null && i < doneStates!.length ? doneStates![i] : subtasks[i].done;

  // ADICIONADO_ETAPA3B
  Widget _buildList(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.45),
        borderRadius:
            const BorderRadius.vertical(bottom: Radius.circular(14)),
      ),
      child: Column(
        children: [
          Divider(height: 1, thickness: 1, color: AppColors.surfaceVariant),
          for (int i = 0; i < subtasks.length; i++) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(36, 9, 12, 9),
              child: _buildSubtaskRow(context, subtasks[i], i),
            ),
            if (i < subtasks.length - 1)
              Divider(height: 1, thickness: 1, color: Colors.white.withValues(alpha: 0.04)),
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // ADICIONADO_ETAPA3B
  Widget _buildSubtaskRow(BuildContext context, Subtask sub, int index) {
    final done = _doneAt(index);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticService().selectionClick();
            onToggle(index);
          },
          child: Padding(
            padding: const EdgeInsets.only(top: 2, right: 10),
            child: _buildSubtaskCircle(sub, done),
          ),
        ),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _openSubtaskDetail(context, sub),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSubtaskTitle(sub, done),
                if (sub.description != null && sub.description!.isNotEmpty)
                  _buildSubtaskDesc(sub, done),
                _buildSubtaskChips(context, sub),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ADICIONADO_ETAPA3B
  Widget _buildSubtaskCircle(Subtask sub, bool done) {
    final priColor = switch (sub.priority) {
      SubtaskPriority.high => const Color(0xFFDC4C3E),
      SubtaskPriority.medium => const Color(0xFFEB8909),
      SubtaskPriority.low => const Color(0xFF246FE0),
      null => AppColors.textTertiary,
    };
    // M1-OLD: antes, done==true mantinha a cor da prioridade da subtask.
    // return Container(
    //   width: 18,
    //   height: 18,
    //   decoration: BoxDecoration(
    //     shape: BoxShape.circle,
    //     color: priColor.withValues(alpha: 0.08),
    //     border: Border.all(color: priColor, width: 2),
    //   ),
    //   child: done
    //       ? Icon(Icons.check, size: 11, color: priColor.withValues(alpha: 0.8))
    //       : null,
    // );
    const doneColor = Color(0xFF22C55E);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? doneColor : priColor.withValues(alpha: 0.08),
        border: Border.all(color: done ? doneColor : priColor, width: 2),
      ),
      child: done
          ? const Icon(Icons.check_rounded, size: 10, color: Colors.white)
          : null,
    );
  }

  // ADICIONADO_ETAPA3B
  Widget _buildSubtaskTitle(Subtask sub, bool done) {
    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: done
            ? Colors.white.withValues(alpha: 0.40)
            : Colors.white.withValues(alpha: 0.88),
        decoration: done ? TextDecoration.lineThrough : TextDecoration.none,
        decorationColor: Colors.white.withValues(alpha: 0.40),
      ),
      child: Text(sub.title),
    );
  }

  // ADICIONADO_ETAPA3B
  Widget _buildSubtaskDesc(Subtask sub, bool done) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        sub.description!,
        style: TextStyle(
          fontSize: 12,
          color: Colors.white.withValues(alpha: done ? 0.20 : 0.35),
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // ADICIONADO_ETAPA3B
  static const _ptMonths = [
    'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
    'jul', 'ago', 'set', 'out', 'nov', 'dez',
  ];

  // ADICIONADO_ETAPA3B
  Widget _buildSubtaskChips(BuildContext context, Subtask sub) {
    final chips = <Widget>[];

    if (sub.dueDate != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final due = DateTime(sub.dueDate!.year, sub.dueDate!.month, sub.dueDate!.day);
      final diff = due.difference(today).inDays;
      final Color dotColor;
      final String label;
      if (diff == 0) {
        dotColor = const Color(0xFF7ECC49);
        label = 'Hoje';
      } else if (diff < 0) {
        dotColor = const Color(0xFFDC4C3E);
        label = '${due.day} ${_ptMonths[due.month - 1]}';
      } else {
        dotColor = const Color(0xFFF0A830);
        label = '${due.day} ${_ptMonths[due.month - 1]}';
      }
      chips.add(_metaChip(dotColor, label));
    }

    if (sub.labelIds.isNotEmpty) {
      for (final id in sub.labelIds) {
        final option = projectLabels?.where((l) => l.id == id).firstOrNull;
        if (option != null) {
          chips.add(_metaChip(option.color, option.name));
        } else {
          // Nunca quebrar silenciosamente — fallback cinza com o id.
          chips.add(_metaChip(AppColors.textTertiary, id));
        }
      }
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 5,
        runSpacing: 4,
        children: chips,
      ),
    );
  }

  // ADICIONADO_ETAPA3B
  Widget _metaChip(Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // ADICIONADO_ETAPA3B
  void _openSubtaskDetail(BuildContext context, Subtask sub) {
    HapticService().lightImpact();
    final item = SubtaskItem(
      id: sub.id,
      title: sub.title,
      description: sub.description,
      done: sub.done,
      priority: sub.priority,
      labelIds: sub.labelIds.toSet(),
      dueDate: sub.dueDate,
      valor: sub.valor,
    );
    showSubtaskDetailSheet(
      context: context,
      item: item,
      labels: projectLabels ?? const [],
      parentTaskTitle: parentTaskTitle, // ADICIONADO_REDESIGN_SUBTASK
      // O sheet já persiste cada campo via debounce direto no Supabase
      // (SubtaskRepository.updateSubtaskFields). Não há callback de reload
      // de lista cabeado aqui (SubtaskList é stateless e recebe `subtasks`
      // de fora); a tela que hospeda o TaskTile precisa recarregar a tarefa
      // para refletir a edição — fora do escopo desta etapa.
      onChanged: () {},
    );
  }
}

// ── Priority dot (completion toggle) ────────────────────────────────────────

class PriorityDot extends StatelessWidget {
  final Priority? priority;
  final bool done;
  const PriorityDot({super.key, required this.priority, this.done = false});

  Color get _color => switch (priority) {
        Priority.high => AppColors.priorityHigh,
        Priority.medium => AppColors.priorityMedium,
        Priority.low => AppColors.priorityLow,
        null => AppColors.textTertiary,
      };

  @override
  Widget build(BuildContext context) {
    // M1-OLD: antes, done==true preenchia com a cor da prioridade.
    // return Container(
    //   width: 20,
    //   height: 20,
    //   decoration: BoxDecoration(
    //     shape: BoxShape.circle,
    //     color: done ? _color : _color.withValues(alpha: 0.12),
    //     border: Border.all(color: _color, width: 2.5),
    //   ),
    //   child: done
    //       ? const Icon(Icons.check, size: 12, color: Colors.white)
    //       : null,
    // );
    const doneColor = Color(0xFF22C55E);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? doneColor : _color.withValues(alpha: 0.12),
        border: Border.all(color: done ? doneColor : _color, width: 2.5),
      ),
      child: done
          ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
          : null,
    );
  }
}

// ── Subtask circular progress ────────────────────────────────────────────────

class SubtaskProgress extends StatelessWidget {
  final int done;
  final int total;
  final Color color;

  const SubtaskProgress({
    super.key,
    required this.done,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : done / total;
    final complete = done == total;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CustomPaint(
            painter: _ArcPainter(
                progress: progress, color: color, complete: complete),
            child: complete
                ? Icon(Icons.check, size: 9, color: color)
                : Center(
                    child: Text(
                      '$done',
                      style: TextStyle(
                        fontSize: 7,
                        fontWeight: FontWeight.w700,
                        color: color,
                        height: 1,
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          '$done/$total',
          style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
        ),
      ],
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double progress;
  final Color color;
  final bool complete;

  const _ArcPainter(
      {required this.progress, required this.color, required this.complete});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = (size.width - 2.5) / 2;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);

    final trackPaint = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(cx, cy), radius, trackPaint);

    if (progress <= 0) return;

    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress, false, arcPaint);
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.progress != progress || old.color != color || old.complete != complete;
}

// ── Tag chip — ícone outline + texto, sem fundo ──────────────────────────────

class TagChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool showIcon;
  final double? maxWidth;
  const TagChip(
      {super.key,
      required this.label,
      required this.color,
      this.showIcon = true,
      this.maxWidth});

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (showIcon) ...[
          // CORRIGIDO_ETAPA3B_CHIP: ícone substituído por bolinha colorida,
          // para padronizar com o estilo de chip já usado nas subtarefas.
          // Icon(Icons.label_outline, size: 13, color: color),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(
            label,
            style: TextStyle(
                fontSize: 12, color: color, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.30), width: 0.8),
      ),
      child: content,
    );
    if (maxWidth != null) {
      return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth!), child: chip);
    }
    return chip;
  }
}
