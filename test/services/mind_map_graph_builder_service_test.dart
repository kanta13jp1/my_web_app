import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/mind_map_graph_builder_service.dart';

void main() {
  group('MindMapGraphBuilderService', () {
    test('build creates unique node ids even when labels repeat', () {
      final service = MindMapGraphBuilderService();

      final result = service.build(<String, dynamic>{
        'Product Strategy': <String, dynamic>{
          'Research': <String, dynamic>{
            'Next Step': <String, dynamic>{},
          },
          'Execution': <String, dynamic>{
            'Next Step': <String, dynamic>{},
          },
        },
      });

      expect(result.graph.nodes, hasLength(5));
      expect(result.nodeLabels, hasLength(5));
      expect(
        result.nodeLabels.values.where((label) => label == 'Next Step').length,
        2,
      );
      expect(result.nodeLabels.keys.toSet(), hasLength(5));
    });

    test('build normalizes blank labels to placeholder text', () {
      final service = MindMapGraphBuilderService();

      final result = service.build(<String, dynamic>{
        '': <String, dynamic>{},
      });

      expect(result.graph.nodes, hasLength(1));
      expect(result.nodeLabels.values.single, '(empty)');
    });
  });
}
