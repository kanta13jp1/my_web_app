import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/debt_repayment_plan.dart';
import 'package:my_web_app/services/debt_repayment_planner_service.dart';

void main() {
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
