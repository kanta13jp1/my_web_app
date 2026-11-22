import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/project_gantt_page.dart';

void main() {
  group('resolveWbsCategoryIconData', () {
    test('maps known Material icon names to IconData', () {
      expect(resolveWbsCategoryIconData('movie'), Icons.movie_outlined);
      expect(
        resolveWbsCategoryIconData('person_add'),
        Icons.person_add_outlined,
      );
      expect(resolveWbsCategoryIconData('query_stats'), Icons.query_stats);
      expect(resolveWbsCategoryIconData('trending_up'), Icons.trending_up);
    });

    test('falls back to label_outline for unknown snake_case icon names', () {
      expect(
        resolveWbsCategoryIconData('custom_metric_badge'),
        Icons.label_outline,
      );
    });

    test('returns null for emojis and short symbols', () {
      expect(resolveWbsCategoryIconData('📋'), isNull);
      expect(resolveWbsCategoryIconData('X'), isNull);
      expect(resolveWbsCategoryIconData('\$'), isNull);
    });
  });

  group('WbsCategoryIconBadge', () {
    testWidgets('renders Icon widget instead of raw icon name text', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                WbsCategoryIconBadge(iconValue: 'movie'),
                WbsCategoryIconBadge(iconValue: 'person_add'),
                WbsCategoryIconBadge(iconValue: 'X'),
              ],
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.movie_outlined), findsOneWidget);
      expect(find.byIcon(Icons.person_add_outlined), findsOneWidget);
      expect(find.text('movie'), findsNothing);
      expect(find.text('person_add'), findsNothing);
      expect(find.text('X'), findsOneWidget);
    });
  });
}
