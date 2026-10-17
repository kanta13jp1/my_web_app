import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/widgets/recurring_fixed_cost_editor_dialog.dart';

const _cost = AssetRecurringFixedCost(
  id: 'synthetic',
  name: 'Synthetic utility',
  amount: 2000,
  paymentDay: 7,
);

Future<void> _open(
  WidgetTester tester,
  Future<void> Function(AssetRecurringFixedCost) save,
) async {
  await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
    return Scaffold(
        body: TextButton(
            onPressed: () {
              showRecurringFixedCostEditor(context,
                  existing: _cost, onSave: save,);
            },
            child: const Text('open'),),);
  },),),);
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('fixed cost save waits and prevents duplicate submission',
      (tester) async {
    var calls = 0;
    final gate = Completer<void>();
    await _open(tester, (cost) async {
      calls++;
      await gate.future;
    });
    await tester.tap(find.text('保存'));
    await tester.pump();
    expect(calls, 1);
    expect(find.byType(RecurringFixedCostEditorDialog), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,);
    expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'キャンセル'))
            .onPressed,
        isNull,);
    await tester.tap(find.text('保存中…'));
    await tester.pump();
    expect(calls, 1);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(RecurringFixedCostEditorDialog), findsNothing);
  });

  testWidgets('fixed cost save failure retains data and permits retry',
      (tester) async {
    var calls = 0;
    AssetRecurringFixedCost? saved;
    await _open(tester, (cost) async {
      calls++;
      if (calls == 1) throw StateError('synthetic failure');
      saved = cost;
    });
    await tester.enterText(
        find.widgetWithText(TextFormField, '名称'), 'Edited utility',);
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('保存できませんでした。入力を保持しています。'), findsOneWidget);
    expect(find.text('Edited utility'), findsOneWidget);
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(saved?.name, 'Edited utility');
    expect(saved?.id, 'synthetic');
    expect(find.byType(RecurringFixedCostEditorDialog), findsNothing);
  });
}
