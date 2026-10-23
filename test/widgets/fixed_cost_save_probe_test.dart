import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/widgets/recurring_fixed_cost_editor_dialog.dart';

void main() {
  for (final fails in [false, true]) {
    testWidgets('fixed cost pending and completion fails=$fails', (tester) async {
      var calls = 0;
      var closed = false;
      final gate = Completer<void>();
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(
        builder: (context) => ElevatedButton(onPressed: () async {
          await showRecurringFixedCostEditor(context,
            sourceAccounts: const [],
            prefill: const AssetRecurringFixedCost(id: 'synthetic', name: '合成固定費', amount: 1234, paymentDay: 15),
            onSave: (cost) async {
              calls++;
              expect(cost.name, '合成固定費');
              expect(cost.amount, 1234);
              if (calls == 1) await gate.future;
              if (fails && calls == 1) throw StateError('synthetic failure');
            });
          closed = true;
        }, child: const Text('open')),
      ))));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
      await tester.pump();
      expect(calls, 1);
      expect(closed, false);
      expect(find.text('保存中…'), findsOneWidget);
      expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'キャンセル')).onPressed, isNull);
      expect(find.widgetWithText(TextFormField, '合成固定費'), findsOneWidget);
      gate.complete();
      await tester.pumpAndSettle();
      if (fails) {
        expect(closed, false);
        expect(find.text('保存できませんでした。入力を保持しています。'), findsOneWidget);
        expect(find.widgetWithText(TextFormField, '合成固定費'), findsOneWidget);
        expect(find.widgetWithText(TextFormField, '1234'), findsOneWidget);
        await tester.tap(find.text('保存'));
        await tester.pumpAndSettle();
        expect(calls, 2);
      }
      expect(closed, true);
      expect(find.text('定期固定費を追加'), findsNothing);
    });
  }
}
