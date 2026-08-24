import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/competitor_browse_page.dart';

void main() {
  testWidgets('shows a retry state after loading fails and recovers', (
    tester,
  ) async {
    var attempts = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: CompetitorBrowsePage(
          loader: () async {
            attempts += 1;
            if (attempts == 1) {
              throw StateError('temporary failure');
            }
            return <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'notion',
                'display_name': 'Notion',
                'emoji': '📝',
                'pricing_tier': 'freemium',
                'pricing_start_usd': 10,
                'japan_presence_level': 'strong',
                'our_overlap_score': 90,
                'threat_level': 'high',
              },
            ];
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('競合情報を読み込めませんでした'), findsOneWidget);
    expect(find.text('該当する競合がありません'), findsNothing);
    expect(find.byKey(const Key('competitor-browse-retry')), findsOneWidget);

    await tester.tap(find.byKey(const Key('competitor-browse-retry')));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('Notion'), findsOneWidget);
    expect(find.text('1社'), findsOneWidget);
    expect(find.text('競合情報を読み込めませんでした'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
