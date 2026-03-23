import 'package:graphview/GraphView.dart';

class MindMapGraphBuildResult {
  final Graph graph;
  final Map<String, String> nodeLabels;

  const MindMapGraphBuildResult({
    required this.graph,
    required this.nodeLabels,
  });
}

class MindMapGraphBuilderService {
  MindMapGraphBuildResult build(Map<String, dynamic> json) {
    final graph = Graph();
    final nodeLabels = <String, String>{};
    var nextNodeIndex = 0;

    void walk(Map<String, dynamic> branch, Node? parent) {
      for (final entry in branch.entries) {
        final label = entry.key.trim().isEmpty ? '(empty)' : entry.key.trim();
        final nodeId = 'mind_map_node_${nextNodeIndex++}';
        final node = Node.Id(nodeId);
        nodeLabels[nodeId] = label;
        graph.addNode(node);

        if (parent != null) {
          graph.addEdge(parent, node);
        }

        final rawChildren = entry.value;
        final children = rawChildren is Map<String, dynamic>
            ? rawChildren
            : (rawChildren is Map
                ? Map<String, dynamic>.from(rawChildren)
                : null);
        if (children != null && children.isNotEmpty) {
          walk(children, node);
        }
      }
    }

    walk(json, null);

    return MindMapGraphBuildResult(
      graph: graph,
      nodeLabels: nodeLabels,
    );
  }
}
