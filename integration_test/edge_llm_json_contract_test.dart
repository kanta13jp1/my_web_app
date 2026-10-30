import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:my_web_app/pages/edge_llm_playground_page.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Edge LLM画面で入力全文のJSON構文を確認する', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: EdgeLlmPlaygroundPage()));
    final field = find.byKey(const Key('json-contract-input'));
    final button = find.text('JSON構文を確認する');
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.enterText(field, '{"sum":10}');
    await tester.pump();
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    expect(find.text('入力全文はJSONとして読み取れます。'), findsOneWidget);

    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.enterText(field, '```json\n{"sum":10}\n```');
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(field).controller!.text,
      '```json\n{"sum":10}\n```',
    );
    expect(find.text('入力全文はJSONとして読み取れます。'), findsNothing);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    expect(find.textContaining('入力全文はJSONとして読み取れません。'), findsOneWidget);

    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.enterText(field, 'null');
    await tester.pump();
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    expect(find.text('入力全文はJSONとして読み取れます。'), findsOneWidget);
  });
}
