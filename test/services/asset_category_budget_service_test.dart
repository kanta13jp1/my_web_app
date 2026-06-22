import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_category_budget_service.dart';

void main() {
  group('AssetCategoryBudgetService.build', () {
    test('takes the union of budgeted and actual categories', () {
      final report = AssetCategoryBudgetService.build(
        actualByCategory: <String, double>{'食費': 30000, '交通': 5000},
        budgets: <String, double>{'食費': 50000, '住居': 63000},
      );

      expect(report.rows.length, 3);
      expect(report.totalBudget, 50000 + 63000);
      expect(report.totalActual, 30000 + 5000);
      expect(report.totalRemaining, 113000 - 35000);
    });

    test('detects over-budget and sorts it first', () {
      final report = AssetCategoryBudgetService.build(
        actualByCategory: <String, double>{'食費': 60000, '交通': 5000},
        budgets: <String, double>{'食費': 50000, '交通': 20000},
      );

      expect(report.rows.first.category, '食費');
      expect(report.rows.first.isOver, isTrue);
      expect(report.overCount, 1);

      final shoku = report.rows.firstWhere((row) => row.category == '食費');
      expect(shoku.remaining, -10000);
      expect(shoku.ratio, closeTo(1.2, 0.001));
    });

    test('an unbudgeted category has a null ratio and is not over', () {
      final report = AssetCategoryBudgetService.build(
        actualByCategory: <String, double>{'娯楽・浪費': 8000},
        budgets: <String, double>{},
      );

      final row = report.rows.single;
      expect(row.hasBudget, isFalse);
      expect(row.ratio, isNull);
      expect(row.isOver, isFalse);
      expect(report.hasAnyBudget, isFalse);
    });

    test('a budgeted category with no spend keeps the full remaining', () {
      final report = AssetCategoryBudgetService.build(
        actualByCategory: <String, double>{},
        budgets: <String, double>{'住居': 63000},
      );

      final row = report.rows.single;
      expect(row.actual, 0);
      expect(row.remaining, 63000);
      expect(row.isOver, isFalse);
      expect(report.totalRemaining, 63000);
    });

    test('is empty when there are no budgets and no spend', () {
      final report = AssetCategoryBudgetService.build(
        actualByCategory: <String, double>{},
        budgets: <String, double>{},
      );

      expect(report.isEmpty, isTrue);
      expect(report.hasAnyBudget, isFalse);
    });

    test('ignores non-positive amounts as category sources', () {
      final report = AssetCategoryBudgetService.build(
        actualByCategory: <String, double>{'食費': 0, '交通': -100},
        budgets: <String, double>{'住居': 0, '食費': 50000},
      );

      expect(report.rows.length, 1);
      expect(report.rows.single.category, '食費');
      expect(report.rows.single.actual, 0);
    });
  });
}
