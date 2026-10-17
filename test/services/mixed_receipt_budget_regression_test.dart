import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/salary_spending_breakdown_service.dart';

void main() {
  test('reconciled mixed receipt preserves total and splits category amounts', () {
    const service = SalarySpendingBreakdownService();
    final result = service.build(
      referenceDate: DateTime(2026, 10, 17),
      expenses: <SalarySpendingEntry>[
        SalarySpendingEntry(
          date: DateTime(2026, 10, 9),
          amount: 736,
          description: 'セブン 食品116円、たばこ620円',
          sourceLabel: 'cash',
        ),
      ],
    );
    expect(result.totalExpense, 736);
    expect(result.expenseEntryCount, 1);
    final amounts = <String, double>{
      for (final section in result.sections) section.category: section.amount,
    };
    expect(amounts['食費'], 116);
    expect(amounts['娯楽・浪費'], 620);
    expect(amounts.values.fold<double>(0, (sum, value) => sum + value), 736);
  });
}
