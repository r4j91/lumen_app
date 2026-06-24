import '../models/section.dart';
import 'supabase_client.dart';

class SectionRepository {
  const SectionRepository();

  Future<List<Section>> getSectionsForProject(String projectId) async {
    final rows = await supabase
        .from('sections')
        .select('id, project_id, name, order, created_at')
        .eq('project_id', projectId)
        .order('order', ascending: true);
    return (rows as List)
        .map((r) => Section.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<Section> createSection(String projectId, String name) async {
    final row = await supabase
        .from('sections')
        .insert({'project_id': projectId, 'name': name})
        .select('id, project_id, name, order, created_at')
        .single();
    return Section.fromJson(row);
  }

  Future<void> updateSection(String sectionId, {String? name, int? order}) async {
    await supabase.from('sections').update({
      if (name != null) 'name': name,
      if (order != null) 'order': order,
    }).eq('id', sectionId);
  }

  Future<void> deleteSection(String sectionId) async {
    await supabase.from('sections').delete().eq('id', sectionId);
  }
}
