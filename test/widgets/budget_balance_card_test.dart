import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/budget_balance_calculator.dart';
import 'package:my_web_app/widgets/budget_balance_card.dart';

void main() {
  Future<void> mount(WidgetTester tester,
      {double width = 1000, double scale = 1,}) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: const Scaffold(
              body: SingleChildScrollView(child: BudgetBalanceCard()),),
        ),
      ),
    );
  }

  Future<void> fill(WidgetTester tester) async {
    final values = ['230000', '110000', '120000', '10000', '20000', '50000'];
    for (var i = 0; i < values.length; i++) {
      await tester.enterText(
          find.byKey(ValueKey('balance-${BudgetBalanceField.values[i].name}')),
          values[i],);
    }
  }

  Future<void> calculate(WidgetTester tester) async {
    final button = find.text('配分を確認する');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets(
      'unknown inputs produce field errors, then a valid allocation recovers',
      (tester) async {
    await mount(tester);
    await calculate(tester);
    expect(find.textContaining('未確認です。'), findsNWidgets(6));
    expect(find.textContaining('配分後の残り'), findsNothing);
    await fill(tester);
    await calculate(tester);
    expect(find.text('配分後の残り 30,000円'), findsOneWidget);
    expect(find.text('年間支出の月割り：10,000円'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'editing clears a stale result, shows deficit, then reset clears all fields',
      (tester) async {
    await mount(tester);
    await fill(tester);
    await calculate(tester);
    await tester.enterText(
        find.byKey(const ValueKey('balance-investment')), '150000',);
    await tester.pump();
    expect(find.text('配分後の残り 30,000円'), findsNothing);
    await calculate(tester);
    expect(find.text('毎月 70,000円の不足'), findsOneWidget);
    await tester.ensureVisible(find.text('入力をクリア'));
    await tester.tap(find.text('入力をクリア'));
    await tester.pump();
    expect(find.text('毎月 70,000円の不足'), findsNothing);
    for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(field.controller!.text, '');
    }
  });
  testWidgets(
      '320px width and double text scale keep validation and results scrollable',
      (tester) async {
    await mount(tester, width: 320, scale: 2);
    await fill(tester);
    await calculate(tester);
    await tester.ensureVisible(find.text('配分後の残り 30,000円'));
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byKey(const ValueKey('balance-income')), '-1');
    await calculate(tester);
    expect(find.textContaining('0以上の整数で入力'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
