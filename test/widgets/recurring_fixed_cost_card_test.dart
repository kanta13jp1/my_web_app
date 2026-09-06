import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/widgets/recurring_fixed_cost_card.dart';
import 'package:my_web_app/widgets/recurring_fixed_cost_editor_dialog.dart';

void main() {
  group('RecurringFixedCostCard', () {
    testWidgets('renders entries and fires add/edit/delete callbacks',
        (tester) async {
      AssetRecurringFixedCost? edited;
      AssetRecurringFixedCost? deleted;
      var addPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecurringFixedCostCard(
              costs: const <AssetRecurringFixedCost>[
                AssetRecurringFixedCost(
                  id: 'fc_denki',
                  name: '電気代',
                  amount: 8000,
                  paymentDay: 27,
                  sourceAccountId: 'smbc',
                ),
              ],
              sourceAccountNames: const <String, String>{
                'smbc': '三井住友銀行大塚支店',
              },
              onAdd: () => addPressed = true,
              onEdit: (cost) => edited = cost,
              onDelete: (cost) => deleted = cost,
            ),
          ),
        ),
      );

      expect(find.text('電気代'), findsOneWidget);
      expect(find.textContaining('毎月27日'), findsOneWidget);
      expect(find.textContaining('¥8,000'), findsOneWidget);
      expect(find.textContaining('振替元: 三井住友銀行大塚支店'), findsOneWidget);

      // 各行は名称 + 内訳を 1 つの semantics ラベルへまとめて読み上げる。
      final rowSemantics = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            (widget.properties.label?.contains('電気代') ?? false) &&
            (widget.properties.label?.contains('¥8,000') ?? false),
      );
      expect(rowSemantics, findsOneWidget);

      await tester.tap(find.text('追加'));
      expect(addPressed, isTrue);
      await tester.tap(find.byTooltip('電気代 を編集'));
      expect(edited?.id, 'fc_denki');
      await tester.tap(find.byTooltip('電気代 を削除'));
      expect(deleted?.id, 'fc_denki');
    });

    testWidgets('shows an empty hint when there are no costs', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecurringFixedCostCard(
              costs: const <AssetRecurringFixedCost>[],
              sourceAccountNames: const <String, String>{},
              onAdd: () {},
              onEdit: (_) {},
              onDelete: (_) {},
            ),
          ),
        ),
      );

      expect(find.textContaining('通常の固定費（家賃・光熱費など）は未登録'), findsOneWidget);
      expect(find.textContaining('同じ請求を両方へ登録しない'), findsOneWidget);
    });
  });

  group('RecurringFixedCostEditorDialog', () {
    testWidgets('returns a cost built from the entered values', (tester) async {
      AssetRecurringFixedCost? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await showRecurringFixedCostEditor(context);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), '電気代');
      await tester.enterText(find.byType(TextFormField).at(1), '8000');
      await tester.enterText(find.byType(TextFormField).at(2), '27');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.name, '電気代');
      expect(result!.amount, 8000);
      expect(result!.paymentDay, 27);
      expect(result!.cadence, AssetRecurringFixedCostCadence.monthly);
      expect(result!.sourceAccountId, isNull);
    });

    testWidgets('stays open and shows errors on invalid input', (tester) async {
      var returned = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await showRecurringFixedCostEditor(context);
                  returned = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      // 何も入力せず保存 → バリデーションエラーで閉じない。
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(find.text('名称を入力してください'), findsOneWidget);
      expect(returned, isFalse);
    });
  });
}
