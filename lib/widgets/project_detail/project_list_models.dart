import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../models/section.dart';
import '../../models/task.dart';
import '../../theme/app_colors.dart';
import '../collapsible_section_header.dart';

enum ProjectListItemKind {
  task,
  separator,
  sectionHeader,
  addTask,
  completedHeader,
  completedTask,
}

class ProjectListItem {
  final ProjectListItemKind kind;
  final int? taskIndex;
  final Section? section;
  final String? sectionId;
  final int? completedIndex;

  const ProjectListItem._({
    required this.kind,
    this.taskIndex,
    this.section,
    this.sectionId,
    this.completedIndex,
  });

  factory ProjectListItem.task(int index) =>
      ProjectListItem._(kind: ProjectListItemKind.task, taskIndex: index);

  factory ProjectListItem.separator() =>
      const ProjectListItem._(kind: ProjectListItemKind.separator);

  factory ProjectListItem.sectionHeader(Section section) =>
      ProjectListItem._(kind: ProjectListItemKind.sectionHeader, section: section);

  factory ProjectListItem.addTask(String? sectionId) =>
      ProjectListItem._(kind: ProjectListItemKind.addTask, sectionId: sectionId);

  const ProjectListItem.completedHeader()
      : kind = ProjectListItemKind.completedHeader,
        taskIndex = null,
        section = null,
        sectionId = null,
        completedIndex = null;

  factory ProjectListItem.completedTask(int index) =>
      ProjectListItem._(kind: ProjectListItemKind.completedTask, completedIndex: index);
}

List<ProjectListItem> computeProjectListItems({
  required List<Task> tasks,
  required List<Section> sections,
  required Set<String> collapsedSectionIds,
  required bool showCompleted,
  required bool completedExpanded,
  required List<Task> completedTasks,
}) {
  final items = <ProjectListItem>[];

  final grouped = <String?, List<int>>{};
  for (var i = 0; i < tasks.length; i++) {
    grouped.putIfAbsent(tasks[i].sectionId, () => []).add(i);
  }

  final nullIndices = grouped[null] ?? [];
  for (var n = 0; n < nullIndices.length; n++) {
    items.add(ProjectListItem.task(nullIndices[n]));
    if (n < nullIndices.length - 1) items.add(ProjectListItem.separator());
  }

  final sorted = [...sections]..sort((a, b) => a.order.compareTo(b.order));
  for (final section in sorted) {
    final expanded = !collapsedSectionIds.contains(section.id);
    final indices = grouped[section.id] ?? [];
    items.add(ProjectListItem.sectionHeader(section));
    if (expanded) {
      for (var n = 0; n < indices.length; n++) {
        items.add(ProjectListItem.task(indices[n]));
        items.add(ProjectListItem.separator());
      }
      items.add(ProjectListItem.addTask(section.id));
    }
  }

  if (showCompleted && completedTasks.isNotEmpty) {
    items.add(const ProjectListItem.completedHeader());
  }
  if (showCompleted && completedExpanded) {
    for (var ci = 0; ci < completedTasks.length; ci++) {
      items.add(ProjectListItem.completedTask(ci));
    }
  }

  return items;
}

/// Header row for a project section — chevron + name + count + "···" menu.
class ProjectSectionHeader extends StatelessWidget {
  final String name;
  final int count;
  final bool expanded;
  final VoidCallback onTap;
  final void Function(BuildContext ctx) onMenu;

  const ProjectSectionHeader({
    super.key,
    required this.name,
    required this.count,
    required this.expanded,
    required this.onTap,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    return CollapsibleSectionHeader(
      title: name,
      count: count,
      expanded: expanded,
      onTap: onTap,
      trailing: Builder(
        builder: (ctx) => IconButton(
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedMoreHorizontal,
            size: 18,
            color: AppColors.textTertiary,
          ),
          onPressed: () => onMenu(ctx),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}
