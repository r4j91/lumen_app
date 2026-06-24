enum SubtaskPriority { high, medium, low }

class Subtask {
  final String? id;
  final String? taskId;
  final String title;
  final String? description;
  final bool done;
  final SubtaskPriority? priority;
  final int order;
  final double? valor;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  // ADICIONADO_ETAPA3A
  final DateTime? dueDate;
  // ADICIONADO_ETAPA3A
  final List<String> labelIds;

  const Subtask({
    this.id,
    this.taskId,
    required this.title,
    this.description,
    this.done = false,
    this.priority,
    this.order = 0,
    this.valor,
    this.createdAt,
    this.updatedAt,
    // ADICIONADO_ETAPA3A
    this.dueDate,
    // ADICIONADO_ETAPA3A
    this.labelIds = const [],
  });

  Subtask copyWith({
    String? id,
    String? taskId,
    String? title,
    String? description,
    bool? done,
    SubtaskPriority? priority,
    int? order,
    double? valor,
    // ADICIONADO_ETAPA3A
    DateTime? dueDate,
    // ADICIONADO_ETAPA3A
    List<String>? labelIds,
  }) => Subtask(
    id: id ?? this.id,
    taskId: taskId ?? this.taskId,
    title: title ?? this.title,
    description: description ?? this.description,
    done: done ?? this.done,
    priority: priority ?? this.priority,
    order: order ?? this.order,
    valor: valor ?? this.valor,
    createdAt: createdAt,
    updatedAt: updatedAt,
    // ADICIONADO_ETAPA3A
    dueDate: dueDate ?? this.dueDate,
    // ADICIONADO_ETAPA3A
    labelIds: labelIds ?? this.labelIds,
  );

  factory Subtask.fromJson(Map<String, dynamic> json) => Subtask(
    id: json['id']?.toString(),
    taskId: json['task_id']?.toString(),
    title: json['titulo'] as String? ?? '',
    description: json['descricao'] as String?,
    done: json['concluida'] as bool? ?? false,
    priority: _parsePriority(json['prioridade'] as String?),
    order: json['ordem'] as int? ?? 0,
    valor: (json['valor'] as num?)?.toDouble(),
    createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'] as String) : null,
    // ADICIONADO_ETAPA3A
    dueDate: json['data_vencimento'] != null ? DateTime.tryParse(json['data_vencimento'] as String) : null,
    // ADICIONADO_ETAPA3A
    labelIds: ((json['label_ids'] as List?) ?? const []).map((e) => e.toString()).toList(),
  );

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    if (taskId != null) 'task_id': taskId,
    'titulo': title,
    if (description != null) 'descricao': description,
    'concluida': done,
    if (priority != null) 'prioridade': priority!.name,
    'ordem': order,
    if (valor != null) 'valor': valor,
    // ADICIONADO_ETAPA3A
    if (dueDate != null) 'data_vencimento': '${dueDate!.year.toString().padLeft(4, '0')}-${dueDate!.month.toString().padLeft(2, '0')}-${dueDate!.day.toString().padLeft(2, '0')}',
    // ADICIONADO_ETAPA3A
    if (labelIds.isNotEmpty) 'label_ids': labelIds,
  };

  static SubtaskPriority? _parsePriority(String? value) => switch (value) {
    'high'   => SubtaskPriority.high,
    'medium' => SubtaskPriority.medium,
    'low'    => SubtaskPriority.low,
    _        => null,
  };
}
