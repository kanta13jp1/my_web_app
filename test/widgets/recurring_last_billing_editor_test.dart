import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/widgets/recurring_fixed_cost_editor_dialog.dart';

void main() {
  testWidgets(
      'editor validates, saves, restores and explicitly clears last billing',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var cost = const AssetRecurringFixedCost(
      id: 'synthetic',
      name: 'Synthetic contract',
      amount: 1000,
      paymentDay: 5,
    );
    var saves = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                final result =
                    await showRecurringFixedCostEditor(context, existing: cost);
                if (result != null) {
                  cost = result;
                  saves++;
                }
              },
              child: const Text('Edit synthetic contract'),
            ),
          ),
        ),
      ),
    );
    Future<void> open() async {
      await tester.tap(find.text('Edit synthetic contract'));
      await tester.pumpAndSettle();
    }

    final field = find.byKey(const Key('recurring_last_billing_date'));
    await open();
    await tester.enterText(field, '2026-02-30');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(saves, 0);
    expect(find.text('実在する日付をYYYY-MM-DD形式で入力してください'), findsOneWidget);
    await tester.enterText(field, '2026-12-05');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(saves, 1);
    expect(cost.lastBillingDate, DateTime(2026, 12, 5));
    await open();
    expect(tester.widget<TextFormField>(field).controller!.text, '2026-12-05');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(cost.lastBillingDate, DateTime(2026, 12, 5));
    await open();
    await tester.enterText(field, '');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(cost.lastBillingDate, isNull);
    expect(saves, 3);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
