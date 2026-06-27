import 'package:flutter/material.dart';
import '../../../services/haptic_service.dart';
import '../../../theme/app_colors.dart';
import 'package:hugeicons/hugeicons.dart';

class LabelOption {
  final String id;
  final String name;
  final Color color;
  const LabelOption(this.id, this.name, this.color);
}

class TaskLabelsPickerSheet extends StatefulWidget {
  final List<LabelOption> labels;
  final Set<String> selectedIds;
  final void Function(Set<String>) onChanged;

  const TaskLabelsPickerSheet({
    super.key,
    required this.labels,
    required this.selectedIds,
    required this.onChanged,
  });

  @override
  State<TaskLabelsPickerSheet> createState() => _TaskLabelsPickerSheetState();
}

class _TaskLabelsPickerSheetState extends State<TaskLabelsPickerSheet> {
  late final Set<String> _ids;

  @override
  void initState() {
    super.initState();
    _ids = Set.from(widget.selectedIds);
  }

  void _toggle(String id) {
    HapticService().selectionClick();
    setState(() {
      if (_ids.contains(id)) { _ids.remove(id); } else { _ids.add(id); }
    });
    widget.onChanged(_ids);
  }

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
            child: Text('Etiquetas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 0.5, color: Color(0xFF3A3B40)),
          const SizedBox(height: 4),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: widget.labels.map((l) {
                  final selected = _ids.contains(l.id);
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                    leading: Container(
                      width: 12, height: 12,
                      decoration: BoxDecoration(color: l.color, shape: BoxShape.circle),
                    ),
                    title: Text(l.name, style: TextStyle(fontSize: 16, color: AppColors.textPrimary,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500)),
                    trailing: selected ? HugeIcon(icon: HugeIcons.strokeRoundedTick01, size: 18, color: l.color) : null,
                    dense: true,
                    visualDensity: const VisualDensity(horizontal: 0, vertical: -1),
                    onTap: () => _toggle(l.id),
                  );
                }).toList(),
              ),
            ),
          ),
          SizedBox(height: 8 + View.of(context).padding.bottom / View.of(context).devicePixelRatio),
        ],
      ),
    );
  }
}
