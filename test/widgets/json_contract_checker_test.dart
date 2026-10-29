import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/json_contract_checker.dart';

void main() {
  testWidgets('全文を端末内で検査し、入力変更で結果を消す', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: JsonContractChecker())),
    );
    final field = find.byKey(const Key('json-contract-input'));
    final button = find.text('JSON構文を確認する');
    final checkButton = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(checkButton.onPressed, isNull);

    for (final value in ['{"sum":10}', '[1,2]', 'null', 'true', '42', '"x"']) {
      await tester.enterText(field, value);
      await tester.pump();
      await tester.tap(button);
      await tester.pump();
      expect(find.text('入力全文はJSONとして読み取れます。'), findsOneWidget);
    }

    for (final value in ['```json\n{"sum":10}\n```', '{"sum":}']) {
      await tester.enterText(field, value);
      await tester.pump();
      expect(find.text('入力全文はJSONとして読み取れます。'), findsNothing);
      await tester.tap(button);
      await tester.pump();
      expect(
        find.text('入力全文はJSONとして読み取れません。Markdownの囲みもJSONには含められません。'),
        findsOneWidget,
      );
    }
    await tester.enterText(field, '{}');
    await tester.pump();
    expect(find.textContaining('入力全文はJSONとして'), findsNothing);
  });
}
