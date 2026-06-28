import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../models/task.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/task_tile.dart' show TagChip, PriorityDot, dueDateTagChip, TaskMetaLine;

/// Preview visual das opções de layout de metadados (etiquetas, data, contadores).
class TaskMetaPreviewScreen extends StatelessWidget {
  const TaskMetaPreviewScreen({super.key});

  static const _labelColor = Color(0xFFD4A843);
  static const _labelName = 'Em Análise';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: HugeIcon(icon: HugeIcons.strokeRoundedArrowLeft01, size: 18, color: AppColors.textSecondary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Preview: meta da tarefa',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 120),
        children: [
          Text(
            'Compare como etiquetas, datas e contadores aparecem na linha da tarefa (modo lista).',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.45),
          ),
          const SizedBox(height: AppSpacing.xl),
          _OptionBlock(
            title: 'Atual (modo lista)',
            subtitle: 'Etiquetas numa linha; contadores + data noutra — parece fragmentado',
            badge: 'baseline',
            child: _ListFrame(
              child: _CurrentLayout(
                title: 'Embalagens',
                description: 'Ver esses saldos para passar o pedido pa…',
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          _OptionBlock(
            title: 'A — Linha única unificada',
            subtitle: 'Chips coloridos juntos · contadores discretos à direita com separador ·',
            badge: 'recomendada',
            accentBadge: true,
            child: _ListFrame(
              child: _UnifiedMetaLine(
                title: 'Embalagens',
                description: 'Ver esses saldos para passar o pedido pa…',
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          _OptionBlock(
            title: 'B — Data à direita do título',
            subtitle: 'Scan rápido da data; tags e contadores abaixo',
            child: _ListFrame(
              child: _DateRightLayout(
                title: 'Embalagens',
                description: 'Ver esses saldos para passar o pedido pa…',
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          _OptionBlock(
            title: 'C — Chips vs. contadores',
            subtitle: 'Esquerda = semântico (cor) · direita = operacional (números)',
            child: _ListFrame(
              child: _SplitMetaLayout(
                title: 'Embalagens',
                description: 'Ver esses saldos para passar o pedido pa…',
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          _OptionBlock(
            title: 'Variações compactas',
            subtitle: 'Mesma tarefa com menos metadados — alinhamento se mantém',
            child: Column(
              children: [
                _ListFrame(
                  child: _UnifiedMetaLine(
                    title: 'Teste 77',
                    description: null,
                    showLabel: false,
                    subtasks: '0/1',
                    comments: 0,
                  ),
                ),
                const SizedBox(height: 10),
                _ListFrame(
                  child: _UnifiedMetaLine(
                    title: 'Tfghvv',
                    description: 'Bvbbb',
                    labelName: 'Em Andamento',
                    labelColor: AppColors.accent,
                    showDate: false,
                    subtasks: '1/5',
                    comments: 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared sample widgets ─────────────────────────────────────────────────────

class _OptionBlock extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? badge;
  final bool accentBadge;
  final Widget child;

  const _OptionBlock({
    required this.title,
    required this.subtitle,
    required this.child,
    this.badge,
    this.accentBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accentBadge
                      ? AppColors.accent.withValues(alpha: 0.15)
                      : AppColors.textTertiary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(99),
                  border: accentBadge ? Border.all(color: AppColors.accent.withValues(alpha: 0.35)) : null,
                ),
                child: Text(
                  badge!,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: accentBadge ? AppColors.accent : AppColors.textTertiary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.35)),
        const SizedBox(height: AppSpacing.md),
        child,
      ],
    );
  }
}

class _ListFrame extends StatelessWidget {
  final Widget child;
  const _ListFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.textTertiary.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          child,
          Divider(height: 1, thickness: 0.5, color: AppColors.textTertiary.withValues(alpha: 0.1)),
          Opacity(
            opacity: 0.45,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(36, 8, 18, 8),
              child: Row(
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.textTertiary, width: 2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('Subtarefa expandida…', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskRowShell extends StatelessWidget {
  final String title;
  final String? description;
  final Widget meta;
  final Widget? trailingMeta;

  const _TaskRowShell({
    required this.title,
    required this.meta,
    this.description,
    this.trailingMeta,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 10, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: PriorityDot(priority: Priority.medium, done: false),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                          ),
                          if (description != null && description!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                description!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (trailingMeta != null) ...[
                      const SizedBox(width: 8),
                      trailingMeta!,
                    ],
                  ],
                ),
                Padding(padding: const EdgeInsets.only(top: 4), child: meta),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: HugeIcon(icon: HugeIcons.strokeRoundedArrowUp01, size: 18, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _MetaCounters extends StatelessWidget {
  final String subtasks;
  final int comments;
  final String separator;

  const _MetaCounters({
    this.subtasks = '0/2',
    this.comments = 1,
    this.separator = '·',
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        HugeIcon(icon: HugeIcons.strokeRoundedTaskDone01, size: 12, color: AppColors.textTertiary),
        const SizedBox(width: 3),
        Text(subtasks, style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
        if (comments > 0) ...[
          Text(' $separator ', style: TextStyle(fontSize: 12, color: AppColors.textTertiary.withValues(alpha: 0.5))),
          HugeIcon(icon: HugeIcons.strokeRoundedComment01, size: 12, color: AppColors.textTertiary),
          const SizedBox(width: 3),
          Text('$comments', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
        ],
      ],
    );
  }
}

// ── Layout: atual ─────────────────────────────────────────────────────────────

class _CurrentLayout extends StatelessWidget {
  final String title;
  final String? description;

  const _CurrentLayout({required this.title, this.description});

  @override
  Widget build(BuildContext context) {
    return _TaskRowShell(
      title: title,
      description: description,
      meta: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              TagChip(label: TaskMetaPreviewScreen._labelName, color: TaskMetaPreviewScreen._labelColor),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                const _MetaCounters(),
                const SizedBox(width: 8),
                dueDateTagChip(DateTime.now()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Layout A: linha única ────────────────────────────────────────────────────

class _UnifiedMetaLine extends StatelessWidget {
  final String title;
  final String? description;
  final bool showLabel;
  final bool showDate;
  final String labelName;
  final Color labelColor;
  final String subtasks;
  final int comments;

  const _UnifiedMetaLine({
    required this.title,
    this.description,
    this.showLabel = true,
    this.showDate = true,
    this.labelName = TaskMetaPreviewScreen._labelName,
    this.labelColor = TaskMetaPreviewScreen._labelColor,
    this.subtasks = '0/2',
    this.comments = 1,
  });

  @override
  Widget build(BuildContext context) {
    return _TaskRowShell(
      title: title,
      description: description,
      meta: TaskMetaLine(
        labels: showLabel
            ? [TaskLabel(id: '1', name: labelName, color: labelColor)]
            : const [],
        dueDate: showDate ? DateTime.now() : null,
        subtasksDone: int.tryParse(subtasks.split('/').first) ?? 0,
        subtasksTotal: int.tryParse(subtasks.split('/').last) ?? 0,
        commentCount: comments,
      ),
    );
  }
}

// ── Layout B: data à direita ──────────────────────────────────────────────────

class _DateRightLayout extends StatelessWidget {
  final String title;
  final String? description;

  const _DateRightLayout({required this.title, this.description});

  @override
  Widget build(BuildContext context) {
    return _TaskRowShell(
      title: title,
      description: description,
      trailingMeta: dueDateTagChip(DateTime.now()),
      meta: Row(
        children: [
          TagChip(label: TaskMetaPreviewScreen._labelName, color: TaskMetaPreviewScreen._labelColor),
          const Spacer(),
          const _MetaCounters(),
        ],
      ),
    );
  }
}

// ── Layout C: split semântico / operacional ─────────────────────────────────

class _SplitMetaLayout extends StatelessWidget {
  final String title;
  final String? description;

  const _SplitMetaLayout({required this.title, this.description});

  @override
  Widget build(BuildContext context) {
    return _TaskRowShell(
      title: title,
      description: description,
      meta: Row(
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              TagChip(label: TaskMetaPreviewScreen._labelName, color: TaskMetaPreviewScreen._labelColor),
              dueDateTagChip(DateTime.now()),
            ],
          ),
          const Spacer(),
          const _MetaCounters(separator: ''),
        ],
      ),
    );
  }
}
