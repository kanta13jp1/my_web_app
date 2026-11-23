import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/models/payment_funding_rule.dart';
import 'package:my_web_app/services/asset_liability_monthly_state_store.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';
import 'package:my_web_app/services/asset_liability_workbook_memoizer.dart';
import 'package:my_web_app/services/asset_management_insight_service.dart';
import 'package:my_web_app/services/asset_safety_transfer_suggestion_service.dart';
import 'package:my_web_app/services/payment_confirmation_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const planner = AssetLiabilityPlanningService();
  const insightService = AssetManagementInsightService();

  group('AssetSafetyTransferSuggestionService (#3350)', () {
    test('detects account below safety reserve and emits 1 per account', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          'じぶん銀行': 3000,
          '三井住友銀行大塚支店': 100000,
          '財布(現金)': 2000,
        },
        baseDate: DateTime(2026, 6, 10),
      );

      final suggestions = AssetSafetyTransferSuggestionService.buildSuggestions(
        workbook: workbook,
        minimumSafetyBalance: 10000,
      );

      expect(suggestions, hasLength(2));
      final byTo = <String, AssetSafetyTransferSuggestion>{
        for (final s in suggestions) s.toAccountId: s,
      };
      expect(byTo.keys, containsAll(<String>['jibun_bank', 'wallet_cash']));
      expect(byTo['wallet_cash']!.fromAccountId, 'smbc_otsuka_branch');
      expect(byTo['wallet_cash']!.isSameBankFreeTransfer, isTrue);
      expect(byTo['wallet_cash']!.amount, 8000);
      expect(byTo['jibun_bank']!.amount, 7000);

      final report = insightService.buildReport(
        workbook: workbook,
        minimumSafetyBalance: 10000,
      );
      expect(report.hasSafetyBalanceTransferSuggestions, isTrue);
      expect(report.safetyBalanceTransferSuggestions, hasLength(2));
    });

    test('clears once pending transfer task restores projected balance', () {
      final withTask = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          'じぶん銀行': 3000,
          '三井住友銀行大塚支店': 100000,
        },
        baseDate: DateTime(2026, 6, 10),
        transferTasks: <AssetLiabilityTransferTask>[
          const AssetLiabilityTransferTask(
            id: 't1',
            fromAccountId: 'smbc_otsuka_branch',
            fromAccountName: '三井住友銀行大塚支店',
            toAccountId: 'jibun_bank',
            toAccountName: 'じぶん銀行',
            amount: 7000,
            dueDate: null,
          ),
        ],
      );

      final suggestions = AssetSafetyTransferSuggestionService.buildSuggestions(
        workbook: withTask,
        minimumSafetyBalance: 10000,
      );

      expect(suggestions, isEmpty);
    });

    test('respects excludedAccountIds and donor priority', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          '財布(現金)': 2000,
          '三井住友銀行大塚支店': 150000,
          '横浜銀行': 80000,
        },
        baseDate: DateTime(2026, 6, 10),
      );

      final suggestions = AssetSafetyTransferSuggestionService.buildSuggestions(
        workbook: workbook,
        minimumSafetyBalance: 10000,
        fundingRule: const PaymentFundingRule(
          priorityAccountIds: <String>['yokohama_bank', 'smbc_otsuka_branch'],
          minimumReserve: 20000,
          excludedAccountIds: <String>{'smbc_otsuka_branch'},
        ),
      );

      expect(suggestions, hasLength(1));
      expect(suggestions.single.fromAccountId, 'yokohama_bank');
      expect(suggestions.single.amount, 8000);
    });
  });

  group('PaymentConfirmationGate (#3291)', () {
    test('flags missing income plans and post-payment negative drop', () {
      final missingPositive = PaymentConfirmationGate.evaluate(
        incomePlanCount: 0,
        monthlyAvailableAmount: 20000,
      );
      expect(missingPositive.showIncomeMissingBanner, isTrue);
      expect(missingPositive.requiresConfirmationDialog, isTrue);
      expect(
        missingPositive.severity,
        PaymentConfirmationGateSeverity.warning,
      );

      final missingNegative = PaymentConfirmationGate.evaluate(
        incomePlanCount: 0,
        monthlyAvailableAmount: -5000,
      );
      expect(
        missingNegative.severity,
        PaymentConfirmationGateSeverity.critical,
      );

      final dropsNegative = PaymentConfirmationGate.evaluate(
        incomePlanCount: 1,
        monthlyAvailableAmount: 10000,
        paymentAmount: 15000,
      );
      expect(dropsNegative.showIncomeMissingBanner, isFalse);
      expect(dropsNegative.requiresConfirmationDialog, isTrue);

      final safe = PaymentConfirmationGate.evaluate(
        incomePlanCount: 1,
        monthlyAvailableAmount: 30000,
        paymentAmount: 15000,
      );
      expect(safe.showIncomeMissingBanner, isFalse);
      expect(safe.requiresConfirmationDialog, isFalse);
      expect(safe.severity, PaymentConfirmationGateSeverity.none);
    });

    test('validates payday income input fields', () {
      expect(
        AssetLiabilityPlanningService.validateIncomePlan(
          dayOfMonth: 0,
          amount: 200000,
          name: '給与',
        ),
        isNotNull,
      );
      expect(
        AssetLiabilityPlanningService.validateIncomePlan(
          dayOfMonth: 25,
          amount: 0,
          name: '給与',
        ),
        isNotNull,
      );
      expect(
        AssetLiabilityPlanningService.validateIncomePlan(
          dayOfMonth: 25,
          amount: 200000,
          name: '   ',
        ),
        isNotNull,
      );
      expect(
        AssetLiabilityPlanningService.validateIncomePlan(
          dayOfMonth: 25,
          amount: 250000,
          name: '給与',
        ),
        isNull,
      );
    });

    test('report.incomePlanGate reacts to registered incomePlans', () {
      final withoutIncome = planner.buildWorkbook(
        latestSnapshot: const <String, double>{'三井住友銀行大塚支店': 50000},
        baseDate: DateTime(2026, 6, 10),
      );
      final reportMissing = insightService.buildReport(workbook: withoutIncome);
      expect(reportMissing.incomePlanGate.showIncomeMissingBanner, isTrue);

      final withIncome = planner.buildWorkbook(
        latestSnapshot: const <String, double>{'三井住友銀行大塚支店': 50000},
        baseDate: DateTime(2026, 6, 10),
        incomePlans: <AssetLiabilityIncomePlan>[
          AssetLiabilityIncomePlan(
            id: 'inc1',
            date: DateTime(2026, 6, 25),
            name: '給与',
            amount: 250000,
            destinationAccountId: 'smbc_otsuka_branch',
            destinationAccountName: '三井住友銀行大塚支店',
            received: false,
          ),
        ],
      );
      final reportOk = insightService.buildReport(workbook: withIncome);
      expect(reportOk.incomePlanGate.showIncomeMissingBanner, isFalse);
    });
  });

  group('PaymentFundingRule, transfer buffer & dedupeKey (#4059)', () {
    test('auto-assigns missing sources & exclusions', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          '横浜銀行': 150000,
          'じぶん銀行': 80000,
          '三井住友銀行大塚支店': 200000,
          'モビット': -90000,
        },
        baseDate: DateTime(2026, 6, 10),
        monthlyPaymentOverrides: const <String, double>{'mobit': 25000},
        paymentFundingRule: const PaymentFundingRule(
          priorityAccountIds: <String>['jibun_bank', 'yokohama_bank'],
          minimumReserve: 20000,
          excludedAccountIds: <String>{'smbc_otsuka_branch'},
        ),
      );

      final mobit = workbook.debtMasterRows.singleWhere(
        (row) => row.id == 'mobit',
      );
      expect(mobit.paymentSourceAccountId, 'jibun_bank');
    });

    test('transferBufferAmount splits shortfall + buffer across donors', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          '財布(現金)': 5000,
          '横浜銀行': 38000,
          '三井住友銀行大塚支店': 37000,
          'モビット': -50000,
        },
        baseDate: DateTime(2026, 6, 10),
        monthlyPaymentOverrides: const <String, double>{'mobit': 10000},
        paymentSourceAccountIds: const <String, String>{'mobit': 'wallet_cash'},
        transferBufferAmount: 10000,
      );

      // wallet_cash shortfall = 5,000; buffer = 10,000 => target = 15,000.
      // Donor reserve default is 30,000: yokohama has 8,000 surplus, smbc has 7,000 surplus.
      expect(workbook.transferSuggestions, hasLength(2));
      final totalTransferred = workbook.transferSuggestions.fold<double>(
        0,
        (sum, s) => sum + s.amount,
      );
      expect(totalTransferred, 15000);
      expect(workbook.transferSuggestions.first.targetPaymentName, 'モビット');
      expect(workbook.transferSuggestions.first.targetPaymentDate, isNotNull);

      final report = insightService.buildReport(workbook: workbook);
      expect(
        report.movementSuggestions.first.reason,
        contains('モビット'),
      );
    });

    test('dedupeKey persists & invalidates memoizer', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      const store = AssetLiabilityMonthlyStateStore();
      final month = DateTime(2026, 6, 1);
      final task1 = AssetLiabilityTransferTask(
        id: 'tt_1',
        fromAccountId: 'smbc_otsuka_branch',
        fromAccountName: '三井住友銀行大塚支店',
        toAccountId: 'wallet_cash',
        toAccountName: '財布(現金)',
        amount: 5000,
        dueDate: DateTime(2026, 6, 15),
        dedupeKey: 'smbc_otsuka_branch__wallet_cash__5000__2026-06-15',
      );
      await store.saveMonth(
        month: month,
        state: AssetLiabilityMonthlyState(
          transferTasks: <AssetLiabilityTransferTask>[task1],
        ),
      );
      final loaded = await store.loadMonth(month);
      expect(loaded.transferTasks, hasLength(1));
      expect(
        loaded.transferTasks.single.dedupeKey,
        'smbc_otsuka_branch__wallet_cash__5000__2026-06-15',
      );

      final memoizer = AssetLiabilityWorkbookMemoizer();
      final baseArgs = DateTime(2026, 6, 10);
      AssetLiabilityWorkbook resolveWithKey(String? key) {
        return memoizer.resolve(
          planner: planner,
          latestSnapshot: const <String, double>{'三井住友銀行大塚支店': 50000},
          baseDate: baseArgs,
          confirmedPaymentDays: const <String, double>{},
          monthlyPaymentOverrides: const <String, double>{},
          actualPaymentAmounts: const <String, double>{},
          paymentDifferenceReasons: const <String, String>{},
          annualRateOverrides: const <String, double>{},
          paymentDayOverrides: const <String, int>{},
          paidAccountNames: const <String>{},
          billingConfirmedAccountIds: const <String>{},
          paymentSourceAccountIds: const <String, String>{},
          defaultPaymentSourceAccountIds: const <String, String>{},
          defaultCardBillingAccountIds: const <String, String>{},
          cardBillingAccountIds: const <String, String>{},
          revolvingConfigs: const <String,
              AssetLiabilityRevolvingCreditConfig>{},
          cardUsagePolicies: const <String, AssetCardUsagePolicy>{},
          incomePlans: const <AssetLiabilityIncomePlan>[],
          cardStatementLines: const <AssetLiabilityCardStatementLine>[],
          transferTasks: <AssetLiabilityTransferTask>[
            task1.copyWith(dedupeKey: key),
          ],
          recurringFixedCosts: const <AssetRecurringFixedCost>[],
          includeDefaultFixedPayments: false,
          salaryDay: null,
        )!;
      }

      resolveWithKey('k1');
      resolveWithKey('k1');
      expect(memoizer.cacheMisses, 1);
      expect(memoizer.cacheHits, 1);

      resolveWithKey('k2');
      expect(memoizer.cacheMisses, 2);
    });
  });
}
