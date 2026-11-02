import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/git_ignore_examples_card.dart';

void main() {
  testWidgets('fixed examples change explanation without accepting user data', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: GitIgnoreExamplesCard()),
        ),
      ),
    );
    expect(find.textContaining('未登録の .env は通常の変更一覧に表示されません'), findsOneWidget);
    await tester.tap(find.text('未登録 .env.example'));
    await tester.pump();
    expect(find.textContaining('未登録ファイルとして表示されます'), findsOneWidget);
    await tester.tap(find.text('登録後に変更'));
    await tester.pump();
    expect(find.textContaining('無視規則があっても変更一覧に表示されます'), findsOneWidget);
    await tester.tap(find.text('一致の調べ方'));
    await tester.pump();
    expect(find.textContaining('--no-index'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.textContaining('手元のファイルを調べたり秘密情報を検出したりしません'), findsOneWidget);
  });
}
