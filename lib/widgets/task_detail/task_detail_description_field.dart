import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Notes/description field for task detail — keeps focus border state local
/// so the parent sheet does not rebuild on focus changes.
class TaskDetailDescriptionField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final EdgeInsetsGeometry padding;

  const TaskDetailDescriptionField({
    super.key,
    required this.controller,
    required this.focusNode,
    this.padding = const EdgeInsets.fromLTRB(20, 0, 20, 16),
  });

  @override
  State<TaskDetailDescriptionField> createState() =>
      _TaskDetailDescriptionFieldState();
}

class _TaskDetailDescriptionFieldState extends State<TaskDetailDescriptionField> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
    _focused = widget.focusNode.hasFocus;
  }

  @override
  void didUpdateWidget(TaskDetailDescriptionField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChange);
      widget.focusNode.addListener(_onFocusChange);
      _focused = widget.focusNode.hasFocus;
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    final next = widget.focusNode.hasFocus;
    if (next != _focused && mounted) setState(() => _focused = next);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.padding,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _focused
                ? AppColors.accent.withValues(alpha: 0.5)
                : AppColors.textTertiary.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        child: TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          cursorColor: AppColors.accent,
          cursorWidth: 1.5,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.55,
          ),
          decoration: InputDecoration(
            hintText: 'Adicionar notas...',
            hintStyle: TextStyle(
              color: AppColors.textTertiary.withValues(alpha: 0.55),
              fontSize: 14,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
            filled: true,
            fillColor: Colors.transparent,
          ),
          maxLines: null,
        ),
      ),
    );
  }
}
