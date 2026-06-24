import '../models/label.dart';
import 'supabase_client.dart';

class LabelRepository {
  const LabelRepository();

  Future<List<TaskLabel>> fetchLabels() async {
    final rows = await supabase
        .from('labels')
        .select('id, nome, cor')
        .order('nome', ascending: true);
    return (rows as List)
        .map((r) => TaskLabel.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<List<TaskLabel>> fetchLabelsForTask(String taskId) async {
    final rows = await supabase
        .from('task_labels')
        .select('labels ( id, nome, cor )')
        .eq('task_id', taskId);
    return (rows as List)
        .map((r) {
          final l = (r as Map)['labels'] as Map?;
          if (l == null) return null;
          return TaskLabel.fromJson(l as Map<String, dynamic>);
        })
        .whereType<TaskLabel>()
        .toList();
  }

  Future<void> createLabel({required String name, required String colorHex}) async {
    await supabase.from('labels').insert({'nome': name, 'cor': colorHex});
  }

  Future<void> updateLabel(String id, {String? name, String? colorHex}) async {
    await supabase.from('labels').update({
      if (name != null) 'nome': name,
      if (colorHex != null) 'cor': colorHex,
    }).eq('id', id);
  }

  Future<void> deleteLabel(String id) async {
    await supabase.from('labels').delete().eq('id', id);
  }

  Future<void> setTaskLabels(String taskId, List<String> labelIds) async {
    await supabase.from('task_labels').delete().eq('task_id', taskId);
    if (labelIds.isEmpty) return;
    await supabase.from('task_labels').insert(
      labelIds.map((lid) => {'task_id': taskId, 'label_id': lid}).toList(),
    );
  }
}
