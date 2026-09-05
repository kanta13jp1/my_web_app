import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_salary_spending_entries.dart';

String _title(Map<String, dynamic> flow) =>
    flow['description']?.toString() ?? '';

AssetLiabilityIncomePlan _plan(String name, DateTime date, double amount,
    {bool received = true}) {
  return AssetLiabilityIncomePlan(
    id: name,
    date: date,
    name: name,
    amount: amount,
    destinationAccountId: null,
    destinationAccountName: null,
    received: received,
  );
}

void main() {
  group('AssetSalarySpendingEntries.build', () {
    test('splits recent flows into expense/income and drops transfers', () {
      final result = AssetSalarySpendingEntries.build(
        cardStatementLines: const [],
        recentFlows: [
          <String, dynamic>{
            'action_type': 'expense',
            'amount': 3000,
            'occurred_at': '2026-06-10',
            'description': 'ランチ',
          },
          <String, dynamic>{
            'action_type': 'conquer',
            'amount': 5000,
            'occurred_at': '2026-06-11',
            'description': 'メルカリ売上',
          },
          <String, dynamic>{
            'action_type': 'transfer',
            'amount': 10000,
            'occurred_at': '2026-06-12',
            'description': '口座移動',
          },
        ],
        monthlyIncomePlans: const [],
        payslipSalaryIncomes: const [],
        payslipRows: const [],
        flowDisplayTitle: _title,
      );

      expect(result.expenses, hasLength(1));
      expect(result.expenses.single.description, 'ランチ');
      expect(result.expenses.single.sourceLabel, '支出');
      expect(result.incomes, hasLength(1));
      expect(result.incomes.single.description, 'メルカリ売上');
    });

    test('card lines are expenses and dedupe flows that match the marker', () {
      final result = AssetSalarySpendingEntries.build(
        cardStatementLines: [
          AssetLiabilityCardStatementLine(
            id: 'c1',
            billingAccountId: 'rakuten',
            billingAccountName: '楽天カード',
            postedAt: DateTime(2026, 6, 5),
            description: 'Amazon',
            amount: 2000,
          ),
        ],
        recentFlows: [
          <String, dynamic>{
            'action_type': 'expense',
            'amount': 2000,
            'occurred_at': '2026-06-05',
            'description': '楽天カード引き落とし',
          },
          <String, dynamic>{
            'action_type': 'expense',
            'amount': 500,
            'occurred_at': '2026-06-06',
            'description': 'コンビニ',
          },
        ],
        monthlyIncomePlans: const [],
        payslipSalaryIncomes: const [],
        payslipRows: const [],
        flowDisplayTitle: _title,
      );

      expect(result.expenses, hasLength(2));
      expect(
        result.expenses.map((e) => e.description),
        containsAll(<String>['Amazon', 'コンビニ']),
      );
      expect(
        result.expenses.where((e) => e.description.contains('楽天カード')),
        isEmpty,
      );
    });

    test('unreceived salary plan does not inflate payslip income', () {
      final result = AssetSalarySpendingEntries.build(
        cardStatementLines: const [],
        recentFlows: const [],
        monthlyIncomePlans: [
          _plan('給料予定', DateTime(2026, 8, 25), 450000, received: false),
        ],
        payslipSalaryIncomes: const [
          {'pay_date': '2026-08-25', 'amount': 421277},
        ],
        payslipRows: const [
          {'pay_date': '2026-08-25', 'net_amount': 421277},
        ],
        flowDisplayTitle: _title,
      );

      expect(result.incomes, hasLength(1));
      expect(result.incomes.single.amount, 421277);
    });

    test('received plan mirrored in flows and payslips is counted once', () {
      final result = AssetSalarySpendingEntries.build(
        cardStatementLines: const [],
        recentFlows: const [
          {
            'action_type': 'conquer',
            'amount': 421277,
            'occurred_at': '2026-08-25',
            'description': '給料',
          },
        ],
        monthlyIncomePlans: [
          _plan('給料', DateTime(2026, 8, 25), 421277),
        ],
        payslipSalaryIncomes: const [
          {'pay_date': '2026-08-25', 'amount': 421277},
        ],
        payslipRows: const [],
        flowDisplayTitle: _title,
      );
      expect(result.incomes, hasLength(1));
      expect(result.incomes.single.amount, 421277);
    });

    test('received income plans dedupe by same date and amount', () {
      final result = AssetSalarySpendingEntries.build(
        cardStatementLines: const [],
        recentFlows: const [],
        monthlyIncomePlans: [
          _plan('給料', DateTime(2026, 6, 25), 300000),
          _plan('給料(重複)', DateTime(2026, 6, 25), 300000),
          _plan('副収入', DateTime(2026, 6, 20), 20000),
        ],
        payslipSalaryIncomes: const [],
        payslipRows: const [],
        flowDisplayTitle: _title,
      );

      expect(result.incomes, hasLength(2));
    });

    test('payslip rows add net amounts as income, skipping non-positive', () {
      final result = AssetSalarySpendingEntries.build(
        cardStatementLines: const [],
        recentFlows: const [],
        monthlyIncomePlans: const [],
        payslipSalaryIncomes: const [],
        payslipRows: const [
          <String, dynamic>{
            'pay_date': '2026-06-25',
            'net_amount': 280000,
            'company_name': '自分株式会社',
          },
          <String, dynamic>{'pay_date': '2026-06-26', 'net_amount': 0},
        ],
        flowDisplayTitle: _title,
      );

      expect(result.incomes, hasLength(1));
      expect(result.incomes.single.description, '給与明細: 自分株式会社');
    });
  });
}
