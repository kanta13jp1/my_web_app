import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';

void main() {
  group('AssetLiabilityPlanningService.buildWorkbook', () {
    const service = AssetLiabilityPlanningService();

    final snapshot = <String, double>{
      '三井住友銀行大塚支店': 25677,
      '三井住友銀行CL': -481281,
      '三井住友銀行神田支店': 2645,
      '横浜銀行': -161437,
      'アコムカードローン': -699446,
      'アコムショッピング': -2234106,
      'モビット': -1553260,
      'じぶん銀行カードローン': -994562,
      'au': -32152,
      'auPayカード': -513770,
      'PayPayカード': -487324,
      'ファミペイカード': -97380,
      '三菱UFJ eスマート証券': 57155,
      '財布': 11000,
    };

    test('matches the Excel-style asset liability summary', () {
      final workbook = service.buildWorkbook(
        latestSnapshot: snapshot,
        baseDate: DateTime(2026, 5, 12),
      );

      expect(workbook.cashLikeTotal.round(), 39322);
      expect(workbook.securitiesTotal.round(), 57155);
      expect(workbook.positiveAssetTotal.round(), 96477);
      expect(workbook.liabilityTotal.round(), -7254718);
      expect(workbook.netWorth.round(), -7158241);
      expect(workbook.debtToAssetRatio, closeTo(75.1963, 0.001));
      expect(workbook.topFourDebtShare, closeTo(0.7556, 0.001));
    });

    test('groups liability balances by payment day', () {
      final workbook = service.buildWorkbook(
        latestSnapshot: snapshot,
        baseDate: DateTime(2026, 5, 12),
      );

      final riskByDay = {
        for (final risk in workbook.paymentDayRisks) risk.paymentDay: risk,
      };

      expect(riskByDay[8]?.balanceTotal.round(), -2933552);
      expect(riskByDay[10]?.balanceTotal.round(), -513770);
      expect(riskByDay[11]?.balanceTotal.round(), -32152);
      expect(riskByDay[15]?.balanceTotal.round(), -2195978);
      expect(riskByDay[27]?.balanceTotal.round(), -1579266);
      expect(riskByDay[8]?.isPast, isTrue);
      expect(riskByDay[15]?.isUpcoming, isTrue);
    });

    test('builds debt master rows with type, rate, and priority signals', () {
      final workbook = service.buildWorkbook(
        latestSnapshot: snapshot,
        baseDate: DateTime(2026, 5, 12),
      );

      final largest = workbook.debtMasterRows.first;
      expect(largest.name, 'アコムショッピング');
      expect(largest.kind, AssetLiabilityAccountKind.shoppingDebt);
      expect(largest.paymentDay, 8);
      expect(largest.liabilityShare, closeTo(0.308, 0.001));

      final topPriority = workbook.repaymentPriorityRows.first;
      expect(topPriority.name, anyOf('アコムカードローン', 'モビット'));
      expect(topPriority.annualRate, 0.18);
      expect(topPriority.priorityLabel, '最優先');
    });

    test('prefers manually entered monthly payment over the estimate', () {
      final baseline = service.buildWorkbook(
        latestSnapshot: snapshot,
        baseDate: DateTime(2026, 5, 12),
      );
      final baselineMobit = baseline.debtMasterRows.firstWhere(
        (row) => row.name == 'モビット',
      );

      final workbook = service.buildWorkbook(
        latestSnapshot: snapshot,
        baseDate: DateTime(2026, 5, 12),
        monthlyPaymentOverrides: const <String, double>{
          'モビット': 70000,
        },
      );
      final mobit = workbook.debtMasterRows.firstWhere(
        (row) => row.name == 'モビット',
      );

      expect(mobit.manualPaymentAmount, 70000);
      expect(mobit.scheduledPaymentAmount, 70000);
      expect(mobit.paymentAmountEstimated, isFalse);
      expect(
        workbook.monthlyScheduledPaymentTotal,
        closeTo(
          baseline.monthlyMinimumPaymentEstimateTotal -
              baselineMobit.minimumPaymentEstimate +
              70000,
          0.001,
        ),
      );
      expect(
        workbook.cashAfterScheduledPayments,
        closeTo(
          workbook.cashLikeTotal - workbook.monthlyScheduledPaymentTotal,
          0.001,
        ),
      );
    });

    test('uses the estimated minimum payment when manual input is absent', () {
      final workbook = service.buildWorkbook(
        latestSnapshot: snapshot,
        baseDate: DateTime(2026, 5, 12),
      );

      final auPay = workbook.debtMasterRows.firstWhere(
        (row) => row.name == 'auPayカード',
      );

      expect(auPay.manualPaymentAmount, isNull);
      expect(auPay.paymentAmountEstimated, isTrue);
      expect(
        auPay.scheduledPaymentAmount,
        closeTo(auPay.minimumPaymentEstimate, 0.001),
      );
      expect(workbook.manualPaymentCount, 0);
      expect(workbook.estimatedPaymentCount, workbook.debtMasterRows.length);
    });

    test('treats zero yen as a valid manually entered payment', () {
      final workbook = service.buildWorkbook(
        latestSnapshot: snapshot,
        baseDate: DateTime(2026, 5, 12),
        monthlyPaymentOverrides: const <String, double>{
          'PayPayカード': 0,
        },
      );

      final payPay = workbook.debtMasterRows.firstWhere(
        (row) => row.name == 'PayPayカード',
      );

      expect(payPay.manualPaymentAmount, 0);
      expect(payPay.scheduledPaymentAmount, 0);
      expect(payPay.paymentAmountEstimated, isFalse);
    });

    test('reflects manual and estimated sources in payment day risk', () {
      final workbook = service.buildWorkbook(
        latestSnapshot: snapshot,
        baseDate: DateTime(2026, 5, 12),
        monthlyPaymentOverrides: const <String, double>{
          'モビット': 70000,
        },
      );

      final risk15 = workbook.paymentDayRisks.firstWhere(
        (risk) => risk.paymentDay == 15,
      );
      final risk27 = workbook.paymentDayRisks.firstWhere(
        (risk) => risk.paymentDay == 27,
      );

      expect(risk15.hasManualPayments, isTrue);
      expect(risk15.hasEstimatedPayments, isTrue);
      expect(risk15.manualPaymentCount, 1);
      expect(risk15.estimatedPaymentCount, 2);
      expect(risk15.manualPaymentTotal, 70000);
      expect(
        risk15.scheduledPaymentTotal,
        greaterThan(risk15.minimumPaymentEstimateTotal),
      );

      expect(risk27.hasManualPayments, isFalse);
      expect(risk27.hasEstimatedPayments, isTrue);
    });

    test('reflects paid status in debt rows and cashflow rows', () {
      final workbook = service.buildWorkbook(
        latestSnapshot: <String, double>{
          '財布': 50000,
          'アコムカードローン': -100000,
          'auPayカード': -10000,
          'モビット': -20000,
        },
        baseDate: DateTime(2026, 5, 1),
        paidAccountNames: const <String>{
          'auPayカード',
        },
      );

      final auPay = workbook.debtMasterRows.firstWhere(
        (row) => row.name == 'auPayカード',
      );
      final auPayCashflow = workbook.cashflowRows.firstWhere(
        (row) => row.accountName == 'auPayカード',
      );

      expect(auPay.paid, isTrue);
      expect(auPayCashflow.paid, isTrue);
      expect(auPayCashflow.cashBeforePayment, auPayCashflow.cashAfterPayment);
      expect(
        workbook.monthlyUnpaidPaymentTotal,
        workbook.monthlyScheduledPaymentTotal - auPay.scheduledPaymentAmount,
      );
    });

    test('restores monthly state by stable id after display name changes', () {
      final workbook = service.buildWorkbook(
        latestSnapshot: <String, double>{
          '財布': 50000,
          'SMBCカードローン': -100000,
        },
        baseDate: DateTime(2026, 5, 1),
        monthlyPaymentOverrides: const <String, double>{
          'smbc_card_loan': 12345,
        },
        paidAccountNames: const <String>{
          'smbc_card_loan',
        },
      );

      final row = workbook.debtMasterRows.single;
      final cashflowRow = workbook.cashflowRows.single;

      expect(row.id, 'smbc_card_loan');
      expect(row.name, 'SMBCカードローン');
      expect(row.manualPaymentAmount, 12345);
      expect(row.paid, isTrue);
      expect(cashflowRow.accountId, 'smbc_card_loan');
      expect(cashflowRow.paid, isTrue);
    });

    test('marks unpaid payments due today or earlier as overdue', () {
      final workbook = service.buildWorkbook(
        latestSnapshot: <String, double>{
          '財布': 50000,
          'モビット': -100000,
          'PayPayカード': -10000,
        },
        baseDate: DateTime(2026, 5, 15),
        monthlyPaymentOverrides: const <String, double>{
          'mobit': 10000,
          'paypay_card': 5000,
        },
      );

      final mobit = workbook.cashflowRows.firstWhere(
        (row) => row.accountId == 'mobit',
      );
      final payPay = workbook.cashflowRows.firstWhere(
        (row) => row.accountId == 'paypay_card',
      );

      expect(mobit.overdue, isTrue);
      expect(payPay.overdue, isFalse);
      expect(workbook.hasOverduePayments, isTrue);
      expect(workbook.overdueCashflowRows, hasLength(1));
    });

    test('builds cashflow rows by payment day with risk levels', () {
      final workbook = service.buildWorkbook(
        latestSnapshot: <String, double>{
          '財布': 25000,
          'アコムカードローン': -100000,
          'auPayカード': -10000,
          'モビット': -100000,
        },
        baseDate: DateTime(2026, 5, 1),
        monthlyPaymentOverrides: const <String, double>{
          'アコムカードローン': 10000,
          'auPayカード': 8000,
          'モビット': 9000,
        },
      );

      expect(
        workbook.cashflowRows.map((row) => row.paymentDay).toList(),
        <int>[8, 10, 15],
      );
      expect(workbook.cashflowRows[0].cashAfterPayment, 15000);
      expect(
        workbook.cashflowRows[0].riskLevel,
        AssetLiabilityCashRiskLevel.watch,
      );
      expect(workbook.cashflowRows[1].cashAfterPayment, 7000);
      expect(
        workbook.cashflowRows[1].riskLevel,
        AssetLiabilityCashRiskLevel.caution,
      );
      expect(workbook.cashflowRows[2].cashAfterPayment, -2000);
      expect(
        workbook.cashflowRows[2].riskLevel,
        AssetLiabilityCashRiskLevel.short,
      );
    });

    test('reflects unreceived income plans in chronological cashflow', () {
      final workbook = service.buildWorkbook(
        latestSnapshot: <String, double>{
          'cash': 10000,
          'mobit': -100000,
        },
        baseDate: DateTime(2026, 5, 1),
        monthlyPaymentOverrides: const <String, double>{
          'mobit': 20000,
        },
        incomePlans: <AssetLiabilityIncomePlan>[
          AssetLiabilityIncomePlan(
            id: 'income_salary',
            date: DateTime(2026, 5, 14),
            name: 'Salary',
            amount: 15000,
            destinationAccountId: 'custom_cash',
            destinationAccountName: null,
            received: false,
          ),
        ],
      );

      expect(
        workbook.cashflowRows.map((row) => row.eventType).toList(),
        <AssetLiabilityCashflowEventType>[
          AssetLiabilityCashflowEventType.income,
          AssetLiabilityCashflowEventType.payment,
        ],
      );
      expect(workbook.cashflowRows.first.cashAfterPayment, 25000);
      expect(workbook.cashflowRows.last.cashAfterPayment, 5000);
      expect(workbook.monthlyUnreceivedIncomeTotal, 15000);
      expect(workbook.cashAfterScheduledPayments, 5000);
    });

    test('does not double count received income plans', () {
      final workbook = service.buildWorkbook(
        latestSnapshot: <String, double>{
          'cash': 10000,
          'mobit': -100000,
        },
        baseDate: DateTime(2026, 5, 1),
        monthlyPaymentOverrides: const <String, double>{
          'mobit': 20000,
        },
        incomePlans: <AssetLiabilityIncomePlan>[
          AssetLiabilityIncomePlan(
            id: 'income_received',
            date: DateTime(2026, 5, 14),
            name: 'Received salary',
            amount: 15000,
            destinationAccountId: 'custom_cash',
            destinationAccountName: null,
            received: true,
          ),
        ],
      );

      expect(workbook.monthlyUnreceivedIncomeTotal, 0);
      expect(workbook.cashflowRows.first.cashAfterPayment, 10000);
      expect(workbook.cashflowRows.last.cashAfterPayment, -10000);
      expect(workbook.cashAfterScheduledPayments, -10000);
    });

    test('calculates account-level cashflow and shortage warnings', () {
      final workbook = service.buildWorkbook(
        latestSnapshot: <String, double>{
          'cash': 50000,
          'bank': 10000,
          'mobit': -100000,
        },
        baseDate: DateTime(2026, 5, 1),
        monthlyPaymentOverrides: const <String, double>{
          'mobit': 20000,
        },
        paymentSourceAccountIds: const <String, String>{
          'mobit': 'custom_bank',
        },
        incomePlans: <AssetLiabilityIncomePlan>[
          AssetLiabilityIncomePlan(
            id: 'income_bank',
            date: DateTime(2026, 5, 10),
            name: 'Bank deposit',
            amount: 5000,
            destinationAccountId: 'custom_bank',
            destinationAccountName: null,
            received: false,
          ),
        ],
      );

      final bankSummary = workbook.accountCashflowSummaries.firstWhere(
        (summary) => summary.accountId == 'custom_bank',
      );

      expect(bankSummary.currentBalance, 10000);
      expect(bankSummary.upcomingPayments, 20000);
      expect(bankSummary.upcomingIncome, 5000);
      expect(bankSummary.projectedBalance, -5000);
      expect(workbook.hasAccountShortage, isTrue);
      expect(workbook.transferSuggestions.single.amount, 5000);
      expect(workbook.transferSuggestions.single.toAccountId, 'custom_bank');
    });

    test('applies default payment source to unset monthly items', () {
      final workbook = service.buildWorkbook(
        latestSnapshot: <String, double>{
          'cash': 50000,
          'bank': 10000,
          'mobit': -100000,
        },
        baseDate: DateTime(2026, 5, 1),
        monthlyPaymentOverrides: const <String, double>{
          'mobit': 20000,
        },
        defaultPaymentSourceAccountIds: const <String, String>{
          'mobit': 'custom_bank',
        },
      );

      final mobit = workbook.debtMasterRows.singleWhere(
        (row) => row.id == 'mobit',
      );
      final bankSummary = workbook.accountCashflowSummaries.firstWhere(
        (summary) => summary.accountId == 'custom_bank',
      );

      expect(mobit.paymentSourceAccountId, 'custom_bank');
      expect(bankSummary.upcomingPayments, 20000);
      expect(bankSummary.projectedBalance, -10000);
      expect(workbook.hasAccountShortage, isTrue);
    });

    test('keeps unassigned income out of account-level cashflow warnings', () {
      final workbook = service.buildWorkbook(
        latestSnapshot: <String, double>{
          'cash': 10000,
          'mobit': -100000,
        },
        baseDate: DateTime(2026, 5, 1),
        monthlyPaymentOverrides: const <String, double>{
          'mobit': 20000,
        },
        incomePlans: <AssetLiabilityIncomePlan>[
          AssetLiabilityIncomePlan(
            id: 'income_unassigned',
            date: DateTime(2026, 5, 10),
            name: 'Unassigned salary',
            amount: 15000,
            destinationAccountId: null,
            destinationAccountName: null,
            received: false,
          ),
        ],
      );

      final cashSummary = workbook.accountCashflowSummaries.firstWhere(
        (summary) => summary.accountId == 'custom_cash',
      );

      expect(workbook.monthlyUnreceivedIncomeTotal, 15000);
      expect(workbook.hasUnassignedDestinationIncomePlans, isTrue);
      expect(
        workbook.unassignedDestinationIncomePlans.single.name,
        'Unassigned salary',
      );
      expect(cashSummary.upcomingIncome, 0);
      expect(cashSummary.projectedBalance, 10000);
      expect(workbook.cashAfterScheduledPayments, 5000);
    });
  });
}
