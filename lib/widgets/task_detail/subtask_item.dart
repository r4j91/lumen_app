import 'package:flutter/material.dart';
import '../../models/subtask.dart';

/// Mutable view-model for a subtask being edited inside TaskDetailSheet.
class SubtaskItem {
  static int _counter = 0;

  final int uid;
  /// Real Supabase row id. Null until the parent task is saved for the
  /// first time and this subtask gets persisted. Used to decide whether a
  /// field edit can be written straight to the DB or must stay in-memory.
  String? id;
  /// Parent task id — used to persist metadata before/without a row id.
  String? taskId;
  /// Position within the parent task — pairs with [taskId] for fallback updates.
  int order;
  bool done;
  SubtaskPriority? priority;
  Set<String> labelIds;
  DateTime? dueDate;
  TimeOfDay? dueTime;
  double? valor;
  final TextEditingController ctrl;
  final FocusNode focus;
  final TextEditingController descCtrl;
  final FocusNode descFocus;

  SubtaskItem({
    this.id,
    this.taskId,
    this.order = 0,
    required String title,
    String? description,
    this.done = false,
    this.priority,
    Set<String>? labelIds,
    this.dueDate,
    this.dueTime,
    this.valor,
  })  : uid = _counter++,
        labelIds = labelIds ?? {},
        ctrl = TextEditingController(text: title),
        focus = FocusNode(),
        descCtrl = TextEditingController(text: description ?? ''),
        descFocus = FocusNode();

  void dispose() {
    ctrl.dispose();
    focus.dispose();
    descCtrl.dispose();
    descFocus.dispose();
  }
}
