import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';
import 'package:my_web_app/services/asset_liability_repayment_simulation_service.dart';

void main() {
  group('AssetLiabilityRepaymentSimulationService.buildComparison', () {
    const planner = AssetLiabilityPlanningService();
    const service = AssetLiabilityRepaymentSimulationService();

    test('switches priority order by strategy', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          'cash': 100000,
          'mobit': -120000,
          'aupay card': -90000,
          'paypay card': -30000,
        },
        baseDate: DateTime(2026, 5, 1),
        monthlyPaymentOverrides: const <String, double>{
          'mobit': 10000,
          'aupay card': 8000,
          'paypay card': 6000,
        },
        annualRateOverrides: const <String, double>{
          'mobit': 0.18,
          'aupay card': 0.08,
          'paypay card': 0.15,
        },
      );

      final result = service.buildComparison(
        workbook: workbook,
        extraMonthlyPayment: 10000,
      );

      expect(
        result
            .planFor(AssetLiabilityRepaymentSimulationStrategy.interestRate)
            ?.firstFocusDebtName,
        'mobit',
      );
      expect(
        result
            .planFor(AssetLiabilityRepaymentSimulationStrategy.smallestBalance)
            ?.firstFocusDebtName,
        'paypay card',
      );
      expect(
        result
            .planFor(AssetLiabilityRepaymentSimulationStrategy.paymentDay)
            ?.firstFocusDebtName,
        'aupay card',
      );
    });

    test('extra monthly repayment shortens payoff timing and interest', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          'cash': 150000,
          'mobit': -180000,
          'aupay card': -120000,
        },
        baseDate: DateTime(2026, 5, 1),
        monthlyPaymentOverrides: const <String, double>{
          'mobit': 12000,
          'aupay card': 8000,
        },
        annualRateOverrides: const <String, double>{
          'mobit': 0.18,
          'aupay card': 0.15,
        },
      );

      final baseline = service
          .buildComparison(workbook: workbook)
          .planFor(AssetLiabilityRepaymentSimulationStrategy.interestRate);
      final withExtra = service
          .buildComparison(workbook: workbook, extraMonthlyPayment: 30000)
          .planFor(AssetLiabilityRepaymentSimulationStrategy.interestRate);

      expect(baseline?.estimatedPayoffMonths, isNotNull);
      expect(withExtra?.estimatedPayoffMonths, isNotNull);
      expect(
        withExtra!.estimatedPayoffMonths,
        lessThan(baseline!.estimatedPayoffMonths!),
      );
      expect(
        withExtra.estimatedInterestTotal,
        lessThan(baseline.estimatedInterestTotal),
      );
    });

    test('excludes paid and card-billed debts without mutating workbook', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          'cash': 80000,
          'au': -12000,
          'aupay card': -60000,
          'paypay card': -20000,
          'mobit': -100000,
        },
        baseDate: DateTime(2026, 5, 1),
        monthlyPaymentOverrides: const <String, double>{
          'aupay card': 9000,
          'paypay card': 7000,
          'mobit': 10000,
        },
        paidAccountNames: const <String>{'paypay card'},
      );
      final before = workbook.debtMasterRows
          .map((row) => '${row.id}:${row.balance}:${row.paid}')
          .toList();

      final result = service.buildComparison(
        workbook: workbook,
        extraMonthlyPayment: 5000,
      );
      final selectedPlan = result.planFor(
        AssetLiabilityRepaymentSimulationStrategy.interestRate,
      );
      final after = workbook.debtMasterRows
          .map((row) => '${row.id}:${row.balance}:${row.paid}')
          .toList();

      expect(result.eligibleDebtCount, 2);
      expect(
        selectedPlan?.priorityRows.map((row) => row.name),
        isNot(contains('au')),
      );
      expect(
        selectedPlan?.priorityRows.map((row) => row.name),
        isNot(contains('paypay card')),
      );
      expect(after, before);
    });

    test('panel excludes scheduled recurring expenses but keeps real principal', () {
      final recurring = planner.buildWorkbook(
        latestSnapshot: const <String, double>{},
        baseDate: DateTime(2026, 10, 1),
        recurringFixedCosts: const <AssetRecurringFixedCost>[
          AssetRecurringFixedCost(
            id: 'synthetic-recurring',
            name: 'Synthetic recurring',
            amount: 1000,
            paymentDay: 20,
          ),
        ],
      );
      expect(recurring.scheduledExpenseAccountIds, isNotEmpty);
      expect(service.buildComparison(workbook: recurring).eligibleDebtCount, 1);
      expect(service.buildPanelComparison(workbook: recurring).hasEligibleDebt, isFalse,);

      final mixed = planner.buildWorkbook(
        latestSnapshot: const <String, double>{'mobit': -5000},
        baseDate: DateTime(2026, 10, 1),
        monthlyPaymentOverrides: const <String, double>{'mobit': 1000},
        annualRateOverrides: const <String, double>{'mobit': 0},
        recurringFixedCosts: const <AssetRecurringFixedCost>[
          AssetRecurringFixedCost(
            id: 'synthetic-recurring',
            name: 'Synthetic recurring',
            amount: 1000,
            paymentDay: 20,
          ),
        ],
      );
      final before = mixed.debtMasterRows.map((row) => '${row.id}:${row.balance}:${row.paid}').toList();
      final plan = service.buildPanelComparison(workbook: mixed).plans.first;
      expect(plan.startingBalanceTotal, 5000);
      expect(plan.monthlyPaymentBudget, 1000);
      expect(plan.estimatedPayoffMonths, 5);
      expect(plan.estimatedInterestTotal, 0);
      expect(plan.hasInterestEstimate, isTrue);
      expect(mixed.debtMasterRows.map((row) => '${row.id}:${row.balance}:${row.paid}'), before,);
    });

    test('panel keeps real full-payment liability and excludes only scheduled ids', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{'家賃': -1000},
        baseDate: DateTime(2026, 10, 1),
      );
      expect(workbook.scheduledExpenseAccountIds, isEmpty);
      expect(service.buildPanelComparison(workbook: workbook).eligibleDebtCount, 1,);
    });

    test('paid principal stays outside panel but report opt-in is unchanged', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{'mobit': -5000},
        baseDate: DateTime(2026, 10, 1),
        paidAccountNames: const <String>{'mobit'},
      );
      expect(service.buildPanelComparison(workbook: workbook).hasEligibleDebt, isFalse,);
      expect(service.buildComparison(workbook: workbook, includePaidPrincipal: true).eligibleDebtCount, 1,);
    });

    test('zero planned payment differs from unknown and actual zero', () {
      final zero = planner.buildWorkbook(
        latestSnapshot: const <String, double>{'mobit': -5000},
        baseDate: DateTime(2026, 10, 1),
        monthlyPaymentOverrides: const <String, double>{'mobit': 0},
        actualPaymentAmounts: const <String, double>{'mobit': 0},
      );
      expect(zero.debtMasterRows.single.manualPaymentAmount, 0);
      expect(zero.debtMasterRows.single.actualPaymentAmount, 0);
      final stopped = service.buildPanelComparison(workbook: zero).plans.first;
      expect(stopped.estimatedPayoffMonths, isNull);
      expect(stopped.hasInterestEstimate, isFalse);

      final missing = planner.buildWorkbook(
        latestSnapshot: const <String, double>{'mobit': -5000},
        baseDate: DateTime(2026, 10, 1),
        actualPaymentAmounts: const <String, double>{'mobit': 0},
      );
      expect(missing.debtMasterRows.single.manualPaymentAmount, isNull);
      expect(missing.debtMasterRows.single.actualPaymentAmount, 0);
      expect(missing.debtMasterRows.single.paymentAmountEstimated, isTrue);
      expect(service.buildPanelComparison(workbook: missing).plans.first.monthlyPaymentBudget, greaterThan(0),);
      final noActual = planner.buildWorkbook(
        latestSnapshot: const <String, double>{'mobit': -5000},
        baseDate: DateTime(2026, 10, 1),
      );
      expect(noActual.debtMasterRows.single.actualPaymentAmount, isNull);
    });

    test('panel still excludes card-billed details', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{'au': -1000, 'aupay card': -5000},
        baseDate: DateTime(2026, 10, 1),
      );
      final plan = service.buildPanelComparison(workbook: workbook).plans.first;
      expect(plan.priorityRows.map((row) => row.name), isNot(contains('au')));
      expect(plan.startingBalanceTotal, 5000);
    });

    test('interest availability matches zero-budget epsilon and empty return', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{'mobit': -5000},
        baseDate: DateTime(2026, 10, 1),
        monthlyPaymentOverrides: const <String, double>{'mobit': 0},
      );
      final atLimit = service.buildPanelComparison(
        workbook: workbook,
        extraMonthlyPayment: 0.01,
      ).plans.first;
      expect(atLimit.monthSnapshots, isEmpty);
      expect(atLimit.hasInterestEstimate, isFalse);
      final aboveLimit = service.buildPanelComparison(
        workbook: workbook,
        extraMonthlyPayment: 0.02,
      ).plans.first;
      expect(aboveLimit.monthSnapshots, isNotEmpty);
      expect(aboveLimit.hasInterestEstimate, isTrue);
      final empty = service.buildPanelComparison(
        workbook: planner.buildWorkbook(
          latestSnapshot: const <String, double>{},
          baseDate: DateTime(2026, 10, 1),
        ),
      ).plans.first;
      expect(empty.startingBalanceTotal, 0);
      expect(empty.estimatedPayoffMonths, 0);
      expect(empty.hasInterestEstimate, isTrue);
    });
  });
}
