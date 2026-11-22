import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';
import 'package:my_web_app/services/asset_payment_inconsistency_service.dart';

void main() {
  group('AssetPaymentInconsistencyService', () {
    const planner = AssetLiabilityPlanningService();

    test('detects R1 (paid=true, actual=null before due date)', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          '三井住友銀行大塚支店': 200000,
          'モビット': -300000,
        },
        baseDate: DateTime(2026, 9, 2),
        paymentDayOverrides: const <String, int>{'mobit': 15},
        monthlyPaymentOverrides: const <String, double>{'mobit': 12000},
        paidAccountNames: const <String>{'mobit'},
        includeDefaultFixedPayments: false,
      );

      expect(workbook.paymentInconsistencies.length, 1);
      final item = workbook.paymentInconsistencies.single;
      expect(item.accountId, 'mobit');
      expect(item.rule, AssetPaymentInconsistencyRule.paidWithoutActual);
      expect(item.ruleCode, 'R1');
      expect(item.matchesR1, isTrue);
      expect(item.matchesR3, isFalse);
      expect(item.isPastDue, isFalse);
    });

    test('detects R3 (past due, paid=true, actual=null)', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          '三井住友銀行大塚支店': 200000,
          'モビット': -300000,
        },
        baseDate: DateTime(2026, 9, 10),
        paymentDayOverrides: const <String, int>{'mobit': 5},
        monthlyPaymentOverrides: const <String, double>{'mobit': 12000},
        paidAccountNames: const <String>{'mobit'},
        includeDefaultFixedPayments: false,
      );

      expect(workbook.paymentInconsistencies.length, 1);
      final item = workbook.paymentInconsistencies.single;
      expect(item.accountId, 'mobit');
      expect(
        item.rule,
        AssetPaymentInconsistencyRule.pastDuePaidWithoutActual,
      );
      expect(item.ruleCode, 'R3');
      expect(item.matchesR1, isTrue);
      expect(item.matchesR3, isTrue);
      expect(item.isPastDue, isTrue);
    });

    test('detects R2 (scheduled=0, actual>0)', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          '三井住友銀行大塚支店': 200000,
          'PayPayカード': -20000,
        },
        baseDate: DateTime(2026, 9, 2),
        monthlyPaymentOverrides: const <String, double>{'paypay_card': 0},
        actualPaymentAmounts: const <String, double>{'paypay_card': 14616.72},
        includeDefaultFixedPayments: false,
      );

      expect(workbook.paymentInconsistencies.length, 1);
      final item = workbook.paymentInconsistencies.single;
      expect(item.accountId, 'paypay_card');
      expect(item.rule, AssetPaymentInconsistencyRule.zeroScheduledWithActual);
      expect(item.ruleCode, 'R2');
      expect(item.matchesR2, isTrue);
      expect(item.actualPaymentAmount, 14616.72);
    });

    test(
        'clears inconsistencies and reconciles cashflow/risks after recording actual or unmarking paid',
        () {
      const paymentSources = <String, String>{
        'mobit': AssetLiabilityPlanningService.smbcOtsukaBranchAccountId,
      };
      final before = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          '三井住友銀行大塚支店': 200000,
          'モビット': -300000,
        },
        baseDate: DateTime(2026, 9, 10),
        paymentDayOverrides: const <String, int>{'mobit': 5},
        monthlyPaymentOverrides: const <String, double>{'mobit': 12000},
        paidAccountNames: const <String>{'mobit'},
        paymentSourceAccountIds: paymentSources,
        includeDefaultFixedPayments: false,
      );
      expect(before.paymentInconsistencies.length, 1);

      final fixedByActual = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          '三井住友銀行大塚支店': 200000,
          'モビット': -300000,
        },
        baseDate: DateTime(2026, 9, 10),
        paymentDayOverrides: const <String, int>{'mobit': 5},
        monthlyPaymentOverrides: const <String, double>{'mobit': 12000},
        actualPaymentAmounts: const <String, double>{'mobit': 12000},
        paidAccountNames: const <String>{'mobit'},
        paymentSourceAccountIds: paymentSources,
        includeDefaultFixedPayments: false,
      );
      expect(fixedByActual.paymentInconsistencies, isEmpty);
      expect(fixedByActual.monthlyActualPaymentTotal, 12000);
      expect(
        fixedByActual.accountCashflowSummaries
            .singleWhere(
              (s) =>
                  s.accountId ==
                  AssetLiabilityPlanningService.smbcOtsukaBranchAccountId,
            )
            .projectedBalance,
        200000,
      );

      final fixedByUnmarkPaid = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          '三井住友銀行大塚支店': 200000,
          'モビット': -300000,
        },
        baseDate: DateTime(2026, 9, 10),
        paymentDayOverrides: const <String, int>{'mobit': 5},
        monthlyPaymentOverrides: const <String, double>{'mobit': 12000},
        paidAccountNames: const <String>{},
        paymentSourceAccountIds: paymentSources,
        includeDefaultFixedPayments: false,
      );
      expect(fixedByUnmarkPaid.paymentInconsistencies, isEmpty);
      final day5Risk = fixedByUnmarkPaid.paymentDayRisks.singleWhere(
        (r) => r.paymentDay == 5,
      );
      expect(day5Risk.isPast, isTrue);
      expect(day5Risk.requiresAction, isTrue);
      expect(day5Risk.accountNames, contains('モビット'));
      expect(
        fixedByUnmarkPaid.cashflowRows
            .singleWhere((r) => r.accountId == 'mobit')
            .overdue,
        isTrue,
      );
      expect(
        fixedByUnmarkPaid.accountCashflowSummaries
            .singleWhere(
              (s) =>
                  s.accountId ==
                  AssetLiabilityPlanningService.smbcOtsukaBranchAccountId,
            )
            .projectedBalance,
        188000,
      );
    });

    test(
        'detect handles null paymentDay and skips includedInBillingAccount rows, and summarize counts R1/R2/R3',
        () {
      const nullDayPaidRow = AssetLiabilityDebtRow(
        id: 'null_day_debt',
        name: '支払日未設定ローン',
        kind: AssetLiabilityAccountKind.cardLoan,
        balance: -100000,
        paymentDay: null,
        paymentSourceAccountId: 'wallet_cash',
        paymentSourceAccountName: '財布(現金)',
        paymentMethod: AssetLiabilityPaymentMethod.direct,
        paymentMethodLabel: '直接支払い',
        paymentMethodSettingSource:
            AssetLiabilityPaymentMethodSettingSource.builtInDefault,
        billingAccountId: null,
        billingAccountName: null,
        includedInBillingAccount: false,
        annualRate: 0.15,
        minimumPaymentEstimate: 10000,
        manualPaymentAmount: 10000,
        scheduledPaymentAmount: 10000,
        actualPaymentAmount: null,
        monthlyInterestEstimate: 1000,
        principalPaymentEstimate: 9000,
        balanceAfterPaymentEstimate: -91000,
        liabilityShare: 0.5,
        priorityLabel: 'A',
        paymentAmountEstimated: false,
        billingConfirmed: true,
        paid: true,
        requiresAction: false,
      );
      const pastDuePaidRow = AssetLiabilityDebtRow(
        id: 'past_due_debt',
        name: '期日超過ローン',
        kind: AssetLiabilityAccountKind.cardLoan,
        balance: -100000,
        paymentDay: 5,
        paymentSourceAccountId: 'wallet_cash',
        paymentSourceAccountName: '財布(現金)',
        paymentMethod: AssetLiabilityPaymentMethod.direct,
        paymentMethodLabel: '直接支払い',
        paymentMethodSettingSource:
            AssetLiabilityPaymentMethodSettingSource.builtInDefault,
        billingAccountId: null,
        billingAccountName: null,
        includedInBillingAccount: false,
        annualRate: 0.15,
        minimumPaymentEstimate: 10000,
        manualPaymentAmount: 10000,
        scheduledPaymentAmount: 10000,
        actualPaymentAmount: null,
        monthlyInterestEstimate: 1000,
        principalPaymentEstimate: 9000,
        balanceAfterPaymentEstimate: -91000,
        liabilityShare: 0.3,
        priorityLabel: 'A',
        paymentAmountEstimated: false,
        billingConfirmed: true,
        paid: true,
        requiresAction: false,
      );
      const zeroScheduledActualRow = AssetLiabilityDebtRow(
        id: 'zero_scheduled_debt',
        name: '予定0実額ありカード',
        kind: AssetLiabilityAccountKind.creditCard,
        balance: -20000,
        paymentDay: 27,
        paymentSourceAccountId: 'wallet_cash',
        paymentSourceAccountName: '財布(現金)',
        paymentMethod: AssetLiabilityPaymentMethod.direct,
        paymentMethodLabel: '直接支払い',
        paymentMethodSettingSource:
            AssetLiabilityPaymentMethodSettingSource.builtInDefault,
        billingAccountId: null,
        billingAccountName: null,
        includedInBillingAccount: false,
        annualRate: 0.0,
        minimumPaymentEstimate: 0,
        manualPaymentAmount: 0,
        scheduledPaymentAmount: 0,
        actualPaymentAmount: 5000,
        monthlyInterestEstimate: 0,
        principalPaymentEstimate: 0,
        balanceAfterPaymentEstimate: -20000,
        liabilityShare: 0.2,
        priorityLabel: 'B',
        paymentAmountEstimated: false,
        billingConfirmed: true,
        paid: true,
        requiresAction: false,
      );
      const includedRow = AssetLiabilityDebtRow(
        id: 'included_sub',
        name: 'カード合算サブスク',
        kind: AssetLiabilityAccountKind.utility,
        balance: -3000,
        paymentDay: 5,
        paymentSourceAccountId: 'zero_scheduled_debt',
        paymentSourceAccountName: '予定0実額ありカード',
        paymentMethod: AssetLiabilityPaymentMethod.includedInBillingAccount,
        paymentMethodLabel: 'カード合算',
        paymentMethodSettingSource:
            AssetLiabilityPaymentMethodSettingSource.userConfigured,
        billingAccountId: 'zero_scheduled_debt',
        billingAccountName: '予定0実額ありカード',
        includedInBillingAccount: true,
        annualRate: 0.0,
        minimumPaymentEstimate: 3000,
        manualPaymentAmount: 3000,
        scheduledPaymentAmount: 3000,
        actualPaymentAmount: null,
        monthlyInterestEstimate: 0,
        principalPaymentEstimate: 3000,
        balanceAfterPaymentEstimate: 0,
        liabilityShare: 0.0,
        priorityLabel: 'B',
        paymentAmountEstimated: false,
        billingConfirmed: true,
        paid: true,
        requiresAction: false,
      );

      final items = AssetPaymentInconsistencyService.detect(
        debtRows: const <AssetLiabilityDebtRow>[
          nullDayPaidRow,
          pastDuePaidRow,
          zeroScheduledActualRow,
          includedRow,
        ],
        cashflowRows: const <AssetLiabilityCashflowRow>[],
        baseDate: DateTime(2026, 9, 10),
      );

      expect(items.length, 3);
      expect(items[0].accountId, 'null_day_debt');
      expect(items[0].paymentDay, isNull);
      expect(items[0].isPastDue, isFalse);
      expect(items[0].rule, AssetPaymentInconsistencyRule.paidWithoutActual);
      expect(items[1].accountId, 'past_due_debt');
      expect(items[1].isPastDue, isTrue);
      expect(
        items[1].rule,
        AssetPaymentInconsistencyRule.pastDuePaidWithoutActual,
      );
      expect(items[2].accountId, 'zero_scheduled_debt');
      expect(
        items[2].rule,
        AssetPaymentInconsistencyRule.zeroScheduledWithActual,
      );

      final summary = AssetPaymentInconsistencyService.summarize(items);
      expect(summary.totalCount, 3);
      expect(summary.r1Count, 2);
      expect(summary.r2Count, 1);
      expect(summary.r3Count, 1);
      expect(summary.hasInconsistencies, isTrue);
    });
  });
}
