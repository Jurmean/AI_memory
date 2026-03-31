class KnowledgePoint {
  final String id;
  final String name;
  final String? description;
  final int level;
  final String? subjectId;

  const KnowledgePoint({
    required this.id, required this.name, this.description,
    this.level = 0, this.subjectId,
  });

  Map<String, dynamic> toDbMap() => {
    'id': id, 'name': name, 'description': description,
    'level': level, 'subject_id': subjectId,
  };

  factory KnowledgePoint.fromDbMap(Map<String, dynamic> map) => KnowledgePoint(
    id: map['id'] as String, name: map['name'] as String,
    description: map['description'] as String?,
    level: map['level'] as int? ?? 0,
    subjectId: map['subject_id'] as String?,
  );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'description': description, 'level': level, 'subjectId': subjectId};
  factory KnowledgePoint.fromJson(Map<String, dynamic> json) => KnowledgePoint(
    id: json['id'] as String, name: json['name'] as String,
    description: json['description'] as String?, level: json['level'] as int? ?? 0,
    subjectId: json['subjectId'] as String?,
  );
}
