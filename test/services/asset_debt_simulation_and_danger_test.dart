import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_debt_danger_service.dart';
import 'package:my_web_app/services/asset_debt_simulation_service.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AssetDebtSimulationService (#1369 / #2750)', () {
    const mobitHigh = MultiDebtInputItem(
      id: 'mobit',
      name: 'モビット',
      balance: 500000,
      annualRate: 0.18,
      monthlyPayment: 20000,
      daysUntilNextPayment: 30,
    );
    const bankLow = MultiDebtInputItem(
      id: 'bank_loan',
      name: '銀行フリーローン',
      balance: 400000,
      annualRate: 0.12,
      monthlyPayment: 15000,
      daysUntilNextPayment: 30,
    );

    test('calculates daily interest formula and principal split accurately',
        () {
      final breakdown = AssetDebtSimulationService.calculateDailyInterest(
        mobitHigh,
      );
      expect(breakdown.dailyInterest, closeTo(500000 * 0.18 / 365 * 30, 0.01));
      expect(
        breakdown.principalPortion,
        closeTo(20000 - breakdown.dailyInterest, 0.01),
      );
      expect(breakdown.interestExceedsPayment, isFalse);

      const negAmort = MultiDebtInputItem(
        id: 'neg',
        name: '利息超過テスト',
        balance: 500000,
        annualRate: 0.18,
        monthlyPayment: 5000,
        daysUntilNextPayment: 30,
      );
      final negBreakdown = AssetDebtSimulationService.calculateDailyInterest(
        negAmort,
      );
      expect(negBreakdown.principalPortion, 0);
      expect(negBreakdown.interestExceedsPayment, isTrue);
    });

    test('allocates lump-sum extra to highest-rate debt first (avalanche)', () {
      const bankLowForAvalanche = MultiDebtInputItem(
        id: 'bank_loan',
        name: '銀行フリーローン',
        balance: 250000,
        annualRate: 0.12,
        monthlyPayment: 15000,
        daysUntilNextPayment: 30,
      );
      final summary = AssetDebtSimulationService.simulateMultiDebtAvalanche(
        items: const <MultiDebtInputItem>[bankLowForAvalanche, mobitHigh],
        extraAmount: 100000,
      );

      expect(summary.allocations, hasLength(1));
      expect(summary.allocations.first.debtId, 'mobit');
      expect(summary.allocations.first.appliedAmount, 100000);
      expect(summary.allocations.first.remainingBalanceAfterExtra, 400000);
      expect(summary.monthsSaved, isNotNull);
      expect(summary.monthsSaved, greaterThan(0));
      expect(summary.interestSaved, isNotNull);
      expect(summary.interestSaved, greaterThan(0));
    });

    test('supports monthly recurring extra payment mode (#1369)', () {
      final summary = AssetDebtSimulationService.simulateMultiDebtAvalanche(
        items: const <MultiDebtInputItem>[mobitHigh, bankLow],
        extraAmount: 10000,
        isMonthlyRecurring: true,
      );

      expect(summary.isMonthlyRecurring, isTrue);
      expect(summary.allocations, hasLength(1));
      expect(summary.allocations.first.debtId, 'mobit');
      expect(summary.monthsSaved, isNotNull);
      expect(summary.monthsSaved, greaterThan(0));
      expect(summary.interestSaved, greaterThan(0));
    });

    test(
        'consolidation compares monthly payment and warns on long term (#2750)',
        () {
      final goodPlan = AssetDebtSimulationService.simulateConsolidation(
        items: const <MultiDebtInputItem>[mobitHigh, bankLow],
        consolidatedAnnualRate: 0.09,
        consolidatedTermMonths: 36,
      );
      expect(goodPlan.totalPrincipal, 900000);
      expect(goodPlan.currentMonthlyPaymentTotal, 35000);
      expect(goodPlan.weightedAverageAnnualRate, closeTo(0.15333, 0.001));
      expect(goodPlan.monthlyPaymentSavings, greaterThan(0));
      expect(goodPlan.totalInterestSavings, isNotNull);
      expect(goodPlan.totalInterestSavings, greaterThan(0));
      expect(goodPlan.increasesTotalInterest, isFalse);

      final longTermPlan = AssetDebtSimulationService.simulateConsolidation(
        items: const <MultiDebtInputItem>[mobitHigh, bankLow],
        consolidatedAnnualRate: 0.14,
        consolidatedTermMonths: 120,
      );
      expect(longTermPlan.increasesTotalInterest, isTrue);
      expect(longTermPlan.totalInterestDiff, greaterThan(0));

      final zeroRatePlan = AssetDebtSimulationService.simulateConsolidation(
        items: const <MultiDebtInputItem>[mobitHigh],
        consolidatedAnnualRate: 0,
        consolidatedTermMonths: 20,
        overrideTotalPrincipal: 200000,
      );
      expect(zeroRatePlan.consolidatedMonthlyPayment, 10000);
      expect(zeroRatePlan.consolidatedTotalInterest, 0);
    });
  });

  group('AssetDebtDangerService (#1370)', () {
    const planner = AssetLiabilityPlanningService();

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    AssetLiabilityMonthlySnapshot makeSnapshot(
      String monthKey,
      double negativeLiabilityTotal,
    ) {
      return AssetLiabilityMonthlySnapshot(
        monthKey: monthKey,
        savedAt: DateTime(2026, 6, 1),
        positiveAssetTotal: 100000,
        liabilityTotal: negativeLiabilityTotal,
        netWorth: 100000 + negativeLiabilityTotal,
        cashLikeTotal: 100000,
        monthlyScheduledPaymentTotal: 50000,
        monthlyPaidPaymentTotal: 0,
        monthlyUnpaidPaymentTotal: 50000,
        overduePaymentCount: 0,
      );
    }

    test('triggers on repayment-to-income ratio and adapts to thresholds', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          '三井住友銀行大塚支店': 50000,
          'モビット': -300000,
          'アコムローン': -300000,
        },
        monthlyPaymentOverrides: const <String, double>{
          'mobit': 40000,
          'acom_card_loan': 40000,
        },
        baseDate: DateTime(2026, 6, 15),
      );

      final highRisk = AssetDebtDangerService.evaluate(
        workbook: workbook,
        monthlyIncome: 200000,
      );
      expect(highRisk.exceedsIncomeRatioThreshold, isTrue);
      expect(highRisk.repaymentToIncomeRatio, closeTo(0.40, 0.01));
      expect(highRisk.isAlertTriggered, isTrue);

      final relaxed = AssetDebtDangerService.evaluate(
        workbook: workbook,
        monthlyIncome: 200000,
        settings: const DebtDangerSettings(
          repaymentToIncomeThreshold: 0.50,
          stagnantMonthsThreshold: 3,
        ),
      );
      expect(relaxed.exceedsIncomeRatioThreshold, isFalse);
      expect(relaxed.isAlertTriggered, isFalse);
    });

    test('detects consecutive non-decreasing negative liabilityTotal snapshots',
        () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          '三井住友銀行大塚支店': 50000,
          'モビット': -520000,
        },
        monthlyPaymentOverrides: const <String, double>{'mobit': 20000},
        baseDate: DateTime(2026, 6, 15),
      );

      final stagnant = AssetDebtDangerService.evaluate(
        workbook: workbook,
        monthlyIncome: 400000,
        monthlySnapshots: <AssetLiabilityMonthlySnapshot>[
          makeSnapshot('2026-04', -500000),
          makeSnapshot('2026-05', -510000),
          makeSnapshot('2026-06', -520000),
        ],
      );
      expect(stagnant.consecutiveNonDecreasingMonths, 3);
      expect(stagnant.isDebtBalanceStagnant, isTrue);
      expect(stagnant.isAlertTriggered, isTrue);

      final decreasing = AssetDebtDangerService.evaluate(
        workbook: workbook,
        monthlyIncome: 400000,
        monthlySnapshots: <AssetLiabilityMonthlySnapshot>[
          makeSnapshot('2026-04', -500000),
          makeSnapshot('2026-05', -480000),
          makeSnapshot('2026-06', -460000),
        ],
      );
      expect(decreasing.consecutiveNonDecreasingMonths, 0);
      expect(decreasing.isDebtBalanceStagnant, isFalse);
      expect(decreasing.isAlertTriggered, isFalse);
    });

    test('persists DebtDangerSettings round-trip via SharedPreferences',
        () async {
      const saved = DebtDangerSettings(
        repaymentToIncomeThreshold: 0.40,
        stagnantMonthsThreshold: 4,
        bannerDismissed: true,
      );
      await AssetDebtDangerSettingsStore.save(saved);
      final loaded = await AssetDebtDangerSettingsStore.load();
      expect(loaded.repaymentToIncomeThreshold, closeTo(0.40, 0.001));
      expect(loaded.stagnantMonthsThreshold, 4);
      expect(loaded.bannerDismissed, isTrue);
    });
  });
}
