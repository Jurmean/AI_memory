import 'dart:convert';
import '../../data/models/knowledge_point.dart';
import '../../data/models/knowledge_edge.dart';
import '../llm_client.dart';

class KnowledgeGraphService {
  final LLMClient client;

  const KnowledgeGraphService(this.client);

  Future<List<KnowledgeEdge>> inferRelations(
      List<KnowledgePoint> points) async {
    if (points.length < 2) return [];

    final kpNames = points.map((p) => p.name).join('、');
    final prompt = '''请分析以下知识点之间的关系：$kpNames

对于每对有关系的知识点，输出JSON数组：
```json
[
  {"from": "知识点A", "to": "知识点B", "type": "prerequisite或related", "weight": 0.0-1.0}
]
```
type说明：prerequisite表示A是B的前置知识，related表示相关但无先后。
weight表示关联强度，1.0最强。只输出确实有关系的知识点对。''';

    try {
      final response = await client.chat([
        {'role': 'user', 'content': prompt}
      ]);

      final jsonMatch = RegExp(r'```json\s*([\s\S]*?)```').firstMatch(response);
      if (jsonMatch == null) return [];

      final list =
          (await Future.value(jsonMatch.group(1)!.trim())).isNotEmpty
              ? _tryParseEdges(jsonMatch.group(1)!.trim(), points)
              : <KnowledgeEdge>[];
      return list;
    } catch (_) {
      return [];
    }
  }

  List<KnowledgeEdge> _tryParseEdges(
      String json, List<KnowledgePoint> points) {
    try {
      final nameToId = {for (final p in points) p.name: p.id};
      final list = (jsonDecode(json) as List).cast<Map<String, dynamic>>();
      return list
          .where((e) =>
              nameToId.containsKey(e['from']) &&
              nameToId.containsKey(e['to']))
          .map((e) => KnowledgeEdge(
                fromId: nameToId[e['from']]!,
                toId: nameToId[e['to']]!,
                relationType: e['type'] as String? ?? 'related',
                weight: (e['weight'] as num?)?.toDouble() ?? 0.5,
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
