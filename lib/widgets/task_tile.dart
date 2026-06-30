import 'dart:math' as math;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import '../models/task.dart';
import '../models/subtask.dart';
import '../services/haptic_service.dart';
import '../services/label_repository.dart';
import '../services/supabase_client.dart';
import '../services/task_sync.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_motion.dart';
import 'pressable.dart';
import 'done_circle.dart';
import 'package:hugeicons/hugeicons.dart';
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
  /// Recarrega a lista após editar metadados de subtarefa inline.
  final VoidCallback? onSubtaskChanged;

  const TaskTile({
    super.key,
    required this.task,
    required this.onSubtaskToggled,
    this.onCompleted,
    this.onTap,
    this.onDismissed,
    this.showProject = true,
    this.allLabels,
    this.onSubtaskChanged,
  });

  @override
  State<TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends State<TaskTile> with TickerProviderStateMixin {
  static const _labelRepo = LabelRepository();
  List<TaskLabel> _workspaceLabels = [];
  bool _workspaceLabelsLoaded = false;
  bool _expanded = false;

  AnimationController? _expandCtrl;
  Animation<double>? _expandAnim;

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

  void _ensureExpandController() {
    if (_expandCtrl != null) return;
    _expandCtrl = AnimationController(
      duration: const Duration(milliseconds: 220),
      vsync: this,
    );
    _expandAnim = CurvedAnimation(
      parent: _expandCtrl!,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void initState() {
    super.initState();
    _subtasksDone = widget.task.subtasks.map((s) => s.done).toList();
    _strikethrough = widget.task.done;

    if (widget.task.hasSubtasks) _ensureExpandController();

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
    if (widget.allLabels == null) {
      _loadWorkspaceLabels();
    }
  }

  List<TaskLabel> get _subtaskLabelSource =>
      widget.allLabels ?? (_workspaceLabelsLoaded ? _workspaceLabels : widget.task.labels);

  Future<void> _loadWorkspaceLabels() async {
    try {
      final labels = await _labelRepo.fetchLabels();
      if (mounted && widget.allLabels == null) {
        setState(() {
          _workspaceLabels = labels;
          _workspaceLabelsLoaded = true;
        });
      }
    } catch (_) {}
  }

  @override
  void didUpdateWidget(TaskTile old) {
    super.didUpdateWidget(old);
    final newStates = widget.task.subtasks.map((s) => s.done).toList();
    if (!old.task.hasSubtasks && widget.task.hasSubtasks) {
      _ensureExpandController();
    }
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

    if (!AppMotion.enabled(context)) {
      if (mounted) setState(() => _strikethrough = true);
      _animating = false;
      widget.onDismissed?.call();
      return;
    }

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
    _ensureExpandController();
    HapticService().selectionClick();
    final instant = !AppMotion.enabled(context);
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {
        if (instant) {
          _expandCtrl!.value = 1.0;
        } else {
          _expandCtrl!.forward();
        }
      } else {
        if (instant) {
          _expandCtrl!.value = 0.0;
        } else {
          _expandCtrl!.reverse();
        }
      }
    });
  }

  @override
  void dispose() {
    _expandCtrl?.dispose();
    _collapseCtrl.dispose();
    _completionCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  // PRIORITY-CENTRAL-OLD: _priorityColor local, não referenciado — movido
  // pra PriorityExtension em lib/models/task.dart.

  String _accessibilityLabel(Task task) {
    final parts = <String>['Tarefa ${task.title}'];
    if (task.done) parts.add('concluída');
    if (task.dueDate != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final due = DateTime(
        task.dueDate!.year,
        task.dueDate!.month,
        task.dueDate!.day,
      );
      if (due.isBefore(today)) {
        parts.add('atrasada');
      } else if (due == today) {
        parts.add('vence hoje');
      }
    }
    if (task.hasSubtasks) {
      final done = _subtasksDone.where((d) => d).length;
      parts.add('$done de ${task.subtasks.length} subtarefas');
    }
    return parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final isDark = AppColors.surface.computeLuminance() < 0.5;

    return Semantics(
      button: true,
      label: _accessibilityLabel(task),
      child: SizeTransition(
      sizeFactor: _collapseAnim,
      alignment: Alignment.topCenter,
      child: SlideTransition(
        position: _exitSlide,
        child: FadeTransition(
          opacity: _exitFade,
          child: Container(
            margin: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, 10),
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md + 2),
              border: Border.all(
                color: AppColors.textPrimary.withValues(alpha: isDark ? 0.06 : 0.08),
              ),
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
                            child: HugeIcon(icon: HugeIcons.strokeRoundedArrowDown01,
                              size: 22,
                              color: AppColors.textTertiary.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01,
                          size: 18,
                          color: AppColors.textTertiary
                              .withValues(alpha: 0.3),
                        ),
                      ),
                  ],
                ),
                // ── Inline subtask list ──────────────────────────────────
                if (task.hasSubtasks && _expandAnim != null)
                  SizeTransition(
                    sizeFactor: _expandAnim!,
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
                      projectLabels: _subtaskLabelSource
                          .map((l) => LabelOption(l.id, l.name, l.color))
                          .toList(),
                      parentTaskTitle: task.title, // ADICIONADO_REDESIGN_SUBTASK
                      parentTaskId: task.id,
                      onSubtaskChanged: widget.onSubtaskChanged,
                      onToggle: (i) {
                        final newDone = !_subtasksDone[i];
                        setState(() => _subtasksDone[i] = newDone);
                        widget.onSubtaskToggled(i);
                        final sub = widget.task.subtasks[i];
                        if (sub.id != null) {
                          supabase
                              .from('subtasks')
                              .update({'concluida': newDone})
                              .eq('id', sub.id!)
                              .then((_) => TaskSync.instance.notifyChanged())
                              .catchError((_) {});
                        } else {
                          supabase
                              .from('subtasks')
                              .update({'concluida': newDone})
                              .eq('task_id', widget.task.id)
                              .eq('ordem', sub.order)
                              .then((_) => TaskSync.instance.notifyChanged())
                              .catchError((_) {});
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildBody(Task task) {
    final done = _subtasksDone.where((d) => d).length;
    final total = _subtasksDone.length;

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
              child: Semantics(
                button: true,
                label: task.done
                    ? 'Marcar tarefa como pendente'
                    : 'Marcar tarefa como concluída',
                enabled: !_animating,
                child: Padding(
                padding: const EdgeInsets.all(12),
                child: AnimatedBuilder(
                  animation: _dotScale,
                  builder: (_, child) =>
                      Transform.scale(scale: _dotScale.value, child: child),
                  child: PriorityDot(
                      priority: task.priority, done: task.done),
                ),
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
                HugeIcon(icon: HugeIcons.strokeRoundedClock01,
                    size: 11, color: AppColors.textTertiary),
                const SizedBox(width: 2),
                Text(formatTaskTimeDisplay(task.time!),
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textTertiary)),
              ],
              if (task.recurrence != null) ...[
                const SizedBox(width: 4),
                HugeIcon(icon: HugeIcons.strokeRoundedRepeat, size: 11, color: AppColors.textTertiary),
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

        // ── Meta unificada (etiquetas · data · contadores) ───────────
        TaskMetaLine(
          labels: task.labels,
          dueDate: task.dueDate,
          subtasksDone: done,
          subtasksTotal: total,
          commentCount: task.commentCount,
          projectName: widget.showProject && task.project != 'Sem projeto'
              ? task.project
              : null,
          padding: EdgeInsets.only(
            left: 30,
            top: task.description != null && task.description!.isNotEmpty ? 4 : 8,
          ),
        ),
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
  final String? parentTaskId;
  final VoidCallback? onSubtaskChanged;

  const SubtaskList(
      {super.key,
      required this.subtasks,
      this.doneStates,
      required this.onToggle,
      this.projectLabels,
      this.parentTaskTitle,
      this.parentTaskId,
      this.onSubtaskChanged});

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
            BorderRadius.vertical(bottom: Radius.circular(AppRadius.md + 2)),
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
              Divider(height: 1, thickness: 1, color: AppColors.textTertiary.withValues(alpha: 0.08)),
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // ADICIONADO_ETAPA3B
  Widget _buildSubtaskRow(BuildContext context, Subtask sub, int index) {
    final done = _doneAt(index);
    final hasDesc = sub.description != null && sub.description!.isNotEmpty;
    final hasChips = sub.dueDate != null || sub.labelIds.isNotEmpty;
    final centerTitle = !hasDesc && !hasChips;

    return Row(
      crossAxisAlignment:
          centerTitle ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            final willComplete = !done;
            if (willComplete) {
              HapticService().taskCompleted();
            } else {
              HapticService().selectionClick();
            }
            onToggle(index);
          },
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: centerTitle ? 4 : 13,
              horizontal: 4,
            ),
            child: _buildSubtaskCircle(sub, done),
          ),
        ),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _openSubtaskDetail(context, sub),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSubtaskTitle(sub, done),
                if (hasDesc) _buildSubtaskDesc(sub, done),
                _buildSubtaskMeta(sub),
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
      SubtaskPriority.high => AppColors.subtaskPriorityHigh,
      SubtaskPriority.medium => AppColors.subtaskPriorityMedium,
      SubtaskPriority.low => AppColors.subtaskPriorityLow,
      null => AppColors.textTertiary,
    };
    return DoneCircle(
      done: done,
      size: 18,
      borderWidth: 2,
      tickSize: 10,
      ringColor: priColor,
      ringFillAlpha: 0.08,
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
            ? AppColors.textTertiary
            : AppColors.textPrimary.withValues(alpha: 0.88),
        decoration: done ? TextDecoration.lineThrough : TextDecoration.none,
        decorationColor: AppColors.textTertiary,
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
          color: AppColors.textSecondary.withValues(alpha: done ? 0.55 : 0.85),
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildSubtaskMeta(Subtask sub) {
    final resolved = <TaskLabel>[];
    if (sub.labelIds.isNotEmpty && projectLabels != null) {
      for (final id in sub.labelIds) {
        final option = projectLabels!.where((l) => l.id == id).firstOrNull;
        if (option != null) {
          resolved.add(TaskLabel(id: option.id, name: option.name, color: option.color));
        }
      }
    }
    return TaskMetaLine(
      labels: resolved,
      dueDate: sub.dueDate,
      padding: const EdgeInsets.only(top: 6),
    );
  }

  void _openSubtaskDetail(BuildContext context, Subtask sub) {
    HapticService().lightImpact();
    final item = SubtaskItem(
      id: sub.id,
      taskId: parentTaskId,
      order: sub.order,
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
      onChanged: () {
        TaskSync.instance.notifyChanged();
        onSubtaskChanged?.call();
      },
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
    return DoneCircle(
      done: done,
      size: 20,
      borderWidth: 2.5,
      tickSize: 13,
      ringColor: _color,
      ringFillAlpha: 0.12,
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
                ? HugeIcon(icon: HugeIcons.strokeRoundedTick01, size: 9, color: color)
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

// ── Due-date chip (shared between balloon + list layouts) ────────────────────

const kPtMonthsShort = [
  'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
  'jul', 'ago', 'set', 'out', 'nov', 'dez',
];

/// Exibe hora na lista sem segundos (ex.: "23:05:00" → "23:05").
String formatTaskTimeDisplay(String time) {
  final parts = time.split(':');
  if (parts.length >= 2) {
    return '${parts[0]}:${parts[1]}';
  }
  return time;
}

({Color color, String label}) dueDateStyle(DateTime dueDate) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
  final diff = due.difference(today).inDays;
  if (diff == 0) {
    return (color: AppColors.dateDueToday, label: 'Hoje');
  }
  if (diff < 0) {
    return (
      color: AppColors.dateOverdue,
      label: '${due.day} ${kPtMonthsShort[due.month - 1]}',
    );
  }
  return (
    color: AppColors.dateUpcoming,
    label: '${due.day} ${kPtMonthsShort[due.month - 1]}',
  );
}

TagChip dueDateTagChip(DateTime dueDate) {
  final style = dueDateStyle(dueDate);
  return TagChip(
    label: style.label,
    color: style.color,
    hugeIcon: HugeIcons.strokeRoundedCalendar01,
  );
}

/// Opção A — linha única: etiquetas · data · contadores na mesma faixa.
class TaskMetaLine extends StatelessWidget {
  final List<TaskLabel> labels;
  final DateTime? dueDate;
  final int subtasksDone;
  final int subtasksTotal;
  final int commentCount;
  final String? projectName;
  final EdgeInsetsGeometry padding;
  final int maxLabels;

  const TaskMetaLine({
    super.key,
    this.labels = const [],
    this.dueDate,
    this.subtasksDone = 0,
    this.subtasksTotal = 0,
    this.commentCount = 0,
    this.projectName,
    this.padding = const EdgeInsets.only(top: 4),
    this.maxLabels = 3,
  });

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];

    if (projectName != null &&
        projectName!.isNotEmpty &&
        projectName != 'Sem projeto') {
      items.add(Text(
        projectName!,
        style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ));
    }

    for (final l in labels.take(maxLabels)) {
      items.add(TagChip(label: l.name, color: l.color));
    }
    if (labels.length > maxLabels) {
      items.add(TagChip(
        label: '+${labels.length - maxLabels}',
        color: AppColors.textTertiary,
        showIcon: false,
      ));
    }

    if (dueDate != null) {
      items.add(dueDateTagChip(dueDate!));
    }

    if (subtasksTotal > 0) {
      items.add(_TaskMetaCounter(
        icon: HugeIcons.strokeRoundedTaskDone01,
        value: '$subtasksDone/$subtasksTotal',
      ));
    }

    if (commentCount > 0) {
      items.add(_TaskMetaCounter(
        icon: HugeIcons.strokeRoundedComment01,
        value: '$commentCount',
      ));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: padding,
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: items,
      ),
    );
  }
}

class _TaskMetaCounter extends StatelessWidget {
  final List<List<dynamic>> icon;
  final String value;

  const _TaskMetaCounter({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        HugeIcon(icon: icon, size: 12, color: AppColors.textTertiary),
        const SizedBox(width: 3),
        Text(value, style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
      ],
    );
  }
}

// ── Tag chip — ícone outline + texto, sem fundo ──────────────────────────────

class TagChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool showIcon;
  final List<List<dynamic>>? hugeIcon;
  final double? maxWidth;
  const TagChip({
    super.key,
    required this.label,
    required this.color,
    this.showIcon = true,
    this.hugeIcon,
    this.maxWidth,
  });

  List<List<dynamic>> get _icon =>
      hugeIcon ?? HugeIcons.strokeRoundedTag01;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (showIcon) ...[
          HugeIcon(icon: _icon, size: 11, color: color),
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
