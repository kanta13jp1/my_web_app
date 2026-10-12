import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/jev_input_cost_card.dart';

void main() {
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: JevInputCostCard()),
        ),
      ),
    );
  }

  testWidgets('normal comparison shows both USD estimates', (tester) async {
    await open(tester);
    await tester.tap(find.text('概算費用を比較'));
    await tester.pump();
    expect(find.textContaining('変更前 USD 0.016254'), findsOneWidget);
    expect(find.textContaining('変更後 USD 0.242004'), findsOneWidget);
  });
  testWidgets('zero requests show an error instead of a quote', (tester) async {
    await open(tester);
    await tester.enterText(find.widgetWithText(TextField, '判断回数'), '0');
    await tester.tap(find.text('概算費用を比較'));
    await tester.pump();
    expect(find.textContaining('回数は1以上の整数'), findsOneWidget);
    expect(find.textContaining('変更前 USD'), findsNothing);
  });
  testWidgets('editing clears the old quote and correction recovers',
      (tester) async {
    await open(tester);
    await tester.tap(find.text('概算費用を比較'));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, '判断回数'), '0');
    await tester.pump();
    expect(find.textContaining('変更前 USD'), findsNothing);
    await tester.tap(find.text('概算費用を比較'));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, '判断回数'), '1000');
    await tester.tap(find.text('概算費用を比較'));
    await tester.pump();
    expect(find.textContaining('変更前 USD 0.016254'), findsOneWidget);
  });
}
