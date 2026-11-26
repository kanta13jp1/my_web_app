import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/markdown_preview.dart';

void main() {
  testWidgets(
    'MarkdownPreview renders callout, expandable toggle, and wikilinks',
    (tester) async {
      String? tappedLink;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MarkdownPreview(
                data: '> [!NOTE]\n'
                    '> コールアウト本文\n\n'
                    '<details>\n<summary>クリックで展開</summary>\n\n隠れた詳細テキスト\n</details>\n\n'
                    '関連: [[次のノート]]',
                onWikiLinkTap: (target) => tappedLink = target,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('NOTE'), findsOneWidget);
      expect(find.text('コールアウト本文'), findsOneWidget);
      expect(find.text('クリックで展開'), findsOneWidget);

      await tester.tap(find.text('クリックで展開'));
      await tester.pumpAndSettle();
      expect(find.text('隠れた詳細テキスト'), findsOneWidget);

      await tester.tap(find.text('次のノート'));
      await tester.pumpAndSettle();
      expect(tappedLink, '次のノート');
    },
  );
}
