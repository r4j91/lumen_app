import 'package:flutter/material.dart';
import 'supabase_client.dart';
import '../theme/app_colors.dart';

class ProjectData {
  final String id;
  final String name;
  final String? description;
  final Color color;
  final bool favorite;
  final int taskCount;
  final int completedCount;

  const ProjectData({
    required this.id,
    required this.name,
    this.description,
    required this.color,
    this.favorite = false,
    this.taskCount = 0,
    this.completedCount = 0,
  });

  factory ProjectData.fromJson(Map<String, dynamic> json) => ProjectData(
    id: json['id'].toString(),
    name: json['nome'] as String? ?? '',
    description: json['descricao'] as String?,
    color: _parseColor(json['cor'] as String?),
    favorite: json['favorito'] as bool? ?? false,
    taskCount: json['task_count'] as int? ?? 0,
    completedCount: json['completed_count'] as int? ?? 0,
  );

  static Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return AppColors.accent;
    final clean = hex.replaceFirst('#', '');
    try { return Color(int.parse('FF$clean', radix: 16)); } catch (_) {
      return AppColors.accent;
    }
  }
}

class ProjectRepository {
  const ProjectRepository();

  Future<List<ProjectData>> fetchProjects() async {
    final rows = await supabase
        .from('projects')
        .select('id, nome, descricao, cor, favorito')
        .order('nome', ascending: true);
    return (rows as List)
        .map((r) => ProjectData.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<ProjectData?> fetchProjectById(String id) async {
    final rows = await supabase
        .from('projects')
        .select('id, nome, descricao, cor, favorito')
        .eq('id', id)
        .limit(1);
    final list = (rows as List);
    if (list.isEmpty) return null;
    return ProjectData.fromJson(list.first as Map<String, dynamic>);
  }

  Future<void> createProject({
    required String name,
    String? description,
    required String colorHex,
    required String userId,
  }) async {
    await supabase.from('projects').insert({
      'nome': name,
      if (description != null && description.isNotEmpty) 'descricao': description,
      'cor': colorHex,
      'user_id': userId,
    });
  }

  Future<void> updateProject(String id, {String? name, String? colorHex}) async {
    await supabase.from('projects').update({
      if (name != null) 'nome': name,
      if (colorHex != null) 'cor': colorHex,
    }).eq('id', id);
  }

  Future<void> deleteProject(String id) async {
    await supabase.from('projects').delete().eq('id', id);
  }

  Future<void> toggleFavorite(String id, bool favorite) async {
    await supabase.from('projects').update({'favorito': favorite}).eq('id', id);
  }
}
