import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/gemini_university_v2_page.dart';

void main() {
  testWidgets(
    'loading AppBar and genre shelf keep dark surfaces in light mode',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var collapsed = false;
      var toggleCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                appBar: AiUniversityPage.buildLoadingAppBar(),
                body: SizedBox(
                  width: 390,
                  child: AiUniversityGenreShelf(
                    genresCount: 4,
                    collapsed: collapsed,
                    onToggle: () {
                      toggleCount++;
                      setState(() => collapsed = !collapsed);
                    },
                    child: const Text('ジャンルカード'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      expect(tester.takeException(), isNull);

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, const Color(0xFF1A1A1A));
      expect(appBar.foregroundColor, const Color(0xFFE5E7EB));

      final titleText = tester.widget<Text>(find.text('AI 大学'));
      expect(titleText.style?.color, const Color(0xFFE5E7EB));

      final shelf = tester.widget<Container>(
        find.byKey(const Key('ai_university_genre_shelf')),
      );
      final decoration = shelf.decoration as BoxDecoration;
      expect(decoration.color, const Color(0xFF161A24));

      final shelfTitle = tester.widget<Text>(find.text('新ジャンル'));
      expect(shelfTitle.style?.color, Colors.white);

      for (final label in ['新ジャンル', '4', '隠す']) {
        expect(find.text(label), findsOneWidget);
        final rect = tester.getRect(find.text(label));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(390));
      }
      expect(find.byIcon(Icons.expand_less), findsOneWidget);
      expect(find.text('ジャンルカード'), findsOneWidget);

      await tester.tap(find.text('新ジャンル'));
      await tester.pump();

      expect(toggleCount, 1);
      expect(find.text('開く'), findsOneWidget);
      expect(find.text('隠す'), findsNothing);
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
      expect(find.text('ジャンルカード'), findsNothing);

      final openRect = tester.getRect(find.text('開く'));
      expect(openRect.left, greaterThanOrEqualTo(0));
      expect(openRect.right, lessThanOrEqualTo(390));
      expect(tester.takeException(), isNull);
    },
  );
}
