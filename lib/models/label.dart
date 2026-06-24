import 'package:flutter/material.dart';

class TaskLabel {
  final String id;
  final String name;
  final Color color;

  const TaskLabel({
    required this.id,
    required this.name,
    required this.color,
  });

  factory TaskLabel.fromJson(Map<String, dynamic> json) => TaskLabel(
    id: json['id']?.toString() ?? '',
    name: json['nome'] as String? ?? '',
    color: _parseColor(json['cor'] as String?),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'nome': name,
    'cor': '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
  };

  static Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return const Color(0xFF9296A0);
    final clean = hex.replaceFirst('#', '');
    try {
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFF9296A0);
    }
  }
}
