import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/widgets/recurring_fixed_cost_editor_dialog.dart';

void main() {
  const prefill = AssetRecurringFixedCost(
    id: 'fc_suggestion',
    name: '電気代',
    amount: 8050,
    paymentDay: 15,
  );

  testWidgets('prefill initializes the add form in add mode', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: RecurringFixedCostEditorDialog(prefill: prefill)),
      ),
    );

    expect(find.text('定期固定費を追加'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '電気代'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '8050'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '15'), findsOneWidget);
  });

  testWidgets('saving a prefilled form returns a cost with a fresh id', (
    tester,
  ) async {
    AssetRecurringFixedCost? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                saved = await showRecurringFixedCostEditor(
                  context,
                  prefill: prefill,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.name, '電気代');
    expect(saved!.amount, 8050);
    expect(saved!.paymentDay, 15);
    expect(saved!.id, isNot('fc_suggestion')); // 新規 id を採番
  });
}
