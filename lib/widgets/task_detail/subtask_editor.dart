import 'package:flutter/material.dart';
import '../../models/subtask.dart';
import '../../services/haptic_service.dart';
import '../../theme/app_colors.dart';
import '../done_circle.dart';
import '../task_tile.dart' show TagChip;
import './subtask_item.dart';
import './sheets/task_labels_picker_sheet.dart';
import 'package:hugeicons/hugeicons.dart';
import './sheets/subtask_detail_sheet.dart';

class SubtaskEditorRow extends StatefulWidget {
  final SubtaskItem item;
  final int index;
  final List<LabelOption> labels;
  final VoidCallback onToggle;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const SubtaskEditorRow({
    super.key,
    required this.item,
    required this.index,
    required this.labels,
    required this.onToggle,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  State<SubtaskEditorRow> createState() => _SubtaskEditorRowState();
}

class _SubtaskEditorRowState extends State<SubtaskEditorRow> {
  @override
  void initState() {
    super.initState();
    widget.item.ctrl.addListener(_onTextChanged);
    widget.item.descCtrl.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.item.ctrl.removeListener(_onTextChanged);
    widget.item.descCtrl.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  void _showOptionsSheet() {
    FocusManager.instance.primaryFocus?.unfocus();
    widget.item.order = widget.index;
    HapticService().lightImpact();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showSubtaskDetailSheet(
        context: context,
        item: widget.item,
        labels: widget.labels,
        onChanged: () {
          setState(() {});
          widget.onChanged();
        },
      );
    });
  }

  String _formatDate(SubtaskItem item) {
    if (item.dueDate == null) return '';
    final d = item.dueDate!;
    final months = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
    final base = '${d.day} ${months[d.month - 1]}';
    if (item.dueTime != null) {
      return '$base ${item.dueTime!.hour.toString().padLeft(2, '0')}:${item.dueTime!.minute.toString().padLeft(2, '0')}';
    }
    return base;
  }

  Color _priorityColor(SubtaskPriority? p) => p?.color ?? AppColors.textTertiary;

  Color _dueDateColor(SubtaskItem item) {
    if (item.dueDate == null) return AppColors.dateUpcoming;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(item.dueDate!.year, item.dueDate!.month, item.dueDate!.day);
    final diff = due.difference(today).inDays;
    if (diff == 0) return AppColors.dateDueToday;
    if (diff < 0) return AppColors.dateOverdue;
    return AppColors.dateUpcoming;
  }

  @override
  Widget build(BuildContext context) {
    final priColor = _priorityColor(widget.item.priority);
    final hasDate = widget.item.dueDate != null;
    final hasLabels = widget.item.labelIds.isNotEmpty;
    final hasValor = widget.item.valor != null;
    final title = widget.item.ctrl.text.trim();
    final desc = widget.item.descCtrl.text.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: widget.onToggle,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: DoneCircle(
                  done: widget.item.done,
                  size: 22,
                  borderWidth: 1.6,
                  tickSize: 12,
                  ringColor: priColor,
                  ringFillAlpha: 0.08,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: _showOptionsSheet,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      title.isEmpty ? 'Nova subtarefa' : title,
                      style: TextStyle(
                        fontSize: 15,
                        color: title.isEmpty
                            ? AppColors.textTertiary
                            : (widget.item.done
                                ? AppColors.textTertiary
                                : AppColors.textPrimary),
                        decoration:
                            widget.item.done ? TextDecoration.lineThrough : TextDecoration.none,
                        decorationColor: AppColors.textTertiary,
                        height: 1.35,
                        fontStyle: title.isEmpty ? FontStyle.italic : null,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (desc.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        desc,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                          height: 1.45,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (hasDate || hasLabels || hasValor)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (hasDate)
                            TagChip(
                              label: _formatDate(widget.item),
                              color: _dueDateColor(widget.item),
                              hugeIcon: HugeIcons.strokeRoundedCalendar01,
                            ),
                          ...widget.labels
                              .where((l) => widget.item.labelIds.contains(l.id))
                              .map((l) => TagChip(
                                    label: l.name,
                                    color: l.color,
                                  )),
                          if (hasValor)
                            Text(
                              (hasDate ? '· ' : '') +
                                  'R\$ ${widget.item.valor!.toStringAsFixed(2).replaceAll('.', ',')}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF34C759),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: _showOptionsSheet,
            child: ReorderableDragStartListener(
              index: widget.index,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedMoreVertical,
                    size: 16,
                    color: AppColors.textTertiary.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
