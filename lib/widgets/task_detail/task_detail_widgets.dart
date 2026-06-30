import 'package:flutter/material.dart';
import '../../models/task.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import 'package:hugeicons/hugeicons.dart';

class TaskPriorityCircle extends StatelessWidget {
  final Priority? priority;
  const TaskPriorityCircle({super.key, required this.priority});

  Color get _color => switch (priority) {
    Priority.high   => AppColors.priorityHigh,
    Priority.medium => AppColors.priorityMedium,
    Priority.low    => AppColors.priorityLow,
    null            => AppColors.textTertiary,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      margin: const EdgeInsets.only(top: 3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _color.withValues(alpha: 0.12),
        border: Border.all(color: _color, width: 2.5),
      ),
    );
  }
}

/// Linha de metadado com layout [ícone] [título] ··· [valor] [chevron].
class TaskMetaRow extends StatelessWidget {
  final List<List<dynamic>> hugeIcon;
  final String title;
  final String? value;
  final Widget? valueWidget;
  final bool active;
  final VoidCallback onTap;

  const TaskMetaRow({
    super.key,
    required this.hugeIcon,
    required this.title,
    this.value,
    this.valueWidget,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            HugeIcon(icon: hugeIcon, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Align(
                alignment: Alignment.centerRight,
                child: valueWidget != null
                    ? valueWidget!
                    : Text(
                        value ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: active ? AppColors.textPrimary : AppColors.textTertiary,
                          fontWeight: active ? FontWeight.w500 : FontWeight.w400,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
              ),
            ),
            const SizedBox(width: 6),
            HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01,
              size: 16,
              color: AppColors.textTertiary.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

class FieldPill extends StatelessWidget {
  final List<List<dynamic>> hugeIcon;
  final String label;
  final VoidCallback onTap;

  const FieldPill({
    super.key,
    required this.hugeIcon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Center(
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: AppColors.textTertiary.withValues(alpha: 0.15)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                HugeIcon(icon: hugeIcon, size: 15, color: AppColors.textSecondary),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.0,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MetaRow extends StatelessWidget {
  final List<List<dynamic>> hugeIcon;
  final Widget child;
  final VoidCallback onTap;

  const MetaRow({
    super.key,
    required this.hugeIcon,
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      mouseCursor: SystemMouseCursors.click,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              HugeIcon(icon: hugeIcon, size: 18, color: AppColors.textTertiary),
              const SizedBox(width: 12),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// Indicador discreto de prioridade: "P1 ●" com ponto colorido.
class PriorityValueWidget extends StatelessWidget {
  final Priority priority;
  const PriorityValueWidget({super.key, required this.priority});

  Color get _color => switch (priority) {
    Priority.high   => AppColors.priorityHigh,
    Priority.medium => AppColors.priorityMedium,
    Priority.low    => AppColors.priorityLow,
  };

  String get _label => switch (priority) {
    Priority.high   => 'P1',
    Priority.medium => 'P2',
    Priority.low    => 'P3',
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _label,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _color,
          ),
        ),
      ],
    );
  }
}
