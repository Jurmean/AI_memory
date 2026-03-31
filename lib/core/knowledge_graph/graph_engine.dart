import 'dart:collection';
import '../../data/models/knowledge_edge.dart';
import '../../shared/constants.dart';

class KnowledgeGraphEngine {
  final Map<String, List<KnowledgeEdge>> _adjacency = {};

  void loadEdges(List<KnowledgeEdge> edges) {
    _adjacency.clear();
    for (final edge in edges) {
      _adjacency.putIfAbsent(edge.fromId, () => []).add(edge);
      _adjacency.putIfAbsent(edge.toId, () => []).add(
        KnowledgeEdge(
          fromId: edge.toId,
          toId: edge.fromId,
          relationType: edge.relationType,
          weight: edge.weight,
        ),
      );
    }
  }

  void addEdge(KnowledgeEdge edge) {
    _adjacency.putIfAbsent(edge.fromId, () => []).add(edge);
    _adjacency.putIfAbsent(edge.toId, () => []).add(
      KnowledgeEdge(
        fromId: edge.toId,
        toId: edge.fromId,
        relationType: edge.relationType,
        weight: edge.weight,
      ),
    );
  }

  List<String> getNeighbors(String kpId, {int depth = AppConstants.kgMaxBfsDepth}) {
    final visited = <String>{};
    final result = <String>[];
    _bfs(kpId, depth, visited, result);
    return result;
  }

  void _bfs(String start, int maxDepth, Set<String> visited, List<String> result) {
    final queue = Queue<_BfsEntry>();
    queue.add(_BfsEntry(start, 0));
    visited.add(start);

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      if (current.depth > 0) result.add(current.id);
      if (current.depth >= maxDepth) continue;

      for (final edge in _adjacency[current.id] ?? []) {
        if (!visited.contains(edge.toId)) {
          visited.add(edge.toId);
          queue.add(_BfsEntry(edge.toId, current.depth + 1));
        }
      }
    }
  }

  double calculateSynergy(
      String kpId, Map<String, double> forgettingMap) {
    var synergy = 0.0;
    for (final edge in _adjacency[kpId] ?? []) {
      final forgetting = forgettingMap[edge.toId] ?? 0.0;
      synergy += forgetting * edge.weight;
    }
    return synergy * AppConstants.kgAlpha;
  }
}

class _BfsEntry {
  final String id;
  final int depth;
  const _BfsEntry(this.id, this.depth);
}
