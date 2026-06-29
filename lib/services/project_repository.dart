import 'package:flutter/material.dart';
import 'task_sync.dart';
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
    try {
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return AppColors.accent;
    }
  }
}

/// Detalhes editáveis de um projeto (options sheet).
class ProjectDetails {
  final String name;
  final String? colorHex;
  final String? iconName;

  const ProjectDetails({
    required this.name,
    this.colorHex,
    this.iconName,
  });
}

/// Contagem de tarefas por projeto (dashboard de filtros).
class ProjectTaskStats {
  final String id;
  final String name;
  final String? colorHex;
  final String? iconName;
  final int pending;
  final int total;

  const ProjectTaskStats({
    required this.id,
    required this.name,
    this.colorHex,
    this.iconName,
    required this.pending,
    required this.total,
  });
}

class ProjectRepository {
  const ProjectRepository();

  Future<List<ProjectData>> fetchProjectsForUser(String userId) async {
    final rows = await supabase
        .from('projects')
        .select('id, nome, descricao, cor, favorito')
        .eq('user_id', userId)
        .order('nome', ascending: true);
    return (rows as List)
        .map((r) => ProjectData.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Linhas brutas com coluna `icone` quando existir no banco; fallback sem ela.
  Future<List<Map<String, dynamic>>> fetchProjectRowsForUser(String userId) async {
    try {
      final rows = await supabase
          .from('projects')
          .select('id, nome, cor, favorito, icone')
          .eq('user_id', userId)
          .order('nome');
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      if (!e.toString().contains('icone')) rethrow;
      final rows = await supabase
          .from('projects')
          .select('id, nome, cor, favorito')
          .eq('user_id', userId)
          .order('nome');
      return List<Map<String, dynamic>>.from(rows);
    }
  }

  Future<ProjectData?> fetchProjectById(String id) async {
    final rows = await supabase
        .from('projects')
        .select('id, nome, descricao, cor, favorito')
        .eq('id', id)
        .limit(1);
    final list = rows as List;
    if (list.isEmpty) return null;
    return ProjectData.fromJson(list.first as Map<String, dynamic>);
  }

  Future<ProjectDetails?> fetchProjectDetails(String id) async {
    try {
      final row = await supabase
          .from('projects')
          .select('nome, cor, icone')
          .eq('id', id)
          .maybeSingle();
      if (row == null) return null;
      return ProjectDetails(
        name: row['nome'] as String? ?? '',
        colorHex: row['cor'] as String?,
        iconName: row['icone'] as String?,
      );
    } catch (e) {
      if (!e.toString().contains('icone')) rethrow;
      final row = await supabase
          .from('projects')
          .select('nome, cor')
          .eq('id', id)
          .maybeSingle();
      if (row == null) return null;
      return ProjectDetails(
        name: row['nome'] as String? ?? '',
        colorHex: row['cor'] as String?,
      );
    }
  }

  Future<List<ProjectTaskStats>> fetchProjectsWithTaskStats() async {
    List rows;
    try {
      rows = await supabase
          .from('projects')
          .select('id, nome, cor, icone, tasks(concluida)')
          .order('nome');
    } catch (e) {
      if (!e.toString().contains('icone')) rethrow;
      rows = await supabase
          .from('projects')
          .select('id, nome, cor, tasks(concluida)')
          .order('nome');
    }

    return rows.map((r) {
      final map = r as Map<String, dynamic>;
      final tasks = (map['tasks'] as List?) ?? [];
      return ProjectTaskStats(
        id: map['id'].toString(),
        name: map['nome'] as String? ?? '',
        colorHex: map['cor'] as String?,
        iconName: map['icone'] as String?,
        pending: tasks.where((t) => t['concluida'] == false).length,
        total: tasks.length,
      );
    }).toList();
  }

  Future<void> createProject({
    required String name,
    String? description,
    required String colorHex,
    required String userId,
    bool favorite = false,
  }) async {
    await supabase.from('projects').insert({
      'nome': name,
      if (description != null && description.isNotEmpty) 'descricao': description,
      'cor': colorHex,
      'user_id': userId,
      'favorito': favorite,
    });
  }

  Future<void> updateProject(String id, {String? name, String? colorHex}) async {
    await supabase.from('projects').update({
      if (name != null) 'nome': name,
      if (colorHex != null) 'cor': colorHex,
    }).eq('id', id);
  }

  /// Atualiza nome/cor/ícone; omite `icone` se a coluna não existir no banco.
  Future<void> updateProjectDetails({
    required String id,
    required String name,
    required String colorHex,
    String? iconName,
  }) async {
    try {
      await supabase.from('projects').update({
        'nome': name,
        'cor': colorHex,
        if (iconName != null) 'icone': iconName,
      }).eq('id', id);
    } catch (e) {
      if (!e.toString().contains('icone')) rethrow;
      await supabase.from('projects').update({
        'nome': name,
        'cor': colorHex,
      }).eq('id', id);
    }
  }

  Future<void> deleteProject(String id) async {
    await supabase.from('projects').delete().eq('id', id);
    TaskSync.instance.notifyChanged();
  }

  Future<void> toggleFavorite(String id, bool favorite) async {
    await supabase.from('projects').update({'favorito': favorite}).eq('id', id);
  }
}
