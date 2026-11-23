import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_payment_reminder_service.dart';
import 'package:my_web_app/services/asset_spending_value_classification_service.dart';
import 'package:my_web_app/services/salary_spending_breakdown_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

AssetLiabilityDebtRow _buildDebtRow({
  required String id,
  required String name,
  double balance = -200000,
  int? paymentDay = 10,
  double annualRate = 0.146,
  double scheduledPaymentAmount = 15000,
  bool paid = false,
  bool requiresAction = true,
  bool isDirectCashflowTarget = true,
  double? lateFeeAnnualRate,
  int overdueDays = 0,
  double estimatedLateFeeAmount = 0,
}) {
  return AssetLiabilityDebtRow(
    id: id,
    name: name,
    kind: AssetLiabilityAccountKind.cardLoan,
    balance: balance,
    paymentDay: paymentDay,
    paymentSourceAccountId: 'smbc_otsuka',
    paymentSourceAccountName: '三井住友銀行大塚支店',
    paymentMethod: isDirectCashflowTarget
        ? AssetLiabilityPaymentMethod.direct
        : AssetLiabilityPaymentMethod.includedInCard,
    paymentMethodLabel: isDirectCashflowTarget ? '直接支払い' : 'カード合算',
    paymentMethodSettingSource:
        AssetLiabilityPaymentMethodSettingSource.builtInDefault,
    billingAccountId: isDirectCashflowTarget ? null : 'parent_card',
    billingAccountName: isDirectCashflowTarget ? null : '親カード',
    includedInBillingAccount: !isDirectCashflowTarget,
    annualRate: annualRate,
    minimumPaymentEstimate: scheduledPaymentAmount,
    manualPaymentAmount: scheduledPaymentAmount,
    scheduledPaymentAmount: scheduledPaymentAmount,
    monthlyInterestEstimate: 2000,
    principalPaymentEstimate: 13000,
    balanceAfterPaymentEstimate: balance + 13000,
    liabilityShare: 0.5,
    priorityLabel: '高',
    paymentAmountEstimated: false,
    billingConfirmed: true,
    paid: paid,
    requiresAction: requiresAction,
    lateFeeAnnualRate: lateFeeAnnualRate,
    overdueDays: overdueDays,
    estimatedLateFeeAmount: estimatedLateFeeAmount,
  );
}

AssetLiabilityWorkbook _buildWorkbook({
  required DateTime baseDate,
  required List<AssetLiabilityDebtRow> rows,
}) {
  return AssetLiabilityWorkbook(
    baseDate: baseDate,
    accounts: const <AssetLiabilityAccount>[],
    debtMasterRows: rows,
    repaymentPriorityRows: const <AssetLiabilityDebtRow>[],
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
    cashLikeTotal: 100000,
    securitiesTotal: 0,
    positiveAssetTotal: 100000,
    liabilityTotal: -400000,
    netWorth: -300000,
    monthlyMinimumPaymentEstimateTotal: 30000,
    monthlyScheduledPaymentTotal: 30000,
    monthlyActualPaymentTotal: 0,
    monthlyPaymentDifferenceTotal: 0,
    monthlyUnpaidPaymentTotal: 30000,
    monthlyUnreceivedIncomeTotal: 0,
    cashAfterMinimumPayments: 70000,
    cashAfterScheduledPayments: 70000,
    debtToAssetRatio: 4.0,
    topFourDebtShare: 1.0,
    manualPaymentCount: rows.length,
    estimatedPaymentCount: 0,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('AssetSpendingValueClassificationService (#1368)', () {
    test(
        'classifies consumption/waste/investment and keeps unknown withdrawals in needsReview',
        () {
      final entries = <SalarySpendingEntry>[
        SalarySpendingEntry(
          date: DateTime(2026, 6, 1),
          amount: 70000,
          description: '家賃・食費',
          sourceLabel: '収支履歴',
        ),
        SalarySpendingEntry(
          date: DateTime(2026, 6, 2),
          amount: 5000,
          description: 'ATM手数料・パチンコ',
          sourceLabel: '収支履歴',
        ),
        SalarySpendingEntry(
          date: DateTime(2026, 6, 3),
          amount: 25000,
          description: 'NISAつみたて投資信託',
          sourceLabel: '収支履歴',
        ),
        SalarySpendingEntry(
          date: DateTime(2026, 6, 4),
          amount: 12000,
          description: '使途不明金（残高差分から自動記録）',
          sourceLabel: '残高差分',
        ),
      ];

      final report = AssetSpendingValueClassificationService.buildReport(
        entries: entries,
      );

      expect(report.classifiedTotal, 100000);
      expect(report.needsReviewCount, 1);
      expect(report.needsReviewTotal, 12000);
      expect(report.consumption.actualPercent, closeTo(70.0, 0.01));
      expect(report.waste.actualPercent, closeTo(5.0, 0.01));
      expect(report.investment.actualPercent, closeTo(25.0, 0.01));

      final unknown = report.entries.firstWhere(
        (e) => e.entry.description.contains('使途不明'),
      );
      expect(unknown.category, SpendingValueCategory.needsReview);
      expect(unknown.isCandidateWaste, isTrue);
    });

    test('applies user override and highlights waste excess vs 70:5:25 target',
        () async {
      final withdrawal = SalarySpendingEntry(
        date: DateTime(2026, 6, 5),
        amount: 20000,
        description: '現金引出し',
        sourceLabel: '銀行明細',
      );
      final food = SalarySpendingEntry(
        date: DateTime(2026, 6, 6),
        amount: 80000,
        description: 'スーパー食費',
        sourceLabel: 'カード明細',
      );
      final fp =
          AssetSpendingValueClassificationService.fingerprintFor(withdrawal);

      await AssetSpendingValueOverrideStore.saveOverrides(
        <String, SpendingValueCategory>{fp: SpendingValueCategory.waste},
      );
      final loadedOverrides =
          await AssetSpendingValueOverrideStore.loadOverrides();

      final report = AssetSpendingValueClassificationService.buildReport(
        entries: <SalarySpendingEntry>[food, withdrawal],
        overrides: loadedOverrides,
      );

      expect(report.waste.actualPercent, closeTo(20.0, 0.01));
      expect(report.waste.deltaPercent, closeTo(15.0, 0.01));
      expect(
        report.adviceList.any((msg) => msg.contains('浪費が目安（5%）を +15.0pt')),
        isTrue,
      );
    });

    test('parses tagged CSV rows and roundtrips custom entries store',
        () async {
      const csv = '''
日付,金額,摘要,分類
2026-06-01,3500,技術書 Flutter実践,投資
2026-06-02,220,ATM手数料,浪費
2026-06-03,4500,スーパー日用品
invalid-line
''';
      final parsed =
          AssetSpendingValueClassificationService.parseTaggedImportCsv(csv);
      expect(parsed, hasLength(3));
      expect(parsed[0].category, SpendingValueCategory.investment);
      expect(parsed[1].category, SpendingValueCategory.waste);
      expect(parsed[2].category, SpendingValueCategory.consumption);

      await AssetSpendingValueOverrideStore.saveCustomEntries(parsed);
      final restored =
          await AssetSpendingValueOverrideStore.loadCustomEntries();
      expect(restored, hasLength(3));
      expect(restored.first.description, '技術書 Flutter実践');
      expect(restored.first.category, SpendingValueCategory.investment);
    });
  });

  group('AssetPaymentReminderService (#2749)', () {
    test(
        'detects upcoming, dueToday, overdue reminders and daily late fee rate',
        () {
      // baseDate=2026-06-10, salaryDay=25 -> cycle dates: 27..31 are May, 1..24 are June.
      final workbook = _buildWorkbook(
        baseDate: DateTime(2026, 6, 10),
        rows: <AssetLiabilityDebtRow>[
          _buildDebtRow(
            id: 'overdue_loan',
            name: '延滞ローン',
            paymentDay: 5,
            scheduledPaymentAmount: 36500,
            annualRate: 0.146,
            lateFeeAnnualRate: 0.20,
            overdueDays: 5,
            estimatedLateFeeAmount: 100,
          ),
          _buildDebtRow(
            id: 'today_loan',
            name: '本日期日カード',
            paymentDay: 10,
            scheduledPaymentAmount: 12000,
          ),
          _buildDebtRow(
            id: 'upcoming_loan',
            name: '接近ローン',
            paymentDay: 12,
            scheduledPaymentAmount: 8000,
          ),
          _buildDebtRow(
            id: 'far_loan',
            name: '先の日付ローン',
            paymentDay: 20,
            scheduledPaymentAmount: 9000,
          ),
        ],
      );

      final schedule = AssetPaymentReminderService.buildSchedule(
        workbook: workbook,
        salaryDay: 25,
        settings: const AssetPaymentReminderSettings(
          daysBefore: <int>[3, 1, 0],
          customLateFeeAnnualRates: <String, double>{'overdue_loan': 0.20},
        ),
      );

      expect(schedule.overdueItems, hasLength(1));
      expect(schedule.overdueItems.first.overdueDays, 5);
      // 36500 * 0.20 / 365 = 20 yen/day -> 5 days = 100 yen.
      expect(
          schedule.overdueItems.first.dailyLateFeeAmount, closeTo(20.0, 0.1));
      expect(
        schedule.overdueItems.first.estimatedLateFeeAmount,
        closeTo(100.0, 0.1),
      );

      expect(schedule.dueTodayItems, hasLength(1));
      expect(schedule.dueTodayItems.first.accountName, '本日期日カード');

      expect(schedule.upcomingItems, hasLength(1));
      expect(schedule.upcomingItems.first.daysUntilDue, 2);

      expect(schedule.emailDigestSubject, contains('返済期日超過アラート'));
      expect(schedule.emailDigestBody, contains('延滞ローン'));
      expect(schedule.emailDigestBody, contains('本日期日カード'));
    });

    test(
        'prevents duplicate dispatch and persists settings in SharedPreferences',
        () async {
      final workbook = _buildWorkbook(
        baseDate: DateTime(2026, 6, 10),
        rows: <AssetLiabilityDebtRow>[
          _buildDebtRow(
            id: 'today_loan',
            name: '本日期日カード',
            paymentDay: 10,
            scheduledPaymentAmount: 12000,
          ),
        ],
      );
      final schedule = AssetPaymentReminderService.buildSchedule(
        workbook: workbook,
        salaryDay: 25,
      );

      final dispatched = <String>[];
      final firstPass = await AssetPaymentReminderService.dispatchUndelivered(
        schedule: schedule,
        alreadyDeliveredKeys: const <String>{},
        notifier: (item) async {
          dispatched.add(item.accountId);
          return true;
        },
      );
      expect(firstPass, hasLength(1));
      expect(dispatched, <String>['today_loan']);

      final secondPass = await AssetPaymentReminderService.dispatchUndelivered(
        schedule: schedule,
        alreadyDeliveredKeys: firstPass,
        notifier: (item) async {
          dispatched.add(item.accountId);
          return true;
        },
      );
      expect(secondPass, isEmpty);
      expect(dispatched, hasLength(1));

      const settings = AssetPaymentReminderSettings(
        enabled: true,
        daysBefore: <int>[5, 3, 1, 0],
        pushEnabled: true,
        emailDigestEnabled: false,
        customLateFeeAnnualRates: <String, double>{'a': 0.25},
      );
      await AssetPaymentReminderStore.saveSettings(settings);
      final restored = await AssetPaymentReminderStore.loadSettings();
      expect(restored.daysBefore, <int>[5, 3, 1, 0]);
      expect(restored.emailDigestEnabled, isFalse);
      // Capped at 20.0% ceiling.
      expect(restored.customRateFor('a'), 0.20);

      await AssetPaymentReminderStore.saveDeliveredKeys(firstPass);
      final restoredKeys = await AssetPaymentReminderStore.loadDeliveredKeys();
      expect(restoredKeys, equals(firstPass));
    });
  });
}
