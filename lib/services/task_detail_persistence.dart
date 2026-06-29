import 'package:flutter/material.dart';
import '../models/subtask.dart';
import '../models/task.dart';
import '../services/notification_service.dart';
import '../services/supabase_client.dart';
import '../widgets/task_detail/subtask_item.dart';

/// Persistência de tarefa extraída de [TaskDetailSheet] — autosave parcial e save completo.
class TaskDetailPersistence {
  TaskDetailPersistence._();

  static String? _priorityString(Priority? priority) => switch (priority) {
        Priority.high => 'high',
        Priority.medium => 'medium',
        Priority.low => 'low',
        null => null,
      };

  static String? _dueDateString(DateTime? dueDate, TimeOfDay? dueTime) {
    if (dueDate == null) return null;
    if (dueTime != null) {
      return DateTime(
        dueDate.year,
        dueDate.month,
        dueDate.day,
        dueTime.hour,
        dueTime.minute,
      ).toIso8601String();
    }
    return '${dueDate.year}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}';
  }

  static String? _horaString(TimeOfDay? dueTime) {
    if (dueTime == null) return null;
    return '${dueTime.hour.toString().padLeft(2, '0')}:${dueTime.minute.toString().padLeft(2, '0')}';
  }

  static Future<void> autosavePriority({
    required String taskId,
    Priority? priority,
  }) async {
    try {
      await supabase
          .from('tasks')
          .update({'prioridade': _priorityString(priority)})
          .eq('id', taskId);
    } catch (e) {
      // ignore: avoid_print
      print('[TaskDetail] autosave prioridade falhou: $e');
    }
  }

  static Future<void> autosaveDueDate({
    required String taskId,
    DateTime? dueDate,
    TimeOfDay? dueTime,
  }) async {
    String? dueDateStr;
    String? horaStr;

    if (dueDate != null) {
      dueDateStr = _dueDateString(dueDate, dueTime);
      horaStr = dueTime != null ? _horaString(dueTime) : null;
    }

    try {
      await supabase.from('tasks').update({
        'data_vencimento': dueDateStr,
        'hora': horaStr,
      }).eq('id', taskId);
    } catch (e) {
      // ignore: avoid_print
      print('[TaskDetail] autosave falhou: $e');
    }
  }

  static Future<void> autosaveLabels({
    required String taskId,
    required Set<String> labelIds,
  }) async {
    try {
      await supabase.from('task_labels').delete().eq('task_id', taskId);
      if (labelIds.isNotEmpty) {
        await supabase.from('task_labels').insert(
          labelIds.map((lid) => {'task_id': taskId, 'label_id': lid}).toList(),
        );
      }
    } catch (e) {
      // ignore: avoid_print
      print('[TaskDetail] autosave etiquetas falhou: $e');
    }
  }

  /// Salva tarefa nova ou existente; retorna o id persistido.
  static Future<String> saveTask({
    required bool isNew,
    String? existingTaskId,
    required String title,
    required String description,
    Priority? priority,
    String? projectId,
    String? sectionId,
    DateTime? dueDate,
    TimeOfDay? dueTime,
    Recurrence? recurrence,
    required Set<String> labelIds,
    required List<SubtaskItem> subtasks,
  }) async {
    final payload = {
      'titulo': title.trim(),
      'descricao': description.trim().isEmpty ? null : description.trim(),
      'prioridade': _priorityString(priority),
      'project_id': projectId,
      'section_id': sectionId,
      'data_vencimento': _dueDateString(dueDate, dueTime),
      'hora': dueTime != null ? _horaString(dueTime) : null,
      'recorrencia': recurrence?.toJsonString(),
    };

    late final String taskId;

    if (isNew) {
      final userId = supabase.auth.currentUser?.id;
      // ignore: avoid_print
      print('[TaskDetail] inserting new task — user=$userId');
      final inserted = await supabase
          .from('tasks')
          .insert({...payload, if (userId != null) 'user_id': userId})
          .select('id')
          .single();
      taskId = inserted['id'].toString();
    } else {
      taskId = existingTaskId!;
      // ignore: avoid_print
      print('[TaskDetail] updating task $taskId');
      await supabase.from('tasks').update(payload).eq('id', taskId);
    }

    await supabase.from('task_labels').delete().eq('task_id', taskId);
    if (labelIds.isNotEmpty) {
      await supabase.from('task_labels').insert(
        labelIds.map((lid) => {'task_id': taskId, 'label_id': lid}).toList(),
      );
    }

    await supabase.from('subtasks').delete().eq('task_id', taskId);
    final subtaskRows = <Map<String, dynamic>>[];
    for (int i = 0; i < subtasks.length; i++) {
      final st = subtasks[i];
      final stTitle = st.ctrl.text.trim();
      if (stTitle.isEmpty) continue;
      final desc = st.descCtrl.text.trim();
      subtaskRows.add({
        'task_id': taskId,
        'titulo': stTitle,
        'descricao': desc.isEmpty ? null : desc,
        'concluida': st.done,
        'ordem': i,
        'prioridade': switch (st.priority) {
          SubtaskPriority.high => 'high',
          SubtaskPriority.medium => 'medium',
          SubtaskPriority.low => 'low',
          null => null,
        },
        'data_vencimento': _dueDateString(st.dueDate, st.dueTime),
        'label_ids': st.labelIds.isEmpty ? null : st.labelIds.toList(),
      });
    }
    if (subtaskRows.isNotEmpty) {
      try {
        await supabase.from('subtasks').insert(subtaskRows);
      } catch (_) {
        final baseRows = subtaskRows.map((r) {
          final m = Map<String, dynamic>.from(r);
          m.remove('data_vencimento');
          m.remove('label_ids');
          return m;
        }).toList();
        await supabase.from('subtasks').insert(baseRows);
      }
    }

    if (dueDate != null) {
      NotificationService().cancelTaskNotification(taskId);
      NotificationService().scheduleTaskNotification(taskId, title.trim(), dueDate);
    } else {
      NotificationService().cancelTaskNotification(taskId);
    }

    return taskId;
  }
}
