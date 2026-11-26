import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/markdown_preview.dart';

void main() {
  testWidgets(
    'MarkdownPreview renders callout, expandable toggle, and selectable wikilinks',
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

      final selectableFinder = find.byWidgetPredicate(
        (widget) =>
            widget is SelectableText &&
            (widget.textSpan?.toPlainText().contains('次のノート') ?? false),
      );
      expect(selectableFinder, findsOneWidget);

      final SelectableText selectable = tester.widget<SelectableText>(
        selectableFinder,
      );
      GestureRecognizer? linkRecognizer;
      selectable.textSpan?.visitChildren((span) {
        if (span is TextSpan && span.text == '次のノート') {
          linkRecognizer = span.recognizer;
          return false;
        }
        return true;
      });
      expect(linkRecognizer, isA<TapGestureRecognizer>());
      (linkRecognizer! as TapGestureRecognizer).onTap?.call();
      await tester.pumpAndSettle();
      expect(tappedLink, '次のノート');
    },
  );

  testWidgets(
    'MarkdownPreview triggers onWikiLinkTap on tap when selectable is false',
    (tester) async {
      String? tappedLink;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MarkdownPreview(
                selectable: false,
                data: '[[次のノート]]',
                onWikiLinkTap: (target) => tappedLink = target,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final richTextFinder = find.textContaining('次のノート', findRichText: true);
      expect(richTextFinder, findsOneWidget);

      await tester.tapAt(tester.getTopLeft(richTextFinder) + const Offset(12, 8));
      await tester.pumpAndSettle();
      expect(tappedLink, '次のノート');
    },
  );
}
