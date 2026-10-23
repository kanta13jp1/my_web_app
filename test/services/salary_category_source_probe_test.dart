import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_salary_spending_entries.dart';
import 'package:my_web_app/services/salary_spending_breakdown_service.dart';

void main() {
  test('source metadata does not change utilities, totals, or visible text',
      () {
    final entries = AssetSalarySpendingEntries.build(
      cardStatementLines: [],
      recentFlows: [
        {
          'action_type': 'expense',
          'occurred_at': '2026-10-10',
          'amount': 2000,
          'description': '[三井住友銀行] 水道料',
        },
        {
          'action_type': 'expense',
          'occurred_at': '2026-10-10',
          'amount': 1000,
          'description': '[別銀行] 水道料',
        },
        {
          'action_type': 'transfer',
          'occurred_at': '2026-10-10',
          'amount': 9000,
          'description': '[三井住友銀行] -> [現金] ATM',
        },
      ],
      monthlyIncomePlans: [],
      payslipSalaryIncomes: [],
      payslipRows: [],
      flowDisplayTitle: (flow) => flow['description'] as String,
    );
    const service = SalarySpendingBreakdownService();
    final result = service.build(
        referenceDate: DateTime(2026, 10, 12),
        expenses: entries.expenses,
    );
    expect(result.totalExpense, 3000);
    expect(result.expenseEntryCount, 2);
    expect(result.sections.single.category, '光熱費');
    expect(entries.expenses.first.description, '[三井住友銀行] 水道料');
    expect(entries.expenses.first.categoryDescription, '水道料');
  });
  test('explicit repayments and fees retain their categories', () {
    const service = SalarySpendingBreakdownService();
    expect(service.categorize('ローン返済'), '借入返済');
    expect(service.categorize('PEエスエムビーシーエム'), '借入返済');
    expect(service.categorize('三井住友銀行 ・ ATM手数料'), '手数料・税金');
  });
}
