import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/debt_repayment_plan.dart';
import 'package:my_web_app/services/debt_repayment_planner_service.dart';

void main() {
  group('DebtRepaymentPlannerService.generatePlan', () {
    const service = DebtRepaymentPlannerService();

    DebtRepaymentPlanInput buildInput({
      required DebtRepaymentStrategy strategy,
      int extraBudget = 0,
    }) {
      return DebtRepaymentPlanInput(
        debts: const <DebtRepaymentInputDebt>[
          DebtRepaymentInputDebt(
            name: 'Low Balance Loan',
            balance: 50000,
            annualRate: 0.06,
            minimumPaymentRate: 0,
            minimumPaymentFloor: 5000,
            paymentDay: 20,
          ),
          DebtRepaymentInputDebt(
            name: 'High Rate Card',
            balance: 120000,
            annualRate: 0.18,
            minimumPaymentRate: 0,
            minimumPaymentFloor: 5000,
            paymentDay: 25,
          ),
          DebtRepaymentInputDebt(
            name: 'Soon Due Payment',
            balance: 90000,
            annualRate: 0.12,
            minimumPaymentRate: 0,
            minimumPaymentFloor: 5000,
            paymentDay: 5,
          ),
        ],
        strategy: strategy,
        monthlyBudget: 40000,
        extraBudget: extraBudget,
        targetMonths: 24,
        monthlyIncome: 240000,
        monthlyExpense: 150000,
        fixedCost: 30000,
        netWorth: -260000,
        note: '',
        baseMonth: DateTime(2026, 5, 1),
      );
    }

    test('switches priority by balance, interest rate, and payment day', () {
      final snowball = service.generatePlan(
        input: buildInput(strategy: DebtRepaymentStrategy.snowball),
      );
      final avalanche = service.generatePlan(
        input: buildInput(strategy: DebtRepaymentStrategy.avalanche),
      );
      final dueDate = service.generatePlan(
        input: buildInput(strategy: DebtRepaymentStrategy.dueDate),
      );

      expect(snowball.priorities.first.name, 'Low Balance Loan');
      expect(avalanche.priorities.first.name, 'High Rate Card');
      expect(dueDate.priorities.first.name, 'Soon Due Payment');
    });

    test('extra repayment shortens payoff timing and lowers interest', () {
      final base = service.generatePlan(
        input: buildInput(strategy: DebtRepaymentStrategy.avalanche),
      );
      final withExtra = service.generatePlan(
        input: buildInput(
          strategy: DebtRepaymentStrategy.avalanche,
          extraBudget: 30000,
        ),
      );

      final baseInterest = base.monthlyActions.fold<double>(
        0,
        (sum, action) => sum + action.interestTotal,
      );
      final extraInterest = withExtra.monthlyActions.fold<double>(
        0,
        (sum, action) => sum + action.interestTotal,
      );
      final baseMonths = base.estimatedCompletionMonths;
      final extraMonths = withExtra.estimatedCompletionMonths;

      expect(extraMonths, isNotNull);
      expect(baseMonths, isNotNull);
      if (baseMonths == null || extraMonths == null) {
        fail('Expected both repayment simulations to complete.');
      }
      expect(extraMonths, lessThan(baseMonths));
      expect(extraInterest, lessThan(baseInterest));
    });
  });

  group('DebtRepaymentPlannerService.buildExecutionPlan', () {
    const service = DebtRepaymentPlannerService();

    DebtRepaymentPlanInput buildInput({
      required int monthlyBudget,
      required int extraBudget,
      required int monthlyIncome,
      required int monthlyExpense,
      int fixedCost = 18000,
    }) {
      return DebtRepaymentPlanInput(
        debts: const <DebtRepaymentInputDebt>[
          DebtRepaymentInputDebt(
            name: 'Card Loan',
            balance: 180000,
            annualRate: 0.18,
            minimumPaymentRate: 0.04,
            minimumPaymentFloor: 5000,
          ),
          DebtRepaymentInputDebt(
            name: 'Shopping Card',
            balance: 90000,
            annualRate: 0.15,
            minimumPaymentRate: 0.03,
            minimumPaymentFloor: 3000,
          ),
        ],
        strategy: DebtRepaymentStrategy.snowball,
        monthlyBudget: monthlyBudget,
        extraBudget: extraBudget,
        targetMonths: 12,
        monthlyIncome: monthlyIncome,
        monthlyExpense: monthlyExpense,
        fixedCost: fixedCost,
        netWorth: -120000,
        note: 'Keep emergency cash above zero.',
        baseMonth: DateTime(2026, 4, 1),
      );
    }

    test(
        'includes focus, budget-gap, payment, and review tasks when cash is short',
        () {
      final input = buildInput(
        monthlyBudget: 35000,
        extraBudget: 10000,
        monthlyIncome: 80000,
        monthlyExpense: 50000,
      );

      final result = service.generatePlan(input: input);
      final executionPlan = service.buildExecutionPlan(
        input: input,
        result: result,
      );

      expect(executionPlan.summary, contains('Shopping Card'));
      expect(
        executionPlan.tasks.first.title,
        contains('Shopping Card'),
      );
      expect(
        executionPlan.tasks.any(
          (task) => task.kind == DebtExecutionTaskKind.focus,
        ),
        isTrue,
      );
      expect(
        executionPlan.tasks.any(
          (task) => task.kind == DebtExecutionTaskKind.budget,
        ),
        isTrue,
      );
      expect(
        executionPlan.tasks.any(
          (task) => task.kind == DebtExecutionTaskKind.payment,
        ),
        isTrue,
      );
      expect(
        executionPlan.tasks.any(
          (task) => task.kind == DebtExecutionTaskKind.review,
        ),
        isTrue,
      );
      expect(
        executionPlan.tasks.every((task) => task.dueDate.month == 4),
        isTrue,
      );
    });

    test(
        'uses fixed-cost review instead of budget-gap task when monthly plan is affordable',
        () {
      final input = buildInput(
        monthlyBudget: 20000,
        extraBudget: 5000,
        monthlyIncome: 120000,
        monthlyExpense: 70000,
        fixedCost: 22000,
      );

      final result = service.generatePlan(input: input);
      final executionPlan = service.buildExecutionPlan(
        input: input,
        result: result,
      );

      expect(
        executionPlan.tasks.any(
          (task) => task.kind == DebtExecutionTaskKind.budget,
        ),
        isFalse,
      );
      expect(
        executionPlan.tasks.any(
          (task) => task.kind == DebtExecutionTaskKind.fixedCost,
        ),
        isTrue,
      );
      expect(
        executionPlan.tasks.last.kind,
        DebtExecutionTaskKind.review,
      );
    });
  });
}
