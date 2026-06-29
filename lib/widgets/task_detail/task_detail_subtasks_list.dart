import 'package:flutter/material.dart';
import 'sheets/task_labels_picker_sheet.dart' show LabelOption;
import 'subtask_editor.dart';
import 'subtask_item.dart';

/// Reorderable subtask rows for task detail — local [setState] on text edits
/// so the parent sheet (~3300 lines) does not rebuild on every keystroke.
class TaskDetailSubtasksList extends StatefulWidget {
  final List<SubtaskItem> subtasks;
  final List<LabelOption> labels;
  final void Function(SubtaskItem item) onToggle;
  final void Function(int index) onRemove;
  final void Function(int oldIndex, int newIndex) onReorder;

  const TaskDetailSubtasksList({
    super.key,
    required this.subtasks,
    required this.labels,
    required this.onToggle,
    required this.onRemove,
    required this.onReorder,
  });

  @override
  State<TaskDetailSubtasksList> createState() => _TaskDetailSubtasksListState();
}

class _TaskDetailSubtasksListState extends State<TaskDetailSubtasksList> {
  void _localRefresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (widget.subtasks.isEmpty) return const SizedBox.shrink();

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.only(top: 4),
      itemCount: widget.subtasks.length,
      onReorderItem: (oldIndex, newIndex) {
        widget.onReorder(oldIndex, newIndex);
        _localRefresh();
      },
      itemBuilder: (context, i) {
        final s = widget.subtasks[i];
        return SubtaskEditorRow(
          key: ValueKey(s.uid),
          item: s,
          index: i,
          labels: widget.labels,
          onToggle: () => widget.onToggle(s),
          onRemove: () => widget.onRemove(i),
          onChanged: _localRefresh,
        );
      },
    );
  }
}
