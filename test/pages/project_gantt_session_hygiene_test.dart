import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/project_gantt_page.dart';

void main() {
  group('SessionHygieneTab', () {
    testWidgets('renders dark cards without TBD leaks', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: const Scaffold(body: SessionHygieneTab()),
        ),
      );

      final cards = tester.widgetList<Card>(find.byType(Card)).toList();
      expect(cards.length, 5);
      for (final card in cards) {
        expect(card.color, const Color(0xFF1E1E1E));
      }

      expect(find.text('TBD'), findsNothing);
      expect(find.textContaining('session_hygiene_log'), findsNothing);
      expect(find.textContaining('ai_hub.session_hygiene_kpi'), findsNothing);
      expect(find.text('計測準備中'), findsNWidgets(4));
      expect(find.text('メモリ使用量の推移'), findsOneWidget);
      expect(find.text('ディスク空き容量の推移'), findsOneWidget);
    });
  });
}
