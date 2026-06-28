import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/subtask.dart';
import '../../services/haptic_service.dart';
import '../../services/subtask_repository.dart';
import '../../theme/app_colors.dart';
import '../task_tile.dart' show TagChip;
import './subtask_item.dart';
import './sheets/task_labels_picker_sheet.dart';
import 'package:hugeicons/hugeicons.dart';
// import './sheets/subtask_options_sheet.dart'; // replaced by subtask_detail_sheet.dart
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
  static const _repo = SubtaskRepository();
  static const _debounceDuration = Duration(milliseconds: 700);

  bool _descVisible = false;
  Timer? _titleDebounce;
  Timer? _descDebounce;

  @override
  void initState() {
    super.initState();
    _descVisible = widget.item.descCtrl.text.isNotEmpty;
    widget.item.focus.addListener(_onTitleFocus);
    widget.item.descCtrl.addListener(_onDescText);
    widget.item.ctrl.addListener(_onTitleText);
  }

  @override
  void dispose() {
    widget.item.focus.removeListener(_onTitleFocus);
    widget.item.descCtrl.removeListener(_onDescText);
    widget.item.ctrl.removeListener(_onTitleText);
    _titleDebounce?.cancel();
    _descDebounce?.cancel();
    super.dispose();
  }

  void _onTitleFocus() {
    if (!mounted) return;
    if (widget.item.focus.hasFocus && !_descVisible) setState(() => _descVisible = true);
  }

  void _onDescText() {
    if (!mounted) return;
    final hasText = widget.item.descCtrl.text.isNotEmpty;
    if (hasText != _descVisible) setState(() => _descVisible = hasText);
    _descDebounce?.cancel();
    _descDebounce = Timer(_debounceDuration, () => _persistField('descricao', widget.item.descCtrl.text.trim()));
  }

  void _onTitleText() {
    _titleDebounce?.cancel();
    final title = widget.item.ctrl.text.trim();
    if (title.isEmpty) return;
    _titleDebounce = Timer(_debounceDuration, () => _persistField('titulo', title));
  }

  Future<void> _persistField(String column, String value) async {
    widget.item.order = widget.index;
    try {
      await _repo.persistSubtask(
        id: widget.item.id,
        taskId: widget.item.taskId,
        order: widget.item.order,
        fields: {column: value.isEmpty ? null : value},
        onIdResolved: (resolved) => widget.item.id = resolved,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Não foi possível salvar'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.priorityHigh,
      ));
    }
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

  Widget _safeContextMenu(BuildContext context, EditableTextState state, FocusNode node) {
    if (!node.hasFocus) return const SizedBox.shrink();
    return AdaptiveTextSelectionToolbar.editableText(editableTextState: state);
  }

  @override
  Widget build(BuildContext context) {
    final priColor = _priorityColor(widget.item.priority);
    final hasDate = widget.item.dueDate != null;
    final hasLabels = widget.item.labelIds.isNotEmpty;
    final hasValor = widget.item.valor != null;

    return GestureDetector(
      onLongPress: _showOptionsSheet,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: widget.onToggle,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.item.done ? priColor.withValues(alpha: 0.15) : Colors.transparent,
                    border: Border.all(color: priColor, width: 1.6),
                  ),
                  child: widget.item.done
                      ? HugeIcon(icon: HugeIcons.strokeRoundedTick01, size: 12, color: priColor)
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: widget.item.ctrl,
                    focusNode: widget.item.focus,
                    contextMenuBuilder: (ctx, state) =>
                        _safeContextMenu(ctx, state, widget.item.focus),
                    style: TextStyle(
                      fontSize: 15,
                      color: widget.item.done ? AppColors.textTertiary : AppColors.textPrimary,
                      decoration: widget.item.done ? TextDecoration.lineThrough : TextDecoration.none,
                      decorationColor: AppColors.textTertiary,
                      height: 1.35,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Nova subtarefa',
                      hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 15),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOutCubic,
                    child: _descVisible
                        ? TextField(
                            controller: widget.item.descCtrl,
                            focusNode: widget.item.descFocus,
                            contextMenuBuilder: (ctx, state) =>
                                _safeContextMenu(ctx, state, widget.item.descFocus),
                            maxLines: null,
                            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.45),
                            decoration: InputDecoration(
                              hintText: 'Descrição...',
                              hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 12.5),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              isDense: true,
                              contentPadding: const EdgeInsets.only(bottom: 4),
                            ),
                            textCapitalization: TextCapitalization.sentences,
                          )
                        : const SizedBox.shrink(),
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
                              color: AppColors.dateUpcoming,
                              hugeIcon: HugeIcons.strokeRoundedCalendar01,
                            ),
                          ...widget.labels
                              .where((l) => widget.item.labelIds.contains(l.id))
                              .map((l) => TagChip(
                                    label: l.name,
                                    color: l.color,
                                  )),
                          // Valor da parcela (gerador de parcelas / edição manual).
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
            ReorderableDragStartListener(
              index: widget.index,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                child: HugeIcon(icon: HugeIcons.strokeRoundedMoreVertical, size: 16, color: AppColors.textTertiary.withValues(alpha: 0.4)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
