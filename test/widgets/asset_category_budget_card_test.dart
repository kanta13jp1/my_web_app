import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_category_budget_service.dart';
import 'package:my_web_app/widgets/asset_category_budget_card.dart';

Future<void> _pump(
  WidgetTester tester,
  CategoryBudgetReport report, {
  VoidCallback? onEdit,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: AssetCategoryBudgetCard(
            report: report,
            onEditBudgets: onEdit,
            currencyFormatter: (value) => '¥${value.round()}',
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('AssetCategoryBudgetCard', () {
    testWidgets('shows the empty state when no budget is set', (tester) async {
      final report = AssetCategoryBudgetService.build(
        actualByCategory: <String, double>{'食費': 30000},
        budgets: <String, double>{},
      );

      await _pump(tester, report);

      expect(
        find.byKey(const Key('asset_category_budget_card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('asset_category_budget_empty')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('asset_category_budget_total')),
        findsNothing,
      );
    });

    testWidgets('shows totals and an over-budget marker', (tester) async {
      final report = AssetCategoryBudgetService.build(
        actualByCategory: <String, double>{'食費': 60000},
        budgets: <String, double>{'食費': 50000},
      );

      await _pump(tester, report);

      expect(
        find.byKey(const Key('asset_category_budget_total')),
        findsOneWidget,
      );
      expect(find.textContaining('超過'), findsWidgets);
    });

    testWidgets('the edit button fires the callback', (tester) async {
      var tapped = false;
      final report = AssetCategoryBudgetService.build(
        actualByCategory: <String, double>{},
        budgets: <String, double>{'住居': 63000},
      );

      await _pump(tester, report, onEdit: () => tapped = true);

      final button = find.byKey(const Key('asset_category_budget_edit'));
      expect(button, findsOneWidget);

      await tester.tap(button);
      await tester.pump();

      expect(tapped, isTrue);
    });
  });
}
