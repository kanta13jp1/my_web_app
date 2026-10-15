import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_liability_monthly_state_store.dart';
import 'package:my_web_app/services/asset_salary_spending_entries.dart';

AssetSalarySpendingEntries _entries({
  List<Map<String, dynamic>> flows = const [],
  List<Map<String, dynamic>> payslips = const [],
}) =>
    AssetSalarySpendingEntries.build(
      cardStatementLines: const [],
      recentFlows: flows,
      monthlyIncomePlans: const [],
      payslipSalaryIncomes: const [],
      payslipRows: payslips,
      flowDisplayTitle: (flow) => flow['description']?.toString() ?? '',
    );

void main() {
  test('salary-cycle audit: month boundary keeps the salary-day window', () {
    expect(
      AssetLiabilityMonthlyStateStore.salaryCycleStart(DateTime(2026, 1, 24)),
      DateTime(2025, 12, 25),
    );
    expect(
      AssetLiabilityMonthlyStateStore.salaryCycleEndExclusive(
        DateTime(2026, 1, 24),
      ),
      DateTime(2026, 1, 25),
    );
    expect(
      AssetLiabilityMonthlyStateStore.salaryCycleStart(DateTime(2026, 1, 25)),
      DateTime(2026, 1, 25),
    );
  });

  test('salary-cycle audit: same-day same-amount separate income is retained', () {
    final entries = _entries(
      flows: const [
        {
          'id': 'synthetic-resale',
          'action_type': 'conquer',
          'amount': 1000,
          'occurred_at': '2026-01-25',
          'description': '合成の別件売上',
        },
      ],
      payslips: const [
        {
          'id': 'synthetic-payslip',
          'pay_date': '2026-01-25',
          'net_amount': 1000,
          'company_name': '合成給与',
        },
      ],
    );
    expect(entries.incomes, hasLength(2));
    expect(
      entries.incomes.fold<double>(0, (sum, entry) => sum + entry.amount),
      2000,
    );
  });

  test('salary-cycle audit: ATM principal is excluded and only fee is expense', () {
    final entries = _entries(flows: const [
      {
        'action_type': 'transfer',
        'amount': 1000,
        'occurred_at': '2026-01-25',
        'description': '合成ATM振替',
      },
      {
        'action_type': 'expense',
        'amount': 10,
        'occurred_at': '2026-01-25',
        'description': '合成ATM手数料',
      },
    ]);
    expect(entries.incomes, isEmpty);
    expect(entries.expenses.single.amount, 10);
  });

  test('salary-cycle audit: expense-only records keep income evidence empty', () {
    final entries = _entries(flows: const [
      {
        'action_type': 'expense',
        'amount': 10,
        'occurred_at': '2026-01-25',
        'description': '合成支出',
      },
    ]);
    expect(entries.incomes, isEmpty);
    expect(entries.expenses.single.amount, 10);
  });
}
