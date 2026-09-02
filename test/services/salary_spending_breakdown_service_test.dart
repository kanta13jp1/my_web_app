import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/salary_spending_breakdown_service.dart';

void main() {
  group('SalarySpendingBreakdownService', () {
    test(
        'Issue #5194: correctly categorizes bank transfer and debt keywords into 借入返済, 住居, and 通信',
        () {
      const service = SalarySpendingBreakdownService();
      expect(service.categorize('PEエスエムビーシーエム'), '借入返済');
      expect(service.categorize('モビット口振'), '借入返済');
      expect(service.categorize('CL口座振込'), '借入返済');
      expect(service.categorize('ペイペイカード'), '借入返済');
      expect(service.categorize('PayPayカード利用代金'), '借入返済');
      expect(service.categorize('大東建託家賃'), '住居');
      expect(service.categorize('ahamo月額料'), '通信');
    });

    const service = SalarySpendingBreakdownService();

    test('uses the 25th as the salary-cycle boundary before payday', () {
      final breakdown = service.build(
        referenceDate: DateTime(2026, 5, 23),
        expenses: <SalarySpendingEntry>[
          SalarySpendingEntry(
            date: DateTime(2026, 4, 24),
            amount: 9999,
            description: 'outside previous cycle',
            sourceLabel: 'flow',
          ),
          SalarySpendingEntry(
            date: DateTime(2026, 4, 25),
            amount: 120000,
            description: '家賃',
            sourceLabel: 'flow',
          ),
          SalarySpendingEntry(
            date: DateTime(2026, 5, 24),
            amount: 5000,
            description: 'スーパー',
            sourceLabel: 'flow',
          ),
          SalarySpendingEntry(
            date: DateTime(2026, 5, 25),
            amount: 3000,
            description: 'next salary cycle',
            sourceLabel: 'flow',
          ),
        ],
        incomes: <SalaryIncomeEntry>[
          SalaryIncomeEntry(
            date: DateTime(2026, 4, 25),
            amount: 245000,
            description: '給与',
          ),
        ],
      );

      expect(breakdown.periodStart, DateTime(2026, 4, 25));
      expect(breakdown.periodEndExclusive, DateTime(2026, 5, 25));
      expect(breakdown.totalExpense, 125000);
      expect(breakdown.salaryIncomeTotal, 245000);
      expect(breakdown.remainingAfterExpense, 120000);
    });

    test('groups expenses by category and sorts by amount', () {
      final breakdown = service.build(
        referenceDate: DateTime(2026, 5, 26),
        expenses: <SalarySpendingEntry>[
          SalarySpendingEntry(
            date: DateTime(2026, 5, 25),
            amount: 10000,
            description: 'Netflix subscription',
            sourceLabel: 'card',
          ),
          SalarySpendingEntry(
            date: DateTime(2026, 5, 26),
            amount: 30000,
            description: 'カードローン返済',
            sourceLabel: 'flow',
          ),
          SalarySpendingEntry(
            date: DateTime(2026, 5, 26),
            amount: 2000,
            description: '用途未分類',
            sourceLabel: 'flow',
          ),
        ],
      );

      expect(breakdown.sections.map((section) => section.category), <String>[
        '借入返済',
        'サブスク',
        'その他',
      ]);
      expect(breakdown.sections.first.amount, 30000);
      expect(breakdown.sections.first.ratio, closeTo(30000 / 42000, 0.0001));
      expect(breakdown.expenseEntryCount, 3);
    });

    test('falls back to single income entry even without salary keywords', () {
      final breakdown = service.build(
        referenceDate: DateTime(2026, 5, 23),
        incomes: <SalaryIncomeEntry>[
          SalaryIncomeEntry(
            date: DateTime(2026, 4, 25),
            amount: 180000,
            description: 'main income',
          ),
        ],
      );

      expect(breakdown.salaryIncomeTotal, 180000);
    });

    test('groups auto balance drops as unknown spending', () {
      final breakdown = service.build(
        referenceDate: DateTime(2026, 5, 26),
        expenses: <SalarySpendingEntry>[
          SalarySpendingEntry(
            date: DateTime(2026, 5, 26),
            amount: 18000,
            description: '使途不明金（残高差分から自動記録）',
            sourceLabel: '三井住友銀行',
          ),
        ],
      );

      expect(breakdown.sections.single.category, '使途不明金');
      expect(breakdown.sections.single.amount, 18000);
      expect(breakdown.expenseEntryCount, 1);
    });

    test('counts payslip income even when other income entries exist', () {
      final breakdown = service.build(
        referenceDate: DateTime(2026, 5, 26),
        incomes: <SalaryIncomeEntry>[
          SalaryIncomeEntry(
            date: DateTime(2026, 5, 25),
            amount: 452815,
            description: 'Payslip: 自分株式会社',
          ),
          SalaryIncomeEntry(
            date: DateTime(2026, 5, 25),
            amount: 12000,
            description: '副業売上',
          ),
        ],
      );

      expect(breakdown.salaryIncomeTotal, 452815);
    });
  });
}
