import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../models/task.dart';
import '../services/haptic_service.dart';
import '../theme/app_colors.dart';
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
    with TickerProviderStateMixin { // was SingleTickerProviderStateMixin (needed 2nd controller for elevation)
  late final SlidableController _slidableCtrl;
  late final AnimationController _elevCtrl;
  late final Animation<double> _elevAnim;

  static const _startExtent = 0.28;
  static const _endExtent = 0.5;

  bool _startTriggered = false;
  bool _endTriggered = false;

  @override
  void initState() {
    super.initState();
    _slidableCtrl = SlidableController(this);
    _slidableCtrl.animation.addListener(_onRatioChanged);
    _elevCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _elevAnim = CurvedAnimation(parent: _elevCtrl, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _slidableCtrl.animation.removeListener(_onRatioChanged);
    _slidableCtrl.dispose();
    _elevCtrl.dispose();
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

  Future<void> _openContextMenu(BuildContext context, Offset tapPosition) async {
    _elevCtrl.forward();
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
    if (mounted) _elevCtrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (d) => _openContextMenu(context, d.globalPosition),
      onSecondaryTapDown: (d) => _openContextMenu(context, d.globalPosition),
      child: Slidable(
        key: ValueKey(widget.task.id),
        controller: _slidableCtrl,
        startActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: _startExtent,
          children: [
            CustomSlidableAction(
              onPressed: (_) {
                HapticService().taskCompleted();
                widget.onCompleted?.call();
                _showSnack(context, '"${widget.task.title}" concluída');
              },
              backgroundColor: const Color(0xFF3BAA6E),
              foregroundColor: Colors.white,
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(12)),
              child: const Column(
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
          ],
        ),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: _endExtent,
          children: [
            CustomSlidableAction(
              onPressed: (_) {
                HapticService().dateConfirmed();
                _showSnack(context, '"${widget.task.title}" adiada');
              },
              backgroundColor: AppColors.priorityMedium,
              foregroundColor: Colors.white,
              child: const Column(
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
            CustomSlidableAction(
              onPressed: (_) {
                HapticService().taskDeleted();
                widget.onDeleteRequested?.call();
              },
              backgroundColor: AppColors.priorityHigh,
              foregroundColor: Colors.white,
              borderRadius:
                  const BorderRadius.horizontal(right: Radius.circular(12)),
              child: const Column(
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
          ],
        ),
        child: AnimatedBuilder(
          animation: _elevAnim,
          builder: (ctx, child) {
            final t = _elevAnim.value;
            return Transform.translate(
              offset: Offset(0, -6 * t),
              child: Container(
                decoration: t > 0.01
                    ? BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.20 * t),
                            blurRadius: 16,
                            spreadRadius: -2,
                            offset: Offset(0, 6 * t),
                          ),
                        ],
                      )
                    : null,
                child: child,
              ),
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}
