import '../models/subtask.dart';
import 'supabase_client.dart';
import 'task_sync.dart';

class SubtaskRepository {
  const SubtaskRepository();

  Future<List<Subtask>> fetchByTaskId(String taskId) async {
    final rows = await supabase
        .from('subtasks')
        .select('id, task_id, titulo, descricao, concluida, ordem, prioridade')
        .eq('task_id', taskId)
        .order('ordem', ascending: true);
    return (rows as List)
        .map((r) => Subtask.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> createSubtask(Subtask subtask) async {
    final payload = subtask.toJson();
    try {
      await supabase.from('subtasks').insert(payload);
    } catch (_) {
      // Fallback: insert without optional columns in case migration not run yet
      final base = Map<String, dynamic>.from(payload)
        ..remove('data_vencimento')
        ..remove('label_ids');
      await supabase.from('subtasks').insert(base);
    }
  }

  Future<void> createSubtasks(List<Subtask> subtasks) async {
    if (subtasks.isEmpty) return;
    final payload = subtasks.map((s) => s.toJson()).toList();
    try {
      await supabase.from('subtasks').insert(payload);
    } catch (_) {
      final base = payload.map((p) {
        final m = Map<String, dynamic>.from(p)
          ..remove('data_vencimento')
          ..remove('label_ids');
        return m;
      }).toList();
      await supabase.from('subtasks').insert(base);
    }
  }

  /// Insere várias subtarefas de uma vez a partir de Maps já no formato
  /// de colunas do Supabase (usado pelo gerador de parcelas — cada Map já
  /// vem com 'task_id', 'titulo', 'data_vencimento', 'valor', 'concluida',
  /// 'ordem'). Não passa por Subtask.toJson() pois os Maps já são raw.
  Future<void> createSubtasksBatch(List<Map<String, dynamic>> subtasks) async {
    if (subtasks.isEmpty) return;
    await supabase.from('subtasks').insert(subtasks);
  }

  Future<void> updateSubtask(String id, Map<String, dynamic> fields) async {
    await supabase.from('subtasks').update(fields).eq('id', id);
  }

  /// Direct, immediate partial update for a single subtask field group
  /// (title/description/priority/due date/labels), used by the inline
  /// subtask editor so edits to an already-persisted subtask don't depend
  /// on the parent task's full Save action anymore.
  ///
  /// Retries without `data_vencimento`/`label_ids` only if those specific
  /// columns are missing (undeployed migration) — any other error is
  /// rethrown so the caller can surface it instead of losing data silently.
  /// Persists partial field updates. Uses row [id] when available; otherwise
  /// falls back to task_id + ordem and writes the resolved id back via
  /// [onIdResolved].
  Future<void> persistSubtask({
    String? id,
    String? taskId,
    int? order,
    required Map<String, dynamic> fields,
    void Function(String resolvedId)? onIdResolved,
  }) async {
    if (fields.isEmpty) return;

    if (id != null) {
      await updateSubtaskFields(id, fields);
      return;
    }

    if (taskId == null || order == null) return;

    try {
      await supabase
          .from('subtasks')
          .update(fields)
          .eq('task_id', taskId)
          .eq('ordem', order);
      TaskSync.instance.notifyChanged();
      final row = await supabase
          .from('subtasks')
          .select('id')
          .eq('task_id', taskId)
          .eq('ordem', order)
          .maybeSingle();
      final resolved = row?['id']?.toString();
      if (resolved != null) onIdResolved?.call(resolved);
    } catch (e) {
      // ignore: avoid_print
      print('[SubtaskRepository] persistSubtask($taskId/$order) falhou: $e');
      final msg = e.toString();
      final isMissingColumn =
          msg.contains('data_vencimento') || msg.contains('label_ids');
      if (!isMissingColumn) rethrow;
      final base = Map<String, dynamic>.from(fields)
        ..remove('data_vencimento')
        ..remove('label_ids');
      if (base.isEmpty) rethrow;
      await supabase
          .from('subtasks')
          .update(base)
          .eq('task_id', taskId)
          .eq('ordem', order);
      TaskSync.instance.notifyChanged();
      rethrow;
    }
  }

  Future<void> updateSubtaskFields(String id, Map<String, dynamic> fields) async {
    try {
      await supabase.from('subtasks').update(fields).eq('id', id);
      TaskSync.instance.notifyChanged();
    } catch (e) {
      // CORRIGIDO_AUTOSAVE_DATA: o erro original era engolido silenciosamente
      // antes de decidir o fallback, mascarando a causa real (ex: coluna
      // ausente) sem nunca chegar ao _showSaveError() do chamador. Logar
      // sempre, antes de qualquer decisão.
      // ignore: avoid_print
      print('[SubtaskRepository] updateSubtaskFields($id) falhou: $e');
      final msg = e.toString();
      final isMissingColumn = msg.contains('data_vencimento') || msg.contains('label_ids');
      if (!isMissingColumn) rethrow;
      final base = Map<String, dynamic>.from(fields)
        ..remove('data_vencimento')
        ..remove('label_ids');
      if (base.isEmpty) rethrow;
      await supabase.from('subtasks').update(base).eq('id', id);
      // CORRIGIDO_AUTOSAVE_DATA: o fallback removeu campos pedidos pelo
      // chamador (perda de dados silenciosa — ex: data_vencimento nunca
      // persiste). Propagar o erro original mesmo após o fallback ter
      // sucesso parcial, para que _persistMeta() acione o SnackBar de erro
      // em vez de aparentar sucesso total.
      rethrow;
    }
  }

  Future<void> toggleSubtaskDone(String id, bool done) async {
    await supabase.from('subtasks').update({'concluida': done}).eq('id', id);
    TaskSync.instance.notifyChanged();
  }

  Future<void> deleteSubtask(String id) async {
    await supabase.from('subtasks').delete().eq('id', id);
  }

  Future<void> deleteSubtasksByTaskId(String taskId) async {
    await supabase.from('subtasks').delete().eq('task_id', taskId);
  }

  Future<void> reorderSubtasks(List<({String id, int order})> items) async {
    for (final item in items) {
      await supabase
          .from('subtasks')
          .update({'ordem': item.order})
          .eq('id', item.id);
    }
  }
}
