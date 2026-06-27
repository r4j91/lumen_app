import 'package:flutter/material.dart';
import '../../../models/task.dart';
import '../../../services/haptic_service.dart';
import '../../../theme/app_colors.dart';
import 'package:hugeicons/hugeicons.dart';

class TaskPriorityPickerSheet extends StatelessWidget {
  final Priority? current;
  final void Function(Priority?) onSelected;

  const TaskPriorityPickerSheet({
    super.key,
    required this.current,
    required this.onSelected,
  });

  static final _opts = [
    (value: Priority.high,   label: 'Prioridade 1', color: const Color(0xFFDC4C3E), icon: Icons.flag),
    (value: Priority.medium, label: 'Prioridade 2', color: const Color(0xFFEB8909), icon: Icons.flag),
    (value: Priority.low,    label: 'Prioridade 3', color: const Color(0xFF246FE0), icon: Icons.flag),
    (value: null as Priority?,         label: 'Sem prioridade', color: const Color(0xFF6B6E76), icon: Icons.flag_outlined),
  ];

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
            child: Text('Prioridade', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 0.5, color: Color(0xFF3A3B40)),
          const SizedBox(height: 4),
          for (final opt in _opts)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
              leading: Icon(opt.icon, size: 20, color: opt.color),
              title: Text(opt.label, style: TextStyle(fontSize: 16, color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
              trailing: current == opt.value ? HugeIcon(icon: HugeIcons.strokeRoundedTick01, size: 18, color: opt.color) : null,
              dense: true,
              visualDensity: const VisualDensity(horizontal: 0, vertical: -1),
              onTap: () {
                HapticService().prioritySelected();
                onSelected(opt.value);
                Navigator.of(context, rootNavigator: true).pop();
              },
            ),
          SizedBox(height: 8 + View.of(context).padding.bottom / View.of(context).devicePixelRatio),
        ],
      ),
    );
  }
}
