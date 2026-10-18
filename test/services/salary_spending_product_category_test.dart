import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_category_budget_service.dart';
import 'package:my_web_app/services/salary_spending_breakdown_service.dart';

void main() {
  const service = SalarySpendingBreakdownService();

  test('food descriptions include the full convenience store name', () {
    expect(service.categorize('ファミリーマート バニラとミルクティー'), '食費');
    expect(service.categorize('食品 バニラとミルクティー'), '食費');
    expect(service.categorize('ファミマ おにぎり'), '食費');
  });

  test('book evidence precedes general marketplace fallback', () {
    expect(service.categorize('Amazon 文庫の注文'), '書籍');
    expect(service.categorize('Amazon 書籍購入'), '書籍');
    expect(service.categorize('紀伊國屋書店'), '書籍');
    expect(service.categorize('Amazon 洗剤'), '日用品');
    expect(service.categorize('Amazon Prime subscription'), 'サブスク');
    expect(service.categorize('用途未分類'), 'その他');
    expect(SalarySpendingBreakdownService.categoryLabels, contains('書籍'));
  });

  test('corrected categories preserve expense totals and budget actuals', () {
    final breakdown = service.build(
      referenceDate: DateTime(2026, 10, 18),
      expenses: <SalarySpendingEntry>[
        SalarySpendingEntry(
          date: DateTime(2026, 10, 11),
          amount: 538,
          description: 'ファミリーマート 食品',
          sourceLabel: 'synthetic',
        ),
        SalarySpendingEntry(
          date: DateTime(2026, 10, 18),
          amount: 935,
          description: 'Amazon 文庫',
          sourceLabel: 'synthetic',
        ),
      ],
    );
    final actuals = <String, double>{
      for (final section in breakdown.sections)
        section.category: section.amount,
    };
    expect(breakdown.totalExpense, 1473);
    expect(breakdown.expenseEntryCount, 2);
    expect(actuals, <String, double>{'食費': 538, '書籍': 935});
    final budget = AssetCategoryBudgetService.build(
      actualByCategory: actuals,
      budgets: const <String, double>{'食費': 1000, '書籍': 1000},
    );
    expect(budget.totalActual, 1473);
    expect(budget.totalBudget, 2000);
    expect(budget.rows.singleWhere((row) => row.category == '書籍').actual, 935);
  });
}
