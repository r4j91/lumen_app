import 'package:flutter/material.dart';
import '../../models/task.dart';
import '../../theme/app_colors.dart';
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
/// Todos os ícones são exibidos em tom neutro (textSecondary).
/// O valor pode ser texto simples (via [value]) ou widget customizado (via [valueWidget]).
class TaskMetaRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? value;
  final Widget? valueWidget;
  final bool active;
  final VoidCallback onTap;

  const TaskMetaRow({
    super.key,
    required this.icon,
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
            Icon(icon, size: 16, color: AppColors.textSecondary),
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

// ADICIONADO_REDESIGN_DETAIL: pílula compacta para campos vazios (scroll
// horizontal), padrão Todoist.
class FieldPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const FieldPill({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        // CORRIGIDO_VISUAL_A: padding aumentado (10/5 -> 12/7).
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          // CORRIGIDO_REDESIGN_DETAIL_PILL: fundo/borda ajustados (cores
          // brancas explícitas, não herdadas de surfaceVariant do tema).
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // CORRIGIDO_VISUAL_A: ícone 13 -> 15.
            Icon(icon, size: 15, color: Colors.white.withValues(alpha: 0.5)),
            const SizedBox(width: 5),
            // CORRIGIDO_VISUAL_A: texto 11 -> 13.
            Text(label,
                style: TextStyle(
                    fontSize: 13, color: Colors.white.withValues(alpha: 0.55))),
          ],
        ),
      ),
    );
  }
}

// ADICIONADO_REDESIGN_DETAIL: linha de metadado compacta para campos já
// preenchidos (substitui TaskMetaRow nesse estado, sem título nem chevron).
class MetaRow extends StatelessWidget {
  final IconData icon;
  final Widget child;
  final VoidCallback onTap;

  const MetaRow({
    super.key,
    required this.icon,
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      // CORRIGIDO_SUBTASK_TAP: behavior opaco garante que toda a área do
      // Padding (não só onde há pixels desenhados) responda ao toque.
      mouseCursor: SystemMouseCursors.click,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Padding(
        // CORRIGIDO_SUBTASK_TAP: padding vertical 6 -> 9 (18px de altura
        // extra de área de toque, mais próximo do mínimo recomendado).
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            // CORRIGIDO_VISUAL_A: ícone 14 -> 18.
            Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.35)),
            // CORRIGIDO_VISUAL_A: espaçamento 10 -> 12.
            const SizedBox(width: 12),
            Expanded(child: child),
          ],
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
