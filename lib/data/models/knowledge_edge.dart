class KnowledgeEdge {
  final String fromId;
  final String toId;
  final String relationType;
  final double weight;

  const KnowledgeEdge({
    required this.fromId, required this.toId,
    this.relationType = 'related', this.weight = 1.0,
  });

  Map<String, dynamic> toDbMap() => {
    'from_id': fromId, 'to_id': toId,
    'relation_type': relationType, 'weight': weight,
  };

  factory KnowledgeEdge.fromDbMap(Map<String, dynamic> map) => KnowledgeEdge(
    fromId: map['from_id'] as String, toId: map['to_id'] as String,
    relationType: map['relation_type'] as String? ?? 'related',
    weight: (map['weight'] as num?)?.toDouble() ?? 1.0,
  );
}
