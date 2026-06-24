import 'dart:convert';

enum RecurrenceType { daily, weekly, monthly, yearly, custom }

class Recurrence {
  final RecurrenceType type;
  // custom: dias da semana
  final List<String>? weekdays; // ["seg","ter","qua","qui","sex","sab","dom"]
  // custom: intervalo numérico
  final int? interval;
  final String? intervalUnit; // "dias" | "semanas" | "meses"

  const Recurrence({
    required this.type,
    this.weekdays,
    this.interval,
    this.intervalUnit,
  });

  // ── Serialization ──────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'tipo': _typeStr};
    if (weekdays != null && weekdays!.isNotEmpty) map['dias'] = weekdays;
    if (interval != null) map['intervalo'] = interval;
    if (intervalUnit != null) map['unidade'] = intervalUnit;
    return map;
  }

  String toJsonString() => jsonEncode(toJson());

  static Recurrence? fromJsonString(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final tipo = map['tipo'] as String?;
      if (tipo == null) return null;
      final type = _parseType(tipo);
      if (type == null) return null;
      return Recurrence(
        type: type,
        weekdays: (map['dias'] as List?)?.cast<String>(),
        interval: map['intervalo'] as int?,
        intervalUnit: map['unidade'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  // ── Display ────────────────────────────────────────────────────────────────

  String get displayLabel => switch (type) {
        RecurrenceType.daily => 'Todo dia',
        RecurrenceType.weekly => 'Toda semana',
        RecurrenceType.monthly => 'Todo mês',
        RecurrenceType.yearly => 'Todo ano',
        RecurrenceType.custom => _customLabel,
      };

  String get _customLabel {
    if (weekdays != null && weekdays!.isNotEmpty) {
      const labels = {
        'seg': 'Seg', 'ter': 'Ter', 'qua': 'Qua',
        'qui': 'Qui', 'sex': 'Sex', 'sab': 'Sáb', 'dom': 'Dom',
      };
      return weekdays!.map((d) => labels[d] ?? d).join(', ');
    }
    if (interval != null && intervalUnit != null) {
      return 'A cada $interval $intervalUnit';
    }
    return 'Personalizado';
  }

  // ── Next date calculation ──────────────────────────────────────────────────

  DateTime? nextDate(DateTime from) {
    switch (type) {
      case RecurrenceType.daily:
        return from.add(const Duration(days: 1));
      case RecurrenceType.weekly:
        return from.add(const Duration(days: 7));
      case RecurrenceType.monthly:
        return DateTime(from.year, from.month + 1, from.day);
      case RecurrenceType.yearly:
        return DateTime(from.year + 1, from.month, from.day);
      case RecurrenceType.custom:
        if (interval != null && intervalUnit != null) {
          return switch (intervalUnit) {
            'dias' => from.add(Duration(days: interval!)),
            'semanas' => from.add(Duration(days: interval! * 7)),
            'meses' => DateTime(from.year, from.month + interval!, from.day),
            _ => null,
          };
        }
        if (weekdays != null && weekdays!.isNotEmpty) {
          const dayMap = {
            'seg': 1, 'ter': 2, 'qua': 3,
            'qui': 4, 'sex': 5, 'sab': 6, 'dom': 7,
          };
          for (int i = 1; i <= 7; i++) {
            final next = from.add(Duration(days: i));
            if (weekdays!.any((d) => dayMap[d] == next.weekday)) return next;
          }
        }
        return null;
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String get _typeStr => switch (type) {
        RecurrenceType.daily => 'diario',
        RecurrenceType.weekly => 'semanal',
        RecurrenceType.monthly => 'mensal',
        RecurrenceType.yearly => 'anual',
        RecurrenceType.custom => 'personalizado',
      };

  static RecurrenceType? _parseType(String tipo) => switch (tipo) {
        'diario' => RecurrenceType.daily,
        'semanal' => RecurrenceType.weekly,
        'mensal' => RecurrenceType.monthly,
        'anual' => RecurrenceType.yearly,
        'personalizado' => RecurrenceType.custom,
        _ => null,
      };
}
