import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_salary_spending_entries.dart';
import 'package:my_web_app/services/salary_spending_breakdown_service.dart';

void main() {
  test('full unconfirmed memo survives source parsing without repayment', () {
    const memo = '個人宛振込（用途未確認）。銀行出金、明細で確認。'
        '取引後銀行残高は観測値。宛先個人名は保存しない。'
        '返済・贈与・自分口座間振替等の用途は未確認で推定しない。';
    final entries = AssetSalarySpendingEntries.build(
      cardStatementLines: [],
      recentFlows: [
        {
          'action_type': 'expense',
          'occurred_at': '2026-10-23',
          'amount': 100,
          'description': '[三井住友銀行] $memo',
        },
      ],
      monthlyIncomePlans: [],
      payslipSalaryIncomes: [],
      payslipRows: [],
      flowDisplayTitle: (flow) => flow['description'] as String,
    );
    expect(entries.expenses.single.categoryDescription, memo);
    const service = SalarySpendingBreakdownService();
    final result = service.build(
      referenceDate: DateTime(2026, 10, 23),
      expenses: entries.expenses,
    );
    expect(result.sections.single.category, 'その他');
    expect(result.totalExpense, 100);
    expect(result.expenseEntryCount, 1);
    expect(entries.expenses.single.description, '[三井住友銀行] $memo');
  });
  test('unconfirmed purpose candidates are not repayment evidence', () {
    const service = SalarySpendingBreakdownService();
    const caution = '返済・贈与・自分口座間振替等の用途は未確認で推定しない。';
    expect(service.categorize('個人宛振込（用途未確認）。$caution'), 'その他');
    expect(service.categorize('家賃。$caution'), '住居');
    expect(service.categorize('水道料。$caution'), '光熱費');
    expect(service.categorize('水道料 $caution'), '光熱費');
    expect(service.categorize('家賃\n$caution'), '住居');
    expect(service.categorize('ローン返済 $caution'), '借入返済');
    expect(service.categorize('ATM手数料。$caution'), '手数料・税金');
    expect(service.categorize('ローン返済。残高は未確認。'), '借入返済');
  });
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
  test('classification uses caller-cleaned metadata and keeps visible text',
      () {
    final entries = AssetSalarySpendingEntries.build(
      cardStatementLines: [],
      recentFlows: [
        {
          'action_type': 'expense',
          'occurred_at': '2026-10-10',
          'amount': 2000,
          'description': '[三井住友銀行] 水道料 __import_metadata__',
        },
        {
          'action_type': 'expense',
          'occurred_at': '2026-10-10',
          'amount': 500,
          'description': '[三井住友銀行]',
        },
      ],
      monthlyIncomePlans: [],
      payslipSalaryIncomes: [],
      payslipRows: [],
      flowDisplayTitle: (flow) => flow['description'] as String,
      flowCategoryDescription: (flow) =>
          (flow['description'] as String).contains('水道') ? '水道料' : '',
    );
    const service = SalarySpendingBreakdownService();
    final result = service.build(
      referenceDate: DateTime(2026, 10, 12),
      expenses: entries.expenses,
    );
    expect(result.totalExpense, 2500);
    expect(result.sections.any((s) => s.category == '借入返済'), isFalse);
    expect(entries.expenses.first.categoryDescription, '水道料');
    expect(
      entries.expenses.first.description,
      '[三井住友銀行] 水道料 __import_metadata__',
    );
    expect(entries.expenses.last.categoryDescription, isEmpty);
  });
  test('explicit repayments and fees retain their categories', () {
    const service = SalarySpendingBreakdownService();
    expect(service.categorize('ローン返済'), '借入返済');
    expect(service.categorize('PEエスエムビーシーエム'), '借入返済');
    expect(service.categorize('三井住友銀行 ・ ATM手数料'), '手数料・税金');
  });
}
