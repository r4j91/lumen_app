import '../models/task.dart';
import 'supabase_client.dart';
import 'task_sync.dart';

const _kSelect = '''
  id,
  titulo,
  descricao,
  prioridade,
  hora,
  ordem,
  concluida,
  data_vencimento,
  recorrencia,
  project_id,
  section_id,
  projects ( nome ),
  subtasks ( id, titulo, descricao, concluida, ordem, prioridade, valor, data_vencimento, label_ids ),
  task_labels ( labels ( id, nome, cor ) ),
  task_comments ( count )
''';

class TaskRepository {
  const TaskRepository();

  // ── Fetch ──────────────────────────────────────────────────────────────────

  Future<List<Task>> fetchTodayTasks() async {
    final todayStr = _dateStr(DateTime.now());
    final rows = await supabase
        .from('tasks')
        .select(_kSelect)
        .eq('concluida', false)
        .lte('data_vencimento', todayStr)
        .order('data_vencimento', ascending: true)
        .order('ordem', ascending: true)
        // ADICIONADO_ORDEM_ESTAVEL: tiebreaker para 'ordem' duplicado/nulo,
        // evita reordenação não-determinística entre recargas da lista.
        .order('id', ascending: true);
    return _mapList(rows);
  }

  Future<List<Task>> fetchInboxTasks() async {
    final rows = await supabase
        .from('tasks')
        .select(_kSelect)
        .eq('concluida', false)
        .isFilter('data_vencimento', null)
        .isFilter('project_id', null)
        .order('ordem', ascending: true)
        // ADICIONADO_ORDEM_ESTAVEL: tiebreaker para 'ordem' duplicado/nulo,
        // evita reordenação não-determinística entre recargas da lista.
        .order('id', ascending: true);
    return _mapList(rows);
  }

  Future<List<Task>> fetchCompletedInboxTasks() async {
    final rows = await supabase
        .from('tasks')
        .select(_kSelect)
        .eq('concluida', true)
        .isFilter('data_vencimento', null)
        .isFilter('project_id', null)
        .order('ordem', ascending: true)
        // ADICIONADO_ORDEM_ESTAVEL: tiebreaker para 'ordem' duplicado/nulo,
        // evita reordenação não-determinística entre recargas da lista.
        .order('id', ascending: true);
    return _mapList(rows);
  }

  Future<List<Task>> fetchCompletedTodayTasks() async {
    final todayStr = _dateStr(DateTime.now());
    final rows = await supabase
        .from('tasks')
        .select(_kSelect)
        .eq('concluida', true)
        .or('data_vencimento.is.null,data_vencimento.eq.$todayStr')
        .order('ordem', ascending: true)
        // ADICIONADO_ORDEM_ESTAVEL: tiebreaker para 'ordem' duplicado/nulo,
        // evita reordenação não-determinística entre recargas da lista.
        .order('id', ascending: true);
    return _mapList(rows);
  }

  Future<List<Task>> fetchUpcomingTasks() async {
    final todayStr = _dateStr(DateTime.now());
    final rows = await supabase
        .from('tasks')
        .select(_kSelect)
        .eq('concluida', false)
        .gt('data_vencimento', todayStr)
        .order('data_vencimento', ascending: true)
        .order('ordem', ascending: true)
        // ADICIONADO_ORDEM_ESTAVEL: tiebreaker para 'ordem' duplicado/nulo,
        // evita reordenação não-determinística entre recargas da lista.
        .order('id', ascending: true);
    return _mapList(rows);
  }

  Future<List<Task>> fetchTasksByProject(String projectId) async {
    final rows = await supabase
        .from('tasks')
        .select(_kSelect)
        .eq('project_id', projectId)
        .eq('concluida', false)
        .order('ordem', ascending: true)
        // ADICIONADO_ORDEM_ESTAVEL: tiebreaker para 'ordem' duplicado/nulo,
        // evita reordenação não-determinística entre recargas da lista.
        .order('id', ascending: true);
    return _mapList(rows);
  }

  Future<List<Task>> fetchCompletedTasksByProject(String projectId) async {
    final rows = await supabase
        .from('tasks')
        .select(_kSelect)
        .eq('project_id', projectId)
        .eq('concluida', true)
        .order('ordem', ascending: true)
        // ADICIONADO_ORDEM_ESTAVEL: tiebreaker para 'ordem' duplicado/nulo,
        // evita reordenação não-determinística entre recargas da lista.
        .order('id', ascending: true);
    return _mapList(rows);
  }

  Future<Task?> fetchTaskById(String id) async {
    final rows = await supabase
        .from('tasks')
        .select(_kSelect)
        .eq('id', id)
        .limit(1);
    final list = _mapList(rows);
    return list.isEmpty ? null : list.first;
  }

  // ── Mutations ──────────────────────────────────────────────────────────────

  Future<void> toggleTaskDone(String id, bool done) async {
    await supabase.from('tasks').update({'concluida': done}).eq('id', id);
  }

  Future<void> updateTaskPriority(String id, Priority priority) async {
    await supabase
        .from('tasks')
        .update({'prioridade': priority.name})
        .eq('id', id);
  }

  Future<void> updateTaskProject(String id, String? projectId) async {
    await supabase
        .from('tasks')
        .update({'project_id': projectId})
        .eq('id', id);
  }

  Future<void> updateTaskDate(String id, String? isoDate) async {
    await supabase
        .from('tasks')
        .update({'data_vencimento': isoDate})
        .eq('id', id);
  }

  Future<void> deleteTask(String id) async {
    await supabase.from('tasks').delete().eq('id', id);
    TaskSync.instance.notifyChanged();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static List<Task> _mapList(dynamic rows) =>
      (rows as List).map((r) => Task.fromJson(r as Map<String, dynamic>)).toList();

  static String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // Keep static for backward compat with existing callers
  static Task mapRow(Map<String, dynamic> row) => Task.fromJson(row);
}
