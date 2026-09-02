import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/disposable_balance_service.dart';

void main() {
  group('DisposableBalanceService', () {
    const service = DisposableBalanceService();

    test('calculates next payday and daily disposable pace', () {
      final result = service.build(
        asOfDate: DateTime(2026, 5, 25),
        payslips: <DisposableBalancePayslip>[
          DisposableBalancePayslip(
            payDate: DateTime(2026, 5, 25),
            netAmount: 465108,
            companyName: 'Acme',
            confidence: 0.9,
          ),
        ],
        recurringExpenses: const <DisposableBalanceRecurringExpense>[
          DisposableBalanceRecurringExpense(
            name: 'Rent',
            amount: 92400,
            dayOfMonth: 27,
            category: 'housing',
          ),
        ],
        debts: <DisposableBalanceDebt>[
          DisposableBalanceDebt(
            name: 'student loan',
            monthlyPayment: 58000,
            principal: 800000,
            interestRate: 0.03,
            lastUpdated: DateTime(2026, 2, 1),
          ),
        ],
      );

      expect(result.nextPayday, DateTime(2026, 6, 25));
      expect(result.daysRemaining, 30);
      expect(result.disposable, 314708);
      expect(result.debtReductionSpendingLimit, 314708);
      expect(result.debtInterestTotal, 2000);
      expect(result.debtPrincipalTotal, 56000);
      expect(result.dailyPace.round(), 10490);
      expect(result.recurringExpenses, hasLength(1));
      expect(result.recurringExpenses.single.name, 'Rent');
      expect(result.recurringExpenses.single.amount, 92400);
      expect(result.debts, hasLength(1));
      expect(result.debts.single.name, 'student loan');
      expect(result.debts.single.monthlyPayment, 58000);
      expect(
        result.requiredActions.single.actionKey,
        'refresh_debt_student_loan',
      );
    });

    test('uses explicit principal and interest split when provided', () {
      final result = service.build(
        asOfDate: DateTime(2026, 5, 30),
        payslips: <DisposableBalancePayslip>[
          DisposableBalancePayslip(
            payDate: DateTime(2026, 5, 25),
            netAmount: 452815,
          ),
        ],
        recurringExpenses: const <DisposableBalanceRecurringExpense>[
          DisposableBalanceRecurringExpense(name: 'Rent', amount: 63000),
        ],
        debts: const <DisposableBalanceDebt>[
          DisposableBalanceDebt(
            name: 'card loan',
            monthlyPayment: 68000,
            principal: 500000,
            principalPayment: 61000,
            interestPayment: 7000,
          ),
          DisposableBalanceDebt(
            name: 'shopping',
            monthlyPayment: 22000,
            principal: 120000,
            principalPayment: 22000,
          ),
        ],
      );

      expect(result.debtTotal, 90000);
      expect(result.debtPrincipalTotal, 83000);
      expect(result.debtInterestTotal, 7000);
      expect(result.debtReductionSpendingLimit, 299815);
      expect(result.disposable, result.debtReductionSpendingLimit);
    });

    test('subtracts rent due on the salary cycle start', () {
      final result = service.build(
        asOfDate: DateTime(2026, 5, 26),
        payslips: <DisposableBalancePayslip>[
          DisposableBalancePayslip(
            payDate: DateTime(2026, 5, 25),
            netAmount: 452815,
            companyName: 'Acme',
            confidence: 0.9,
          ),
        ],
        recurringExpenses: const <DisposableBalanceRecurringExpense>[
          DisposableBalanceRecurringExpense(
            name: 'Rent',
            amount: 63000,
            dayOfMonth: 25,
            category: 'housing',
          ),
        ],
      );

      expect(result.nextPayday, DateTime(2026, 6, 25));
      expect(result.fixedTotal, 63000);
      expect(result.recurringExpenses.single.dayOfMonth, 25);
      expect(result.disposable, 389815);
      expect(
        result.requiredActions.map((action) => action.actionKey),
        isNot(contains('add_recurring_expenses')),
      );
    });

    test(
      'requests payslip and fixed expense setup when sources are missing',
      () {
        final result = service.build(asOfDate: DateTime(2026, 5, 26));

        expect(result.income, 0);
        expect(
          result.requiredActions.map((action) => action.actionKey),
          containsAll(<String>[
            'upload_current_payslip',
            'add_recurring_expenses',
          ]),
        );
      },
    );

    test('detects duplicate music subscriptions', () {
      final result = service.build(
        asOfDate: DateTime(2026, 5, 25),
        payslips: <DisposableBalancePayslip>[
          DisposableBalancePayslip(
            payDate: DateTime(2026, 5, 25),
            netAmount: 300000,
          ),
        ],
        recurringExpenses: const <DisposableBalanceRecurringExpense>[
          DisposableBalanceRecurringExpense(name: 'Spotify', amount: 980),
          DisposableBalanceRecurringExpense(name: 'Apple Music', amount: 1080),
        ],
      );

      expect(
        result.requiredActions.map((action) => action.actionKey),
        contains('cancel_duplicate_music'),
      );
    });
  });

  group('DisposableBalanceActionMergeService', () {
    const service = DisposableBalanceActionMergeService();

    test('keeps local data gaps and merges server recommendations by key', () {
      final result = service.merge(
        serverActions: const <Map<String, dynamic>>[
          <String, dynamic>{
            'action_key': 'add_recurring_expenses',
            'title': 'stale fixed-cost action',
          },
          <String, dynamic>{
            'action_key': 'cancel_duplicate_music',
            'title': 'music saving',
          },
        ],
        localActions: const <Map<String, dynamic>>[
          <String, dynamic>{
            'action_key': 'upload_current_payslip',
            'title': 'current payslip missing',
          },
          <String, dynamic>{
            'action_key': 'cancel_duplicate_music',
            'title': 'local duplicate',
          },
        ],
      );

      expect(result.map((action) => action['action_key']), <String>[
        'upload_current_payslip',
        'cancel_duplicate_music',
      ]);
      expect(result.first['title'], 'current payslip missing');
      expect(result.last['title'], 'music saving');
    });
  });
}
