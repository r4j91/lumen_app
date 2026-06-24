import 'package:flutter/material.dart';
import '../../../services/haptic_service.dart';
import '../../../theme/app_colors.dart';

class ProjectOption {
  final String id;
  final String name;
  const ProjectOption(this.id, this.name);
}

class TaskProjectPickerSheet extends StatelessWidget {
  final List<ProjectOption> projects;
  final ProjectOption? current;
  final void Function(ProjectOption?) onSelected;

  const TaskProjectPickerSheet({
    super.key,
    required this.projects,
    required this.current,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppColors.textTertiary.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text('Projeto', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 0.5, color: Color(0xFF3A3B40)),
          const SizedBox(height: 4),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                    leading: Icon(Icons.inbox_outlined, size: 20,
                        color: current == null ? AppColors.accent : AppColors.textSecondary),
                    title: Text('Sem projeto', style: TextStyle(
                        fontSize: 16, color: AppColors.textPrimary,
                        fontWeight: current == null ? FontWeight.w600 : FontWeight.w500)),
                    trailing: current == null ? Icon(Icons.check, size: 18, color: AppColors.accent) : null,
                    dense: true,
                    visualDensity: const VisualDensity(horizontal: 0, vertical: -1),
                    onTap: () {
                      HapticService().selectionClick();
                      onSelected(null);
                      Navigator.of(context, rootNavigator: true).pop();
                    },
                  ),
                  for (final p in projects)
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                      leading: Icon(Icons.folder_outlined, size: 20,
                          color: current?.id == p.id ? AppColors.accent : AppColors.textSecondary),
                      title: Text(p.name, style: TextStyle(
                          fontSize: 16, color: AppColors.textPrimary,
                          fontWeight: current?.id == p.id ? FontWeight.w600 : FontWeight.w500),
                          overflow: TextOverflow.ellipsis),
                      trailing: current?.id == p.id ? Icon(Icons.check, size: 18, color: AppColors.accent) : null,
                      dense: true,
                      visualDensity: const VisualDensity(horizontal: 0, vertical: -1),
                      onTap: () {
                        HapticService().selectionClick();
                        onSelected(p);
                        Navigator.of(context, rootNavigator: true).pop();
                      },
                    ),
                ],
              ),
            ),
          ),
          SizedBox(height: 8 + View.of(context).padding.bottom / View.of(context).devicePixelRatio),
        ],
      ),
    );
  }
}
