import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/ui/features/comparison/widgets/comparison_related_comparisons_section.dart';

void main() {
  testWidgets(
    'ComparisonRelatedComparisonsSection renders items and handles taps at 360x800 @ 2.0x',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      String? selectedKey;
      var landscapeOpened = false;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: Scaffold(
              backgroundColor: const Color(0xFF0B1120),
              body: SingleChildScrollView(
                child: ComparisonRelatedComparisonsSection(
                  items: const [
                    RelatedComparisonItem(
                      competitorKey: 'notion',
                      emoji: '📝',
                      name: 'Notion',
                      searchKeyword: 'Notion代替 ワークスペース比較',
                    ),
                    RelatedComparisonItem(
                      competitorKey: 'evernote',
                      emoji: '🐘',
                      name: 'Evernote',
                      searchKeyword: 'Evernote代替 ノート移行',
                    ),
                  ],
                  onSelectCompetitor: (key) => selectedKey = key,
                  onOpenLandscape: () => landscapeOpened = true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(ComparisonRelatedComparisonsSection.sectionKey),
        findsOneWidget,
      );
      expect(find.text('📝 Notion'), findsOneWidget);
      expect(find.text('🐘 Evernote'), findsOneWidget);

      final notionFinder = find.byKey(const Key('related-comparison-notion'));
      await tester.ensureVisible(notionFinder);
      await tester.tap(notionFinder);
      await tester.pumpAndSettle();
      expect(selectedKey, 'notion');

      final landscapeFinder = find.byKey(
        ComparisonRelatedComparisonsSection.landscapeButtonKey,
      );
      await tester.ensureVisible(landscapeFinder);
      await tester.tap(landscapeFinder);
      await tester.pumpAndSettle();
      expect(landscapeOpened, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
