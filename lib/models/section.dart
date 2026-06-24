class Section {
  final String id;
  final String projectId;
  final String name;
  final int order;
  final DateTime createdAt;

  const Section({
    required this.id,
    required this.projectId,
    required this.name,
    required this.order,
    required this.createdAt,
  });

  factory Section.fromJson(Map<String, dynamic> json) => Section(
    id: json['id'] as String,
    projectId: json['project_id'] as String,
    name: json['name'] as String,
    order: json['order'] as int? ?? 0,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'project_id': projectId,
    'name': name,
    'order': order,
  };

  Section copyWith({String? name, int? order}) => Section(
    id: id,
    projectId: projectId,
    name: name ?? this.name,
    order: order ?? this.order,
    createdAt: createdAt,
  );
}
