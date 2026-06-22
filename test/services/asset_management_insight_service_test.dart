import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/models/user_profile.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';
import 'package:my_web_app/services/asset_management_insight_service.dart';

void main() {
  group('AssetManagementInsightService', () {
    const service = AssetManagementInsightService();
    const planner = AssetLiabilityPlanningService();

    test('marks missing payment day as an action item', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          'bank': 50000,
          'Custom Card': -10000,
        },
        baseDate: DateTime(2026, 5, 1),
      );

      final report = service.buildReport(
        workbook: workbook,
        userProfile: _userProfile(),
      );

      expect(
        report.actionItems.any(
          (item) =>
              item.type == AssetManagementInsightActionType.missingPaymentDay,
        ),
        true,
      );
    });

    test('clears missing payment day item once an override is entered', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          'bank': 50000,
          'Custom Card': -10000,
        },
        baseDate: DateTime(2026, 5, 1),
        paymentDayOverrides: const <String, int>{'Custom Card': 27},
      );

      final report = service.buildReport(
        workbook: workbook,
        userProfile: _userProfile(),
      );

      expect(
        report.actionItems.any(
          (item) =>
              item.type == AssetManagementInsightActionType.missingPaymentDay,
        ),
        false,
      );
    });

    test('marks missing annual rate as an action item', () {
      final workbook = _workbook(
        debtRows: <AssetLiabilityDebtRow>[
          _debtRow(annualRate: 0, kind: AssetLiabilityAccountKind.cardLoan),
        ],
      );

      final report = service.buildReport(
        workbook: workbook,
        userProfile: _userProfile(),
      );

      expect(
        report.actionItems.any(
          (item) =>
              item.type == AssetManagementInsightActionType.missingAnnualRate,
        ),
        true,
      );
    });

    test('does not require annual rate for full-payment fixed costs', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{'bank': 50000},
        baseDate: DateTime(2026, 5, 1),
        includeDefaultFixedPayments: true,
      );

      final report = service.buildReport(
        workbook: workbook,
        userProfile: _userProfile(),
      );

      expect(
        workbook.debtMasterRows.any(
          (row) =>
              row.id == AssetLiabilityPlanningService.rentAccountId &&
              row.fullPaymentEstimate &&
              row.annualRate == 0,
        ),
        true,
      );
      expect(
        report.actionItems.any(
          (item) =>
              item.type == AssetManagementInsightActionType.missingAnnualRate,
        ),
        false,
      );
    });

    test('marks missing payment source as an action item', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{'bank': 50000, 'PayPay': -20000},
        baseDate: DateTime(2026, 5, 1),
        monthlyPaymentOverrides: const <String, double>{'paypay_card': 20000},
      );

      final report = service.buildReport(
        workbook: workbook,
        userProfile: _userProfile(),
      );

      expect(
        report.actionItems.any(
          (item) =>
              item.type ==
              AssetManagementInsightActionType.missingPaymentSource,
        ),
        true,
      );
    });

    test('marks overdue payments as critical', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          'bank': 50000,
          'auPayカード': -10000,
        },
        baseDate: DateTime(2026, 5, 15),
        monthlyPaymentOverrides: const <String, double>{
          AssetLiabilityPlanningService.auPayCardAccountId: 10000,
        },
        paymentSourceAccountIds: const <String, String>{
          AssetLiabilityPlanningService.auPayCardAccountId: 'bank',
        },
      );

      final report = service.buildReport(workbook: workbook);

      final overdue = report.actionItems.where(
        (item) => item.type == AssetManagementInsightActionType.overduePayment,
      );
      expect(overdue.isNotEmpty, true);
      expect(overdue.first.severity, AssetManagementInsightSeverity.critical);
    });

    test('calculates today, week, and month available amounts', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{'bank': 50000, 'PayPay': -20000},
        baseDate: DateTime(2026, 5, 1),
        monthlyPaymentOverrides: const <String, double>{'paypay_card': 20000},
        paymentSourceAccountIds: const <String, String>{'paypay_card': 'bank'},
        incomePlans: <AssetLiabilityIncomePlan>[
          AssetLiabilityIncomePlan(
            id: 'salary',
            date: DateTime(2026, 5, 2),
            name: 'salary',
            amount: 5000,
            destinationAccountId: 'bank',
            destinationAccountName: 'bank',
            received: false,
          ),
        ],
      );

      final report = service.buildReport(
        workbook: workbook,
        minimumSafetyBalance: 10000,
      );

      // 新式: 今月 = 利用可能資産(bank 50000) − 給料日(5/25)までの未払い(0:
      // paypay は 5/27 で給料日後) − 安全余裕(10000) = 40000。
      // 本日 = 今月 ÷ 残日数(5/1→5/25=24)。今週 = 本日 × 今週末までの日数。
      // 2026-05-01 は金曜 → 今週末(日)まで 3 日。
      expect(report.monthAvailable.availableAmount, 40000);
      expect(report.todayAvailable.availableAmount, closeTo(40000 / 24, 0.001));
      expect(
        report.weekAvailable.availableAmount,
        closeTo(40000 / 24 * 3, 0.001),
      );
    });

    test('generates movement suggestions from accounts with surplus', () {
      // モビット(支払日15)は給料日(5/25)までに期日が来るので未払いに計上される。
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{'bank': 50000, 'モビット': -45000},
        baseDate: DateTime(2026, 5, 1),
        monthlyPaymentOverrides: const <String, double>{'mobit': 45000},
        paymentSourceAccountIds: const <String, String>{'mobit': 'bank'},
      );

      final report = service.buildReport(
        workbook: workbook,
        minimumSafetyBalance: 10000,
      );

      // 今月 = 50000 − 45000 − 10000 = -5000。
      expect(report.monthAvailable.availableAmount, -5000);
      expect(report.movementSuggestions.isNotEmpty, true);
      expect(report.movementSuggestions.first.fromAccountId, 'custom_bank');
      expect(report.movementSuggestions.first.amount, 5000);
    });

    test('generates emergency living advice for negative today cashflow', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          'bank': 50000,
          'PayPay': -200000,
        },
        baseDate: DateTime(2026, 5, 28),
        monthlyPaymentOverrides: const <String, double>{'paypay_card': 200000},
        paymentSourceAccountIds: const <String, String>{'paypay_card': 'bank'},
        incomePlans: <AssetLiabilityIncomePlan>[
          AssetLiabilityIncomePlan(
            id: 'salary',
            date: DateTime(2026, 5, 31),
            name: 'salary',
            amount: 250000,
            destinationAccountId: 'bank',
            destinationAccountName: 'bank',
            received: false,
          ),
        ],
      );

      final report = service.buildReport(
        workbook: workbook,
        minimumSafetyBalance: 10000,
      );

      // 今月 = bank 50000 − 未払い(paypay 200000, 5/27<給料日6/25) − 10000
      //      = -160000。本日はその日割りで負。
      expect(report.monthAvailable.availableAmount, closeTo(-160000, 0.001));
      expect(report.todayAvailable.availableAmount, lessThan(0));
      expect(report.emergencyAdvices.isNotEmpty, true);
      expect(report.emergencyAdvices.first.title, contains('今日の食費'));
      expect(report.emergencyAdvices.first.description, contains('水だけ'));
      expect(report.emergencyAdvices.first.description, contains('危険'));
      expect(
        report.actionItems.any(
          (item) =>
              item.type ==
              AssetManagementInsightActionType.emergencyLivingExpense,
        ),
        true,
      );
    });

    test('generates developer improvement requests', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{'bank': 50000, 'PayPay': -20000},
        baseDate: DateTime(2026, 5, 1),
      );

      final report = service.buildReport(workbook: workbook);

      expect(report.developerRequests.isNotEmpty, true);
      expect(report.developerRequests.first.description.contains('現状では'), true);
      expect(report.developerRequests.first.evidence.isNotEmpty, true);
      expect(
        report.developerRequests.first.implementationSteps.isNotEmpty,
        true,
      );
      expect(
        report.developerRequests.first.acceptanceCriteria.isNotEmpty,
        true,
      );
      expect(report.implementationContexts.isNotEmpty, true);
    });

    test('detects card billing configuration action items', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{'bank': 50000, 'KDDI': -5764},
        baseDate: DateTime(2026, 5, 1),
        monthlyPaymentOverrides: const <String, double>{
          AssetLiabilityPlanningService.kddiProviderAccountId: 5764,
        },
        cardBillingAccountIds: const <String, String>{
          AssetLiabilityPlanningService.kddiProviderAccountId: 'missing_card',
        },
      );

      final report = service.buildReport(workbook: workbook);

      expect(
        report.actionItems.any(
          (item) =>
              item.type ==
              AssetManagementInsightActionType.cardBillingConfiguration,
        ),
        true,
      );
    });

    test('accepts explicit zero yen billing without configuration item', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{'bank': 50000, 'PayPay': -20000},
        baseDate: DateTime(2026, 5, 1),
        monthlyPaymentOverrides: const <String, double>{'paypay_card': 0},
      );

      final report = service.buildReport(workbook: workbook);

      expect(
        report.actionItems.any(
          (item) =>
              item.type ==
              AssetManagementInsightActionType.cardBillingConfiguration,
        ),
        false,
      );
    });

    test('builds prompt with deterministic calculated values', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          'bank': 50000,
          'Custom Card': -10000,
        },
        baseDate: DateTime(2026, 5, 1),
      );
      final report = service.buildReport(
        workbook: workbook,
        userProfile: _userProfile(),
      );

      final prompt = const AssetManagementInsightPromptBuilder()
          .buildDetailedAdvicePrompt(report);

      expect(prompt.contains('Dart側で完了'), true);
      // リボ払いカードの照合不一致を指摘させない明示指示が含まれること。
      expect(prompt.contains('リボ払いカードの扱い'), true);
      // 残高を延滞額・今月の支払額として提示させない明示指示が含まれること。
      expect(prompt.contains('残高と支払額の区別'), true);
      expect(
        prompt.contains('「残高」を延滞額・今月の支払額として並べてはいけません'),
        true,
      );
      expect(prompt.contains('本日'), true);
      expect(prompt.contains('プロフィール詳細'), true);
      expect(prompt.contains('職業: 会社員'), true);
      expect(prompt.contains('負債マスタ詳細'), true);
      expect(prompt.contains('現実装コンテキスト'), true);
      expect(prompt.contains('asset_management_page.dart'), true);
      expect(prompt.contains('開発者向け改善提案候補'), true);
      expect(prompt.contains('受け入れ条件'), true);
      expect(prompt.contains(report.actionItems.first.title), true);
    });
  });
}

AssetLiabilityWorkbook _workbook({
  required List<AssetLiabilityDebtRow> debtRows,
}) {
  return AssetLiabilityWorkbook(
    baseDate: DateTime(2026, 5, 1),
    accounts: const <AssetLiabilityAccount>[
      AssetLiabilityAccount(
        id: 'bank',
        name: 'bank',
        kind: AssetLiabilityAccountKind.deposit,
        balance: 50000,
      ),
    ],
    debtMasterRows: debtRows,
    repaymentPriorityRows: debtRows,
    paymentDayRisks: const <AssetLiabilityPaymentDayRisk>[],
    cashflowRows: const <AssetLiabilityCashflowRow>[],
    incomePlans: const <AssetLiabilityIncomePlan>[],
    transferTasks: const <AssetLiabilityTransferTask>[],
    accountCashflowSummaries: const <AssetLiabilityAccountCashflowSummary>[],
    transferSuggestions: const <AssetLiabilityTransferSuggestion>[],
    cardBillingReview: const AssetLiabilityCardBillingReviewData(
      directPaymentItems: <AssetLiabilityCardBillingReviewItem>[],
      cardBillingGroups: <AssetLiabilityCardBillingGroup>[],
      missingBillingAccountItems: <AssetLiabilityCardBillingReviewItem>[],
      needsReviewItems: <AssetLiabilityCardBillingReviewItem>[],
      doubleCountingRiskItems: <AssetLiabilityCardBillingReviewItem>[],
    ),
    cardStatementReconciliation:
        const AssetLiabilityCardStatementReconciliationData(
      groups: <AssetLiabilityCardStatementReconciliationGroup>[],
      unmatchedStatementLines: <AssetLiabilityCardStatementLine>[],
    ),
    cashLikeTotal: 50000,
    securitiesTotal: 0,
    positiveAssetTotal: 50000,
    liabilityTotal: -10000,
    netWorth: 40000,
    monthlyMinimumPaymentEstimateTotal: 10000,
    monthlyScheduledPaymentTotal: 10000,
    monthlyActualPaymentTotal: 0,
    monthlyPaymentDifferenceTotal: 0,
    monthlyUnpaidPaymentTotal: 10000,
    monthlyUnreceivedIncomeTotal: 0,
    cashAfterMinimumPayments: 40000,
    cashAfterScheduledPayments: 40000,
    debtToAssetRatio: 0.2,
    topFourDebtShare: 1,
    manualPaymentCount: 1,
    estimatedPaymentCount: 0,
  );
}

AssetLiabilityDebtRow _debtRow({
  required double annualRate,
  required AssetLiabilityAccountKind kind,
}) {
  return AssetLiabilityDebtRow(
    id: 'loan',
    name: 'loan',
    kind: kind,
    balance: -10000,
    paymentDay: 15,
    paymentSourceAccountId: 'bank',
    paymentSourceAccountName: 'bank',
    paymentMethod: AssetLiabilityPaymentMethod.direct,
    paymentMethodLabel: '直接支払い',
    paymentMethodSettingSource:
        AssetLiabilityPaymentMethodSettingSource.builtInDefault,
    billingAccountId: null,
    billingAccountName: null,
    includedInBillingAccount: false,
    annualRate: annualRate,
    minimumPaymentEstimate: 10000,
    manualPaymentAmount: 10000,
    scheduledPaymentAmount: 10000,
    monthlyInterestEstimate: 0,
    principalPaymentEstimate: 10000,
    balanceAfterPaymentEstimate: 0,
    liabilityShare: 1,
    priorityLabel: 'test',
    paymentAmountEstimated: false,
    billingConfirmed: true,
    paid: false,
  );
}

UserProfile _userProfile() {
  return UserProfile(
    userId: 'user-1',
    displayName: 'テスト太郎',
    birthDate: DateTime(1978, 9, 30),
    gender: '男',
    occupation: '会社員',
    annualIncome: 4500000,
    address: '東京都',
    education: '大学卒',
    careerHistory: '営業職10年',
    hobbies: '音楽、AI',
    alcoholUse: '時々',
    smokingUse: '吸わない',
    favoriteFoods: 'カレー',
  );
}
