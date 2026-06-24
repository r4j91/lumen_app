import 'label.dart';
import 'recurrence.dart';
import 'subtask.dart';

export 'label.dart';
export 'recurrence.dart';

enum Priority { high, medium, low }

class Task {
  final String id;
  final String title;
  final String? description;
  final String project;
  final String? projectId;
  final String? sectionId;
  final Priority? priority;
  final String? time;
  final List<TaskLabel> labels;
  final List<Subtask> subtasks;
  final DateTime? dueDate;
  final bool done;
  final Recurrence? recurrence;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int commentCount;

  const Task({
    required this.id,
    required this.title,
    this.description,
    required this.project,
    this.projectId,
    this.sectionId,
    this.priority,
    this.time,
    this.labels = const [],
    this.subtasks = const [],
    this.dueDate,
    this.done = false,
    this.recurrence,
    this.createdAt,
    this.updatedAt,
    this.commentCount = 0,
  });

  List<String> get tags => labels.map((l) => l.name).toList();

  int get subtasksDone  => subtasks.where((s) => s.done).length;
  int get subtasksTotal => subtasks.length;
  bool get hasSubtasks  => subtasks.isNotEmpty;

  Task copyWith({
    String? title,
    String? description,
    String? project,
    String? projectId,
    String? sectionId,
    Priority? priority,
    bool clearPriority = false,
    String? time,
    List<TaskLabel>? labels,
    List<Subtask>? subtasks,
    DateTime? dueDate,
    bool? done,
    Recurrence? recurrence,
  }) => Task(
    id: id,
    title: title ?? this.title,
    description: description ?? this.description,
    project: project ?? this.project,
    projectId: projectId ?? this.projectId,
    sectionId: sectionId ?? this.sectionId,
    priority: clearPriority ? null : (priority ?? this.priority),
    time: time ?? this.time,
    labels: labels ?? this.labels,
    subtasks: subtasks ?? this.subtasks,
    dueDate: dueDate ?? this.dueDate,
    done: done ?? this.done,
    recurrence: recurrence ?? this.recurrence,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  factory Task.fromJson(Map<String, dynamic> row) {
    final projectName = (row['projects'] as Map?)?['nome'] as String? ?? 'Sem projeto';
    final projectId   = row['project_id']?.toString();
    final sectionId   = row['section_id']?.toString();

    final subtaskList = ((row['subtasks'] as List?) ?? [])
      ..sort((a, b) => ((a as Map)['ordem'] as int? ?? 0)
          .compareTo((b as Map)['ordem'] as int? ?? 0));

    final labelList = ((row['task_labels'] as List?) ?? [])
        .map((tl) {
          final l = (tl as Map)['labels'] as Map?;
          if (l == null) return null;
          final nome = l['nome'] as String? ?? '';
          if (nome.isEmpty) return null;
          return TaskLabel.fromJson(l as Map<String, dynamic>);
        })
        .whereType<TaskLabel>()
        .toList();

    return Task(
      id: row['id'].toString(),
      title: row['titulo'] as String? ?? '',
      description: row['descricao'] as String?,
      project: projectName,
      projectId: projectId,
      sectionId: sectionId,
      priority: _parsePriority(row['prioridade'] as String?),
      time: row['hora'] as String?,
      done: row['concluida'] as bool? ?? false,
      // BUG-DATE-FROMJSON: DateTime.tryParse falhava silenciosamente
      // quando data_vencimento vinha do Supabase como tipo 'date'
      // (formato '2026-06-23' sem horário) — o cast 'as String' pode
      // falhar se o valor não for exatamente String, e tryParse pode
      // retornar null para formatos inesperados.
      // dueDate: row['data_vencimento'] != null
      //     ? DateTime.tryParse(row['data_vencimento'] as String)
      //     : null,
      dueDate: () {
        final raw = row['data_vencimento'];
        if (raw == null) return null;
        try {
          final str = raw.toString().trim();
          if (str.isEmpty) return null;
          // Tentar parse direto (ISO 8601 completo ou date-only)
          final dt = DateTime.tryParse(str);
          if (dt != null) return dt;
          // Fallback: formato YYYY-MM-DD manual
          final parts = str.split('-');
          if (parts.length >= 3) {
            return DateTime(
              int.parse(parts[0]),
              int.parse(parts[1]),
              int.parse(parts[2].substring(0, 2)),
            );
          }
          return null;
        } catch (_) {
          return null;
        }
      }(),
      recurrence: Recurrence.fromJsonString(row['recorrencia'] as String?),
      labels: labelList,
      subtasks: subtaskList
          .map((s) => Subtask.fromJson(s as Map<String, dynamic>))
          .toList(),
      createdAt: row['created_at'] != null
          ? DateTime.tryParse(row['created_at'] as String)
          : null,
      updatedAt: row['updated_at'] != null
          ? DateTime.tryParse(row['updated_at'] as String)
          : null,
      commentCount: (() {
        final raw = row['task_comments'];
        if (raw == null) return 0;
        if (raw is List && raw.isNotEmpty) {
          final first = raw.first;
          if (first is Map) return (first['count'] as int?) ?? 0;
        }
        return 0;
      })(),
    );
  }

  static Priority? _parsePriority(String? value) => switch (value) {
    'high'   => Priority.high,
    'medium' => Priority.medium,
    'low'    => Priority.low,
    _        => null,
  };
}
