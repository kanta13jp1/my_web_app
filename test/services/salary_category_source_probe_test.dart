import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_salary_spending_entries.dart';
import 'package:my_web_app/services/salary_spending_breakdown_service.dart';

void main() {
  test('plain bank source does not prove an unconfirmed repayment', () {
    const memo = '三井住友銀行サンプル支店 個人宛振込（用途未確認）。'
        '返済・贈与・自分口座間振替等の用途は未確認で推定しない。';
    final entries = AssetSalarySpendingEntries.build(
      cardStatementLines: [],
      recentFlows: [
        {
          'action_type': 'expense',
          'occurred_at': '2026-10-23',
          'amount': 100,
          'description': memo,
        },
      ],
      monthlyIncomePlans: [],
      payslipSalaryIncomes: [],
      payslipRows: [],
      flowDisplayTitle: (flow) => flow['description'] as String,
    );
    const service = SalarySpendingBreakdownService();
    final result = service.build(
      referenceDate: DateTime(2026, 10, 23),
      expenses: entries.expenses,
    );
    expect(result.sections.single.category, 'その他');
    expect(result.totalExpense, 100);
    expect(result.expenseEntryCount, 1);
    expect(entries.expenses.single.description, memo);
  });
}
