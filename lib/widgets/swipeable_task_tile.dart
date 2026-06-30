import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../models/task.dart';
import '../services/haptic_service.dart';
import '../services/task_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import 'package:hugeicons/hugeicons.dart';
// import 'task_context_sheet.dart'; // replaced by overlay menu below
import 'task_context_menu.dart';

class SwipeableTaskTile extends StatefulWidget {
  final Task task;
  final Widget child;
  final VoidCallback? onCompleted;
  final VoidCallback? onDeleteRequested;
  final VoidCallback? onEdit;
  final VoidCallback? onRefresh;

  const SwipeableTaskTile({
    super.key,
    required this.task,
    required this.child,
    this.onCompleted,
    this.onDeleteRequested,
    this.onEdit,
    this.onRefresh,
  });

  @override
  State<SwipeableTaskTile> createState() => _SwipeableTaskTileState();
}

class _SwipeableTaskTileState extends State<SwipeableTaskTile>
    with SingleTickerProviderStateMixin {
  late final SlidableController _slidableCtrl;

  static const _startExtent = 0.28;
  static const _endExtent = 0.5;

  bool _startTriggered = false;
  bool _endTriggered = false;

  @override
  void initState() {
    super.initState();
    _slidableCtrl = SlidableController(this);
    _slidableCtrl.animation.addListener(_onRatioChanged);
  }

  @override
  void dispose() {
    _slidableCtrl.animation.removeListener(_onRatioChanged);
    _slidableCtrl.dispose();
    super.dispose();
  }

  void _onRatioChanged() {
    final ratio = _slidableCtrl.ratio;
    if (ratio >= _startExtent * 0.8) {
      if (!_startTriggered) {
        _startTriggered = true;
        HapticService().swipeThreshold();
      }
    } else {
      _startTriggered = false;
    }
    if (ratio <= -_endExtent * 0.8) {
      if (!_endTriggered) {
        _endTriggered = true;
        HapticService().swipeThreshold();
      }
    } else {
      _endTriggered = false;
    }
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _postpone(BuildContext context) async {
    HapticService().dateConfirmed();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final current = widget.task.dueDate;
    final DateTime next;
    if (current == null) {
      next = today.add(const Duration(days: 1));
    } else {
      final due = DateTime(current.year, current.month, current.day);
      next = !due.isAfter(today)
          ? today.add(const Duration(days: 1))
          : due.add(const Duration(days: 1));
    }
    final iso =
        '${next.year}-${next.month.toString().padLeft(2, '0')}-${next.day.toString().padLeft(2, '0')}';
    try {
      await const TaskRepository().updateTaskDate(widget.task.id, iso);
      widget.onRefresh?.call();
      if (!context.mounted) return;
      _slidableCtrl.close();
      _showSnack(context, '"${widget.task.title}" adiada para amanhã');
    } catch (_) {}
  }

  Future<void> _openContextMenu(BuildContext context, Offset tapPosition) async {
    // OLD: showTaskContextSheet (bottom sheet) — commented for revert:
    // showTaskContextSheet(context, task: widget.task, onEdit: widget.onEdit,
    //   onComplete: widget.onCompleted, onDelete: widget.onDeleteRequested,
    //   onRefresh: widget.onRefresh);
    await showTaskContextMenu(
      context,
      task: widget.task,
      tapPosition: tapPosition,
      onEdit: widget.onEdit,
      onComplete: widget.onCompleted,
      onDelete: widget.onDeleteRequested,
      onRefresh: widget.onRefresh,
    );
  }

  @override
  Widget build(BuildContext context) {
    final slideMotion = AppMotion.enabled(context)
        ? const DrawerMotion()
        : const BehindMotion();

    return GestureDetector(
      onLongPressStart: (d) => _openContextMenu(context, d.globalPosition),
      onSecondaryTapDown: (d) => _openContextMenu(context, d.globalPosition),
      child: Slidable(
        key: ValueKey(widget.task.id),
        controller: _slidableCtrl,
        startActionPane: ActionPane(
          motion: slideMotion,
          extentRatio: _startExtent,
          children: [
            Semantics(
              button: true,
              label: 'Concluir tarefa',
              child: CustomSlidableAction(
              onPressed: (_) {
                HapticService().taskCompleted();
                widget.onCompleted?.call();
                _showSnack(context, '"${widget.task.title}" concluída');
              },
              backgroundColor: AppColors.dateDueToday,
              foregroundColor: AppColors.onColoredFill,
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(12)),
              child: const ExcludeSemantics(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    HugeIcon(icon: HugeIcons.strokeRoundedTick01, size: 22),
                    SizedBox(height: 4),
                    Text('Concluir',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            ),
          ],
        ),
        endActionPane: ActionPane(
          motion: slideMotion,
          extentRatio: _endExtent,
          children: [
            Semantics(
              button: true,
              label: 'Adiar tarefa para amanhã',
              child: CustomSlidableAction(
              onPressed: (_) => _postpone(context),
              backgroundColor: AppColors.priorityMedium,
              foregroundColor: AppColors.onColoredFill,
              child: const ExcludeSemantics(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    HugeIcon(icon: HugeIcons.strokeRoundedClock01, size: 22),
                    SizedBox(height: 4),
                    Text('Adiar',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            ),
            Semantics(
              button: true,
              label: 'Excluir tarefa',
              child: CustomSlidableAction(
              onPressed: (_) {
                HapticService().taskDeleted();
                widget.onDeleteRequested?.call();
              },
              backgroundColor: AppColors.priorityHigh,
              foregroundColor: AppColors.onColoredFill,
              borderRadius:
                  const BorderRadius.horizontal(right: Radius.circular(12)),
              child: const ExcludeSemantics(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    HugeIcon(icon: HugeIcons.strokeRoundedDelete01, size: 22),
                    SizedBox(height: 4),
                    Text('Excluir',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            ),
          ],
        ),
        child: widget.child,
      ),
    );
  }
}
