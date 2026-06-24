import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/haptic_service.dart';
import '../services/supabase_client.dart';
import '../theme/app_colors.dart';

// ── Public entry-point ────────────────────────────────────────────────────────

Future<void> showTaskContextSheet(
  BuildContext context, {
  required Task task,
  VoidCallback? onEdit,
  VoidCallback? onComplete,
  VoidCallback? onDelete,
  VoidCallback? onRefresh,
}) async {
  HapticService().lightImpact();

  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _TaskContextSheet(
      task: task,
      onEdit: onEdit,
      onComplete: onComplete,
      onDelete: onDelete,
      onRefresh: onRefresh,
    ),
  );
}

// ── Sheet widget ──────────────────────────────────────────────────────────────

class _TaskContextSheet extends StatelessWidget {
  final Task task;
  final VoidCallback? onEdit;
  final VoidCallback? onComplete;
  final VoidCallback? onDelete;
  final VoidCallback? onRefresh;

  const _TaskContextSheet({
    required this.task,
    this.onEdit,
    this.onComplete,
    this.onDelete,
    this.onRefresh,
  });

  void _pop(BuildContext ctx) => Navigator.of(ctx, rootNavigator: true).pop();

  Future<void> _duplicate(BuildContext ctx) async {
    _pop(ctx);
    HapticService().selectionClick();
    await _duplicateTask(task);
    onRefresh?.call();
  }

  Future<void> _showPrioritySheet(BuildContext ctx) async {
    _pop(ctx);
    await Future.delayed(const Duration(milliseconds: 180));
    if (!ctx.mounted) return;
    await showModalBottomSheet<void>(
      context: ctx,
      useRootNavigator: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (ctx2) => _PrioritySheet(task: task, onRefresh: onRefresh),
    );
  }

  Future<void> _showProjectSheet(BuildContext ctx) async {
    _pop(ctx);
    await Future.delayed(const Duration(milliseconds: 180));
    if (!ctx.mounted) return;
    final projects = await _fetchProjects();
    if (!ctx.mounted) return;
    await showModalBottomSheet<void>(
      context: ctx,
      useRootNavigator: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (ctx2) =>
          _ProjectSheet(task: task, projects: projects, onRefresh: onRefresh),
    );
  }

  Future<void> _confirmDelete(BuildContext ctx) async {
    _pop(ctx);
    await Future.delayed(const Duration(milliseconds: 180));
    if (!ctx.mounted) return;
    final confirmed = await showCupertinoDialog<bool>(
      context: ctx,
      barrierDismissible: true,
      builder: (dCtx) => CupertinoAlertDialog(
        title: const Text('Excluir tarefa'),
        content: Text('Excluir "${task.title}"? Esta ação não pode ser desfeita.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dCtx).pop(false),
            child: const Text('Cancelar'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              HapticService().taskDeleted();
              Navigator.of(dCtx).pop(true);
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed == true) onDelete?.call();
  }

  @override
  Widget build(BuildContext context) {
    final projectName =
        task.project.isNotEmpty ? task.project : null;

    return Material(
      color: AppColors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textTertiary.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (projectName != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    projectName,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 0.5, color: Color(0xFF3A3B40)),
          const SizedBox(height: 4),

          // Group 1: Editar, Concluir, Duplicar
          _SheetTile(
            icon: Icons.edit_outlined,
            label: 'Editar',
            onTap: () {
              _pop(context);
              HapticService().selectionClick();
              onEdit?.call();
            },
          ),
          _SheetTile(
            icon: Icons.check_circle_outline,
            label: 'Concluir',
            onTap: () {
              _pop(context);
              HapticService().taskCompleted();
              onComplete?.call();
            },
          ),
          _SheetTile(
            icon: Icons.copy_outlined,
            label: 'Duplicar',
            onTap: () => _duplicate(context),
          ),

          const SizedBox(height: 4),
          const Divider(height: 1, thickness: 0.5, color: Color(0xFF3A3B40)),
          const SizedBox(height: 4),

          // Group 2: Prioridade, Mover para projeto
          _SheetTile(
            icon: Icons.flag_outlined,
            label: 'Prioridade',
            trailing: Icon(Icons.chevron_right,
                size: 18, color: AppColors.textTertiary),
            onTap: () => _showPrioritySheet(context),
          ),
          _SheetTile(
            icon: Icons.folder_outlined,
            label: 'Mover para projeto',
            trailing: Icon(Icons.chevron_right,
                size: 18, color: AppColors.textTertiary),
            onTap: () => _showProjectSheet(context),
          ),

          const SizedBox(height: 4),
          const Divider(height: 1, thickness: 0.5, color: Color(0xFF3A3B40)),
          const SizedBox(height: 4),

          // Group 3: Excluir
          _SheetTile(
            icon: Icons.delete_outline,
            label: 'Excluir',
            destructive: true,
            onTap: () => _confirmDelete(context),
          ),

          SizedBox(
              height: 8 + View.of(context).padding.bottom / View.of(context).devicePixelRatio),
        ],
      ),
    );
  }
}

// ── Shared tile ───────────────────────────────────────────────────────────────

class _SheetTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool destructive;
  final Widget? trailing;
  final VoidCallback onTap;

  const _SheetTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        destructive ? AppColors.priorityHigh : AppColors.textPrimary;
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: Icon(icon, size: 20, color: color),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 16,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: trailing,
      onTap: onTap,
      dense: true,
      visualDensity: const VisualDensity(horizontal: 0, vertical: -1),
    );
  }
}

// ── Priority sub-sheet ────────────────────────────────────────────────────────

class _PrioritySheet extends StatelessWidget {
  final Task task;
  final VoidCallback? onRefresh;

  const _PrioritySheet({required this.task, this.onRefresh});

  static final _options = [
    (value: 'high',   label: 'Prioridade Alta',  color: AppColors.priorityHigh),
    (value: 'medium', label: 'Prioridade Média',  color: AppColors.priorityMedium),
    (value: 'low',    label: 'Prioridade Baixa',  color: AppColors.priorityLow),
    (value: 'none',   label: 'Sem prioridade',    color: AppColors.textTertiary),
  ];

  String get _currentValue => switch (task.priority) {
        Priority.high   => 'high',
        Priority.medium => 'medium',
        Priority.low    => 'low',
        null            => 'none',
      };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textTertiary.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Prioridade',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 0.5, color: Color(0xFF3A3B40)),
          const SizedBox(height: 4),
          for (final opt in _options)
            ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
              leading: Icon(
                opt.value == 'none' ? Icons.flag_outlined : Icons.flag,
                size: 20,
                color: opt.color,
              ),
              title: Text(
                opt.label,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              trailing: _currentValue == opt.value
                  ? Icon(Icons.check, size: 18, color: AppColors.accent)
                  : null,
              dense: true,
              visualDensity: const VisualDensity(horizontal: 0, vertical: -1),
              onTap: () async {
                HapticService().selectionClick();
                Navigator.of(context, rootNavigator: true).pop();
                final prioStr = opt.value == 'none' ? null : opt.value;
                try {
                  await supabase
                      .from('tasks')
                      .update({'prioridade': prioStr})
                      .eq('id', task.id);
                  onRefresh?.call();
                } catch (_) {}
              },
            ),
          SizedBox(
              height: 8 + View.of(context).padding.bottom / View.of(context).devicePixelRatio),
        ],
      ),
    );
  }
}

// ── Project sub-sheet ─────────────────────────────────────────────────────────

class _ProjectSheet extends StatelessWidget {
  final Task task;
  final List<({String id, String name})> projects;
  final VoidCallback? onRefresh;

  const _ProjectSheet({
    required this.task,
    required this.projects,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      (id: '', name: 'Sem projeto'),
      ...projects,
    ];

    return Material(
      color: AppColors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textTertiary.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Mover para projeto',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 0.5, color: Color(0xFF3A3B40)),
          const SizedBox(height: 4),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final proj in items)
                    ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                      leading: Icon(
                        proj.id.isEmpty
                            ? Icons.inbox_outlined
                            : Icons.folder_outlined,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                      title: Text(
                        proj.name,
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      trailing: task.project == proj.name
                          ? Icon(Icons.check, size: 18, color: AppColors.accent)
                          : null,
                      dense: true,
                      visualDensity:
                          const VisualDensity(horizontal: 0, vertical: -1),
                      onTap: () async {
                        HapticService().selectionClick();
                        Navigator.of(context, rootNavigator: true).pop();
                        try {
                          final newId =
                              proj.id.isEmpty ? null : proj.id;
                          await supabase
                              .from('tasks')
                              .update({'project_id': newId})
                              .eq('id', task.id);
                          onRefresh?.call();
                        } catch (_) {}
                      },
                    ),
                ],
              ),
            ),
          ),
          SizedBox(
              height: 8 + View.of(context).padding.bottom / View.of(context).devicePixelRatio),
        ],
      ),
    );
  }
}

// ── Data helpers ──────────────────────────────────────────────────────────────

Future<List<({String id, String name})>> _fetchProjects() async {
  try {
    final rows = await supabase
        .from('projects')
        .select('id, nome')
        .order('nome')
        .timeout(const Duration(seconds: 4));
    return (rows as List)
        .map((r) => (id: r['id'].toString(), name: r['nome'] as String))
        .toList();
  } catch (_) {
    return [];
  }
}

Future<void> _duplicateTask(Task task) async {
  final userId = supabase.auth.currentUser?.id;
  final pad = (int n) => n.toString().padLeft(2, '0');
  final prioStr = switch (task.priority) {
    Priority.high   => 'high',
    Priority.medium => 'medium',
    Priority.low    => 'low',
    null            => null,
  };
  try {
    final inserted = await supabase
        .from('tasks')
        .insert({
          'titulo': '${task.title} (cópia)',
          'descricao': task.description,
          'prioridade': prioStr,
          'hora': task.time,
          'concluida': false,
          if (task.dueDate != null)
            'data_vencimento':
                '${task.dueDate!.year}-${pad(task.dueDate!.month)}-${pad(task.dueDate!.day)}',
          if (userId != null) 'user_id': userId,
        })
        .select('id')
        .single();
    final newId = inserted['id'].toString();
    if (task.labels.isNotEmpty) {
      await supabase.from('task_labels').insert(
        task.labels.map((l) => {'task_id': newId, 'label_id': l.id}).toList(),
      );
    }
  } catch (_) {}
}
