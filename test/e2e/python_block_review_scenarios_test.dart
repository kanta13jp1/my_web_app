import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/python_block_review_card.dart';

void main() {
  const usage =
      '```python\ndef parse_duration(s):\n    return 1\n```\n```python\nprint(parse_duration("1s"))\n```';
  Widget host() => const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: PythonBlockReviewCard()),
        ),
      );
  testWidgets('usage after implementation warns about the last block',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.enterText(find.byType(TextField).last, usage);
    await tester.tap(find.text('コードの候補を確認する'));
    await tester.pump();
    expect(find.textContaining('末尾ブロックと関数を含む候補が異なります'), findsOneWidget);
    expect(find.text('候補 1'), findsOneWidget);
  });
  testWidgets('multiple candidates stay ambiguous', (tester) async {
    await tester.pumpWidget(host());
    await tester.enterText(
      find.byType(TextField).last,
      '$usage\n```python\ndef parse_duration(s):\n    return 2\n```',
    );
    await tester.tap(find.text('コードの候補を確認する'));
    await tester.pump();
    expect(find.textContaining('候補を一意に選べません'), findsOneWidget);
  });
  testWidgets('editing clears a previous result at narrow width',
      (tester) async {
    tester.view.physicalSize = const Size(320, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(host());
    await tester.enterText(find.byType(TextField).last, usage);
    await tester.tap(find.text('コードの候補を確認する'));
    await tester.pump();
    expect(find.text('候補 1'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '回答を書き直しました');
    await tester.pump();
    expect(find.text('候補 1'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('examples replace input and clear previous result',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('使用例が末尾にある例'));
    await tester.pump();
    await tester.tap(find.text('コードの候補を確認する'));
    await tester.pump();
    expect(find.textContaining('末尾ブロックと関数を含む候補が異なります'), findsOneWidget);
    await tester.tap(find.text('実装が2つある例'));
    await tester.pump();
    expect(find.text('候補 1'), findsNothing);
    await tester.tap(find.text('コードの候補を確認する'));
    await tester.pump();
    expect(find.textContaining('候補を一意に選べません'), findsOneWidget);
    expect(find.text('候補 2'), findsOneWidget);
  });
}
