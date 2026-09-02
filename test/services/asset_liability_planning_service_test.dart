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

    test('carries card usage policies into the workbook for insights', () {
      final changedAt = DateTime.utc(2026, 8, 29, 6, 18);
      final workbook = service.buildWorkbook(
        latestSnapshot: const <String, double>{
          'bank': 500000,
          'ファミペイ': -100000,
        },
        baseDate: DateTime(2026, 8, 29),
        cardUsagePolicies: <String, AssetCardUsagePolicy>{
          'famipay_card': AssetCardUsagePolicy(
            enforceOneShot: true,
            changedAt: changedAt,
            memo: '受付 ABC123',
          ),
        },
      );

      expect(workbook.cardUsagePolicies['famipay_card']!.enforceOneShot, true);
      expect(workbook.cardUsagePolicies['famipay_card']!.changedAt, changedAt);
      expect(workbook.cardUsagePolicies['famipay_card']!.memo, '受付 ABC123');
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
      expect(riskByDay.containsKey(11), isFalse);
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
        monthlyPaymentOverrides: const <String, double>{'モビット': 70000},
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
          baseline.monthlyScheduledPaymentTotal -
              baselineMobit.scheduledPaymentAmount +
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

    test('uses annual rate overrides for interest and priority signals', () {
      final workbook = service.buildWorkbook(
        latestSnapshot: snapshot,
        baseDate: DateTime(2026, 5, 12),
        annualRateOverrides: const <String, double>{'mobit': 0.12},
      );

      final mobit = workbook.debtMasterRows.firstWhere(
        (row) => row.name == 'モビット',
      );

      expect(mobit.annualRate, 0.12);
      expect(
        mobit.monthlyInterestEstimate,
        closeTo(mobit.balance.abs() * 0.12 / 12, 0.001),
      );
      expect(mobit.priorityLabel, isNotEmpty);
    });

    test('ignores annual rate overrides above the 20 percent block line', () {
      final workbook = service.buildWorkbook(
        latestSnapshot: snapshot,
        baseDate: DateTime(2026, 5, 12),
        annualRateOverrides: const <String, double>{'mobit': 0.205},
      );

      final mobit = workbook.debtMasterRows.firstWhere(
        (row) => row.name == 'モビット',
      );

      expect(mobit.annualRate, 0.18);
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
      expect(
        workbook.estimatedPaymentCount,
        workbook.debtMasterRows
            .where((row) => row.isDirectCashflowTarget)
            .length,
      );
    });

    test('exposes debt control review targets and payment split totals', () {
      final workbook = service.buildWorkbook(
        latestSnapshot: const <String, double>{'bank': 50000, 'PayPay': -20000},
        baseDate: DateTime(2026, 5, 1),
      );

      expect(workbook.billingConfirmationPendingRows.length, 1);
      expect(workbook.billingConfirmationPendingRows.single.id, 'paypay_card');
      expect(
        workbook.billingConfirmationPendingTotal,
        workbook.billingConfirmationPendingRows.single.scheduledPaymentAmount,
      );
      expect(workbook.paymentSourceMissingRows.length, 1);
      expect(workbook.paymentSourceMissingRows.single.id, 'paypay_card');
      expect(
        workbook.paymentSourceMissingTotal,
        workbook.paymentSourceMissingRows.single.scheduledPaymentAmount,
      );
      expect(
        workbook.monthlyScheduledPrincipalEstimateTotal +
            workbook.monthlyScheduledInterestEstimateTotal,
        closeTo(workbook.monthlyScheduledPaymentTotal, 0.001),
      );

      final billingConfirmed = service.buildWorkbook(
        latestSnapshot: const <String, double>{'bank': 50000, 'PayPay': -20000},
        baseDate: DateTime(2026, 5, 1),
        billingConfirmedAccountIds: const <String>{'paypay_card'},
      );

      expect(billingConfirmed.debtMasterRows.single.billingConfirmed, isTrue);
      expect(billingConfirmed.billingConfirmationPendingRows, isEmpty);
      expect(billingConfirmed.paymentSourceMissingRows.length, 1);

      final reviewed = service.buildWorkbook(
        latestSnapshot: const <String, double>{'bank': 50000, 'PayPay': -20000},
        baseDate: DateTime(2026, 5, 1),
        monthlyPaymentOverrides: const <String, double>{'paypay_card': 20000},
        paymentSourceAccountIds: const <String, String>{
          'paypay_card': 'custom_bank',
        },
      );

      expect(reviewed.billingConfirmationPendingRows, isEmpty);
      expect(reviewed.paymentSourceMissingRows, isEmpty);
    });

    test('drops paid rows from the payment source missing review', () {
      const snapshot = <String, double>{'bank': 50000, 'PayPay': -20000};
      const overrides = <String, double>{'paypay_card': 20000};

      final unpaid = service.buildWorkbook(
        latestSnapshot: snapshot,
        baseDate: DateTime(2026, 5, 1),
        monthlyPaymentOverrides: overrides,
      );

      // 原資未設定かつ未払いなので、警告対象として拾われる。
      expect(unpaid.paymentSourceMissingRows.single.id, 'paypay_card');
      expect(unpaid.hasPaymentSourceMissingRows, isTrue);
      expect(unpaid.paymentSourceMissingTotal, closeTo(20000, 0.001));

      final paid = service.buildWorkbook(
        latestSnapshot: snapshot,
        baseDate: DateTime(2026, 5, 1),
        monthlyPaymentOverrides: overrides,
        paidAccountNames: const <String>{'paypay_card'},
      );

      // 支払済みにしたら、原資を後付けしなくてもバナー・アラート・合計から消える。
      // 見込み残高は支払済み行を最初から控除しないので、警告する盲点も無い。
      expect(paid.debtMasterRows.single.paid, isTrue);
      expect(paid.paymentSourceMissingRows, isEmpty);
      expect(paid.hasPaymentSourceMissingRows, isFalse);
      expect(paid.paymentSourceMissingTotal, 0);
    });

    test('treats zero yen as a valid manually entered payment', () {
      final workbook = service.buildWorkbook(
        latestSnapshot: snapshot,
        baseDate: DateTime(2026, 5, 12),
        monthlyPaymentOverrides: const <String, double>{'PayPayカード': 0},
      );

      final payPay = workbook.debtMasterRows.firstWhere(
        (row) => row.name == 'PayPayカード',
      );

      expect(payPay.manualPaymentAmount, 0);
      expect(payPay.scheduledPaymentAmount, 0);
      expect(payPay.paymentAmountEstimated, isFalse);
      expect(payPay.requiresAction, isFalse);
    });

    test('separates zero-yen payments into review-only day groups', () {
      final workbook = service.buildWorkbook(
        latestSnapshot: const <String, double>{
          '財布': 50000,
          'じぶん銀行カードローン': -100000,
          'PayPayカード': -10000,
        },
        baseDate: DateTime(2026, 5, 29),
        monthlyPaymentOverrides: const <String, double>{
          AssetLiabilityPlanningService.jibunBankCardLoanAccountId: 0,
          'paypay_card': 5000,
        },
      );

      final jibun = workbook.debtMasterRows.firstWhere(
        (row) =>
            row.id == AssetLiabilityPlanningService.jibunBankCardLoanAccountId,
      );
      final payPay = workbook.debtMasterRows.firstWhere(
        (row) => row.id == 'paypay_card',
      );
      expect(jibun.minimumPaymentEstimate, greaterThan(0));
      expect(jibun.scheduledPaymentAmount, 0);
      expect(jibun.paid, isFalse);
      expect(jibun.requiresAction, isFalse);
      expect(payPay.requiresAction, isTrue);

      final day27 = workbook.paymentDayRisks
          .where((risk) => risk.paymentDay == 27)
          .toList(growable: false);
      expect(day27, hasLength(2));
      final actionRisk = day27.singleWhere((risk) => risk.requiresAction);
      final reviewOnlyRisk = day27.singleWhere((risk) => !risk.requiresAction);
      expect(actionRisk.accountNames, <String>['PayPayカード']);
      expect(reviewOnlyRisk.accountNames, <String>['じぶん銀行カードローン']);
      expect(reviewOnlyRisk.scheduledPaymentTotal, 0);

      final jibunCashflow = workbook.cashflowRows.firstWhere(
        (row) =>
            row.accountId ==
            AssetLiabilityPlanningService.jibunBankCardLoanAccountId,
      );
      final payPayCashflow = workbook.cashflowRows.firstWhere(
        (row) => row.accountId == 'paypay_card',
      );
      expect(jibunCashflow.overdue, isFalse);
      expect(payPayCashflow.overdue, isTrue);
      expect(
        workbook.overdueCashflowRows.map((row) => row.accountId),
        isNot(
          contains(AssetLiabilityPlanningService.jibunBankCardLoanAccountId),
        ),
      );
    });

    test('manual zero yen does not trigger card billing review alert', () {
      final workbook = service.buildWorkbook(
        latestSnapshot: snapshot,
        baseDate: DateTime(2026, 5, 12),
        monthlyPaymentOverrides: const <String, double>{'PayPayカード': 0},
      );

      expect(
        workbook.cardBillingReview.needsReviewItems.where(
          (item) => item.accountId == 'paypay_card',
        ),
        isEmpty,
      );
    });

    test('reflects manual and estimated sources in payment day risk', () {
      final workbook = service.buildWorkbook(
        latestSnapshot: snapshot,
        baseDate: DateTime(2026, 5, 12),
        monthlyPaymentOverrides: const <String, double>{'モビット': 70000},
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
        paidAccountNames: const <String>{'auPayカード'},
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

    test('excludes paid debts from payment day risks but keeps unpaid', () {
      // モビット・横浜銀行ともに支払日15。基準日を支払日経過後にし、
      // モビットだけ支払済みにする。
      final workbook = service.buildWorkbook(
        latestSnapshot: <String, double>{
          '財布': 50000,
          'モビット': -20000,
          '横浜銀行': -30000,
        },
        baseDate: DateTime(2026, 5, 20),
        paidAccountNames: const <String>{'モビット'},
      );

      final risk15 = workbook.paymentDayRisks
          .where((risk) => risk.paymentDay == 15)
          .toList();

      // 未払いの横浜銀行が残るのでリスク行自体は存在する。
      expect(risk15, hasLength(1));
      // 支払済みのモビットは期限超過リスク(AIナラティブ入力)から物理除外される。
      expect(risk15.single.accountNames, contains('横浜銀行'));
      expect(risk15.single.accountNames, isNot(contains('モビット')));
    });

    test('drops payment day risk entirely when every debt is paid', () {
      final workbook = service.buildWorkbook(
        latestSnapshot: <String, double>{'財布': 50000, 'モビット': -20000},
        baseDate: DateTime(2026, 5, 20),
        paidAccountNames: const <String>{'モビット'},
      );

      // その支払日の負債が全て支払済みなら、支払日リスク行は出ない。
      expect(
        workbook.paymentDayRisks.any((risk) => risk.paymentDay == 15),
        isFalse,
      );
    });

    test('uses actual paid amount for paid rows and keeps unpaid planned', () {
      final workbook = service.buildWorkbook(
        latestSnapshot: <String, double>{
          'cash': 50000,
          'aupay': -10000,
          'paypay': -20000,
        },
        baseDate: DateTime(2026, 5, 1),
        monthlyPaymentOverrides: const <String, double>{
          'aupay_card': 5000,
          'paypay_card': 8000,
        },
        actualPaymentAmounts: const <String, double>{
          'aupay_card': 6200,
          'paypay_card': 9000,
        },
        paymentDifferenceReasons: const <String, String>{
          'aupay_card': 'late fee',
        },
        paidAccountNames: const <String>{'aupay_card'},
      );

      final auPay = workbook.debtMasterRows.firstWhere(
        (row) => row.id == 'aupay_card',
      );
      final payPay = workbook.debtMasterRows.firstWhere(
        (row) => row.id == 'paypay_card',
      );
      final auPayCashflow = workbook.cashflowRows.firstWhere(
        (row) => row.accountId == 'aupay_card',
      );

      expect(auPay.scheduledPaymentAmount, 5000);
      expect(auPay.actualPaymentAmount, 6200);
      expect(auPay.effectivePaidPaymentAmount, 6200);
      expect(auPay.paymentDifferenceAmount, 1200);
      expect(auPay.paymentDifferenceReason, 'late fee');
      expect(auPayCashflow.actualPaymentAmount, 6200);
      expect(auPayCashflow.paymentDifferenceAmount, 1200);
      expect(payPay.paid, isFalse);
      expect(payPay.paymentDifferenceAmount, isNull);
      expect(workbook.monthlyActualPaymentTotal, 6200);
      expect(workbook.monthlyPaymentDifferenceTotal, 1200);
      expect(workbook.monthlyUnpaidPaymentTotal, 8000);
    });

    test(
      'treats au as auPay card-billed detail without direct subtraction',
      () {
        final workbook = service.buildWorkbook(
          latestSnapshot: <String, double>{
            'cash': 50000,
            'au': -32152,
            'auPayカード': -10000,
          },
          baseDate: DateTime(2026, 5, 1),
          monthlyPaymentOverrides: const <String, double>{
            AssetLiabilityPlanningService.auPayCardAccountId: 10000,
          },
        );

        final au = workbook.debtMasterRows.firstWhere(
          (row) => row.id == AssetLiabilityPlanningService.auAccountId,
        );
        final auPay = workbook.debtMasterRows.firstWhere(
          (row) => row.id == AssetLiabilityPlanningService.auPayCardAccountId,
        );
        final auCashflow = workbook.cashflowRows.firstWhere(
          (row) => row.accountId == AssetLiabilityPlanningService.auAccountId,
        );
        final auPayCashflow = workbook.cashflowRows.firstWhere(
          (row) =>
              row.accountId == AssetLiabilityPlanningService.auPayCardAccountId,
        );

        expect(
          au.paymentMethodLabel,
          AssetLiabilityPlanningService.auPayCardPaymentMethodLabel,
        );
        expect(
          au.billingAccountId,
          AssetLiabilityPlanningService.auPayCardAccountId,
        );
        expect(au.paymentMethod, AssetLiabilityPaymentMethod.includedInCard);
        expect(
          au.paymentMethodSettingSource,
          AssetLiabilityPaymentMethodSettingSource.builtInDefault,
        );
        expect(au.includedInBillingAccount, isTrue);
        expect(au.isDirectCashflowTarget, isFalse);
        expect(auPay.isDirectCashflowTarget, isTrue);
        expect(
          workbook.paymentDayRisks.any((risk) => risk.paymentDay == 11),
          isFalse,
        );
        expect(auCashflow.includedInBillingAccount, isTrue);
        expect(auCashflow.cashAfterPayment, auCashflow.cashBeforePayment);
        expect(
          auPayCashflow.cashAfterPayment,
          auPayCashflow.cashBeforePayment - auPayCashflow.paymentAmount,
        );
        expect(
          workbook.monthlyUnpaidPaymentTotal,
          auPay.scheduledPaymentAmount,
        );
        expect(workbook.cashAfterScheduledPayments, 40000);
      },
    );

    test('allows arbitrary payment items to be included in card billing', () {
      final workbook = service.buildWorkbook(
        latestSnapshot: <String, double>{
          'cash': 50000,
          'KDDI': -5764,
          'PayPay': -20000,
        },
        baseDate: DateTime(2026, 5, 1),
        monthlyPaymentOverrides: const <String, double>{
          AssetLiabilityPlanningService.kddiProviderAccountId: 5764,
          'paypay_card': 20000,
        },
        cardBillingAccountIds: const <String, String>{
          AssetLiabilityPlanningService.kddiProviderAccountId: 'paypay_card',
        },
      );

      final kddi = workbook.debtMasterRows.firstWhere(
        (row) => row.id == AssetLiabilityPlanningService.kddiProviderAccountId,
      );
      final payPay = workbook.debtMasterRows.firstWhere(
        (row) => row.id == 'paypay_card',
      );
      final kddiCashflow = workbook.cashflowRows.firstWhere(
        (row) =>
            row.accountId ==
            AssetLiabilityPlanningService.kddiProviderAccountId,
      );

      expect(kddi.paymentMethod, AssetLiabilityPaymentMethod.includedInCard);
      expect(kddi.billingAccountId, 'paypay_card');
      expect(
        kddi.paymentMethodSettingSource,
        AssetLiabilityPaymentMethodSettingSource.monthlyOverride,
      );
      expect(kddi.isDirectCashflowTarget, isFalse);
      expect(payPay.isDirectCashflowTarget, isTrue);
      expect(
        workbook.paymentDayRisks.any((risk) => risk.paymentDay == 25),
        isFalse,
      );
      expect(kddiCashflow.cashAfterPayment, kddiCashflow.cashBeforePayment);
      expect(workbook.monthlyUnpaidPaymentTotal, 20000);
      expect(workbook.cashAfterScheduledPayments, 30000);
    });

    test('applies default card billing settings before built-in defaults', () {
      final workbook = service.buildWorkbook(
        latestSnapshot: <String, double>{
          'cash': 50000,
          'KDDI': -5764,
          'PayPay': -20000,
        },
        baseDate: DateTime(2026, 5, 1),
        monthlyPaymentOverrides: const <String, double>{
          AssetLiabilityPlanningService.kddiProviderAccountId: 5764,
          'paypay_card': 20000,
        },
        defaultCardBillingAccountIds: const <String, String>{
          AssetLiabilityPlanningService.kddiProviderAccountId: 'paypay_card',
        },
      );

      final kddi = workbook.debtMasterRows.firstWhere(
        (row) => row.id == AssetLiabilityPlanningService.kddiProviderAccountId,
      );

      expect(kddi.paymentMethod, AssetLiabilityPaymentMethod.includedInCard);
      expect(kddi.billingAccountId, 'paypay_card');
      expect(
        kddi.paymentMethodSettingSource,
        AssetLiabilityPaymentMethodSettingSource.defaultSetting,
      );
      expect(kddi.isDirectCashflowTarget, isFalse);
      expect(workbook.monthlyUnpaidPaymentTotal, 20000);
    });

    test('monthly card billing overrides default card billing settings', () {
      final workbook = service.buildWorkbook(
        latestSnapshot: <String, double>{
          'cash': 50000,
          'KDDI': -5764,
          'PayPay': -20000,
        },
        baseDate: DateTime(2026, 5, 1),
        monthlyPaymentOverrides: const <String, double>{
          AssetLiabilityPlanningService.kddiProviderAccountId: 5764,
          'paypay_card': 20000,
        },
        defaultCardBillingAccountIds: const <String, String>{
          AssetLiabilityPlanningService.kddiProviderAccountId: 'paypay_card',
        },
        cardBillingAccountIds: const <String, String>{
          AssetLiabilityPlanningService.kddiProviderAccountId:
              AssetLiabilityPlanningService.directPaymentMethodId,
        },
      );

      final kddi = workbook.debtMasterRows.firstWhere(
        (row) => row.id == AssetLiabilityPlanningService.kddiProviderAccountId,
      );

      expect(kddi.paymentMethod, AssetLiabilityPaymentMethod.direct);
      expect(kddi.billingAccountId, isNull);
      expect(
        kddi.paymentMethodSettingSource,
        AssetLiabilityPaymentMethodSettingSource.monthlyOverride,
      );
      expect(kddi.isDirectCashflowTarget, isTrue);
      expect(workbook.monthlyUnpaidPaymentTotal, 25764);
    });

    test('builds monthly card billing review direct payment group', () {
      final workbook = service.buildWorkbook(
        latestSnapshot: <String, double>{
          'cash': 50000,
          'KDDI': -5764,
          'PayPay': -20000,
        },
        baseDate: DateTime(2026, 5, 1),
        monthlyPaymentOverrides: const <String, double>{
          AssetLiabilityPlanningService.kddiProviderAccountId: 5764,
          'paypay_card': 20000,
        },
      );

      final review = workbook.cardBillingReview;
      final directIds =
          review.directPaymentItems.map((item) => item.accountId).toSet();

      expect(
        directIds,
        contains(AssetLiabilityPlanningService.kddiProviderAccountId),
      );
      expect(directIds, contains('paypay_card'));
      expect(review.hasDoubleCountingRisk, isFalse);
      expect(workbook.monthlyUnpaidPaymentTotal, 25764);
    });

    test('groups card-billed review items by billing card', () {
      final workbook = service.buildWorkbook(
        latestSnapshot: <String, double>{
          'cash': 50000,
          'KDDI': -5764,
          'PayPay': -20000,
          'au': -32152,
          'auPayカード': -10000,
        },
        baseDate: DateTime(2026, 5, 1),
        monthlyPaymentOverrides: const <String, double>{
          AssetLiabilityPlanningService.kddiProviderAccountId: 5764,
          'paypay_card': 20000,
          AssetLiabilityPlanningService.auPayCardAccountId: 10000,
        },
        cardBillingAccountIds: const <String, String>{
          AssetLiabilityPlanningService.kddiProviderAccountId: 'paypay_card',
        },
      );

      final review = workbook.cardBillingReview;
      final auPayGroup = review.cardBillingGroups.firstWhere(
        (group) =>
            group.billingAccountId ==
            AssetLiabilityPlanningService.auPayCardAccountId,
      );
      final payPayGroup = review.cardBillingGroups.firstWhere(
        (group) => group.billingAccountId == 'paypay_card',
      );

      expect(
        auPayGroup.items.map((item) => item.accountId),
        contains(AssetLiabilityPlanningService.auAccountId),
      );
      expect(
        payPayGroup.items.map((item) => item.accountId),
        contains(AssetLiabilityPlanningService.kddiProviderAccountId),
      );
      expect(review.hasDoubleCountingRisk, isFalse);
    });

    test('allows billing into an acom shopping (shoppingDebt) host', () {
      final workbook = service.buildWorkbook(
        latestSnapshot: <String, double>{
          'cash': 50000,
          'KDDI': -5764,
          'アコムショッピング': -2234106,
        },
        baseDate: DateTime(2026, 5, 1),
        monthlyPaymentOverrides: const <String, double>{
          AssetLiabilityPlanningService.kddiProviderAccountId: 5764,
        },
        cardBillingAccountIds: const <String, String>{
          AssetLiabilityPlanningService.kddiProviderAccountId:
              AssetLiabilityPlanningService.acomShoppingAccountId,
        },
      );

      final review = workbook.cardBillingReview;
      final acomGroup = review.cardBillingGroups.firstWhere(
        (group) =>
            group.billingAccountId ==
            AssetLiabilityPlanningService.acomShoppingAccountId,
      );
      final kddi = acomGroup.items.firstWhere(
        (item) =>
            item.accountId ==
            AssetLiabilityPlanningService.kddiProviderAccountId,
      );

      expect(kddi.includedInBillingAccount, isTrue);
      expect(
        kddi.alerts,
        isNot(
          contains(
            AssetLiabilityPlanningService
                .cardBillingReviewRemovedBillingAccountAlert,
          ),
        ),
      );
    });

    test('isCardBillingHostKind accepts credit card and shopping debt', () {
      expect(
        AssetLiabilityPlanningService.isCardBillingHostKind(
          AssetLiabilityAccountKind.creditCard,
        ),
        isTrue,
      );
      expect(
        AssetLiabilityPlanningService.isCardBillingHostKind(
          AssetLiabilityAccountKind.shoppingDebt,
        ),
        isTrue,
      );
      expect(
        AssetLiabilityPlanningService.isCardBillingHostKind(
          AssetLiabilityAccountKind.deposit,
        ),
        isFalse,
      );
      expect(
        AssetLiabilityPlanningService.isCardBillingHostKind(
          AssetLiabilityAccountKind.cardLoan,
        ),
        isFalse,
      );
    });

    test('reconciles imported card statement totals with billed amount', () {
      final workbook = service.buildWorkbook(
        latestSnapshot: <String, double>{
          'cash': 50000,
          'KDDI': -5764,
          'Subscription': -14236,
          'PayPay': -20000,
        },
        baseDate: DateTime(2026, 5, 1),
        monthlyPaymentOverrides: const <String, double>{
          AssetLiabilityPlanningService.kddiProviderAccountId: 5764,
          'subscription': 14236,
          'paypay_card': 20000,
        },
        cardBillingAccountIds: const <String, String>{
          AssetLiabilityPlanningService.kddiProviderAccountId: 'paypay_card',
          'subscription': 'paypay_card',
        },
        cardStatementLines: const <AssetLiabilityCardStatementLine>[
          AssetLiabilityCardStatementLine(
            id: 'line_kddi',
            billingAccountId: 'paypay_card',
            billingAccountName: 'PayPay',
            postedAt: null,
            description: 'KDDI',
            amount: 5764,
          ),
          AssetLiabilityCardStatementLine(
            id: 'line_subscription',
            billingAccountId: 'paypay_card',
            billingAccountName: 'PayPay',
            postedAt: null,
            description: 'Subscription',
            amount: 14236,
          ),
        ],
      );

      final group = workbook.cardStatementReconciliation.groups.singleWhere(
        (group) => group.billingAccountId == 'paypay_card',
      );

      expect(group.statementLineTotal, 20000);
      expect(group.billedAmount, 20000);
      expect(group.statementDifference, 0);
      expect(group.hasStatementLines, isTrue);
      expect(
        group.alerts,
        isNot(
          contains(
            AssetLiabilityPlanningService.cardStatementAmountMismatchAlert,
          ),
        ),
      );
    });

    test('alerts when imported card statement total differs', () {
      final workbook = service.buildWorkbook(
        latestSnapshot: <String, double>{
          'cash': 50000,
          'KDDI': -5764,
          'PayPay': -20000,
        },
        baseDate: DateTime(2026, 5, 1),
        monthlyPaymentOverrides: const <String, double>{
          AssetLiabilityPlanningService.kddiProviderAccountId: 5764,
          'paypay_card': 20000,
        },
        cardBillingAccountIds: const <String, String>{
          AssetLiabilityPlanningService.kddiProviderAccountId: 'paypay_card',
        },
        cardStatementLines: const <AssetLiabilityCardStatementLine>[
          AssetLiabilityCardStatementLine(
            id: 'line_kddi',
            billingAccountId: 'paypay_card',
            billingAccountName: 'PayPay',
            postedAt: null,
            description: 'KDDI',
            amount: 5764,
          ),
        ],
      );

      final group = workbook.cardStatementReconciliation.needsReviewGroups
          .singleWhere((group) => group.billingAccountId == 'paypay_card');

      expect(group.statementDifference, -14236);
      expect(
        group.alerts,
        contains(
          AssetLiabilityPlanningService.cardStatementAmountMismatchAlert,
        ),
      );
      expect(workbook.cardBillingReview.hasDoubleCountingRisk, isFalse);
    });

    test('リボ払いカードは最低返済額へ明細の新規利用を上乗せし25日に返す', () {
      final workbook = service.buildWorkbook(
        latestSnapshot: <String, double>{'cash': 50000, 'auPayカード': -530163},
        baseDate: DateTime(2026, 6, 1),
        revolvingConfigs: const <String, AssetLiabilityRevolvingCreditConfig>{
          'aupay_card': AssetLiabilityRevolvingCreditConfig(
            monthlyAmount: 10000,
            newUsageAmount: 99999,
            creditLimit: 500000,
          ),
        },
        cardStatementLines: const <AssetLiabilityCardStatementLine>[
          AssetLiabilityCardStatementLine(
            id: 'line_lemon',
            billingAccountId: 'aupay_card',
            billingAccountName: 'auPayカード',
            postedAt: null,
            description: 'レモンガス',
            amount: 8066,
          ),
          AssetLiabilityCardStatementLine(
            id: 'line_au',
            billingAccountId: 'aupay_card',
            billingAccountName: 'auPayカード',
            postedAt: null,
            description: 'au電話',
            amount: 15116,
          ),
        ],
      );

      final debtRow = workbook.debtMasterRows.firstWhere(
        (row) => row.id == 'aupay_card',
      );
      // 手入力99999より取込明細を優先し、最低返済10000 + (8066 + 15116) = 33182。
      expect(debtRow.scheduledPaymentAmount, 33182);
      expect(debtRow.isRevolving, isTrue);
      expect(debtRow.revolvingBilling!.newUsageAmount, 23182);
      expect(debtRow.revolvingBilling!.existingBalanceAmount, 506981);
      expect(debtRow.revolvingBilling!.overLimitAmount, 0);
      expect(debtRow.paymentDay, 25);
      expect(debtRow.paymentAmountEstimated, isFalse);

      final group = workbook.cardStatementReconciliation.groups.singleWhere(
        (group) => group.billingAccountId == 'aupay_card',
      );
      expect(group.isRevolving, isTrue);
      expect(group.billedAmount, 33182);
      expect(group.statementLineTotal, 23182);
      expect(
        group.alerts,
        isNot(
          contains(
            AssetLiabilityPlanningService.cardStatementAmountMismatchAlert,
          ),
        ),
      );
      expect(group.revolvingBilling!.billedAmount, 33182);
    });

    test('リボ払いカードは明細未取込でも催促アラートを出さない', () {
      final workbook = service.buildWorkbook(
        latestSnapshot: <String, double>{
          'cash': 50000,
          'auPayカード': -530163,
          'au': -32152,
        },
        baseDate: DateTime(2026, 6, 1),
        revolvingConfigs: const <String, AssetLiabilityRevolvingCreditConfig>{
          'aupay_card': AssetLiabilityRevolvingCreditConfig(
            monthlyAmount: 10000,
            creditLimit: 500000,
          ),
        },
        cardBillingAccountIds: const <String, String>{'au': 'aupay_card'},
        // 明細(cardStatementLines)は未取込。
      );

      final group = workbook.cardStatementReconciliation.groups.singleWhere(
        (group) => group.billingAccountId == 'aupay_card',
      );
      expect(group.isRevolving, isTrue);
      // リボ払いは明細取込が不要なので「明細未取込」を催促しない。
      expect(
        group.alerts,
        isNot(
          contains(
            AssetLiabilityPlanningService.cardStatementMissingImportAlert,
          ),
        ),
      );
    });

    test('明細照合の差分に対して修正アクションを提案する', () {
      // 設定内訳(KDDI 5764) ≠ 請求額(20000) かつ明細未取込 →
      // 「内訳を修正する」「明細を取り込む」の両アクションが出る。
      final workbook = service.buildWorkbook(
        latestSnapshot: <String, double>{
          'cash': 50000,
          'KDDI': -5764,
          'PayPay': -20000,
        },
        baseDate: DateTime(2026, 5, 1),
        monthlyPaymentOverrides: const <String, double>{
          AssetLiabilityPlanningService.kddiProviderAccountId: 5764,
          'paypay_card': 20000,
        },
        cardBillingAccountIds: const <String, String>{
          AssetLiabilityPlanningService.kddiProviderAccountId: 'paypay_card',
        },
      );

      final group = workbook.cardStatementReconciliation.groups.singleWhere(
        (group) => group.billingAccountId == 'paypay_card',
      );
      expect(group.hasFixActions, isTrue);
      expect(group.hasConfiguredMismatchFix, isTrue);

      final importFix = group.fixActions.singleWhere(
        (action) =>
            action.kind ==
            AssetLiabilityCardStatementFixActionKind.importStatement,
      );
      expect(
        importFix.title,
        AssetLiabilityPlanningService.cardStatementFixImportLabel,
      );

      final breakdownFix = group.fixActions.singleWhere(
        (action) =>
            action.kind ==
            AssetLiabilityCardStatementFixActionKind.adjustConfiguredBreakdown,
      );
      expect(
        breakdownFix.title,
        AssetLiabilityPlanningService.cardStatementFixAdjustBreakdownLabel,
      );
      // 差分金額 = 設定内訳 5764 − 請求額 20000 = -14236 が案内文に入る。
      expect(breakdownFix.amount, 5764 - 20000);
      expect(breakdownFix.description, contains('-14,236円'));
    });

    test('取込明細と請求額の差分は取込明細確認アクションを提案する', () {
      final workbook = service.buildWorkbook(
        latestSnapshot: <String, double>{
          'cash': 50000,
          'KDDI': -5764,
          'PayPay': -20000,
        },
        baseDate: DateTime(2026, 5, 1),
        monthlyPaymentOverrides: const <String, double>{
          AssetLiabilityPlanningService.kddiProviderAccountId: 5764,
          'paypay_card': 20000,
        },
        cardBillingAccountIds: const <String, String>{
          AssetLiabilityPlanningService.kddiProviderAccountId: 'paypay_card',
        },
        cardStatementLines: const <AssetLiabilityCardStatementLine>[
          AssetLiabilityCardStatementLine(
            id: 'line_kddi',
            billingAccountId: 'paypay_card',
            billingAccountName: 'PayPay',
            postedAt: null,
            description: 'KDDI',
            amount: 5764,
          ),
        ],
      );

      final group = workbook.cardStatementReconciliation.groups.singleWhere(
        (group) => group.billingAccountId == 'paypay_card',
      );
      final reviewFix = group.fixActions.singleWhere(
        (action) =>
            action.kind ==
            AssetLiabilityCardStatementFixActionKind.reviewStatementLines,
      );
      expect(reviewFix.amount, 5764 - 20000);
      // 明細取込済みなので取り込みアクションは出ない。
      expect(
        group.fixActions.any(
          (action) =>
              action.kind ==
              AssetLiabilityCardStatementFixActionKind.importStatement,
        ),
        isFalse,
      );
    });

    test('請求先カード口座が無いホストには請求先再設定アクションのみ出す', () {
      final workbook = service.buildWorkbook(
        latestSnapshot: <String, double>{'cash': 50000, 'KDDI': -5764},
        baseDate: DateTime(2026, 5, 1),
        monthlyPaymentOverrides: const <String, double>{
          AssetLiabilityPlanningService.kddiProviderAccountId: 5764,
        },
        cardBillingAccountIds: const <String, String>{
          AssetLiabilityPlanningService.kddiProviderAccountId: 'missing_card',
        },
      );

      final group = workbook.cardStatementReconciliation.groups.singleWhere(
        (group) => group.billingAccountId == 'missing_card',
      );
      expect(
        group.alerts,
        contains(
          AssetLiabilityPlanningService.cardStatementBillingAccountMissingAlert,
        ),
      );
      final kinds =
          group.fixActions.map((action) => action.kind).toList(growable: false);
      expect(
        kinds,
        contains(AssetLiabilityCardStatementFixActionKind.assignBillingAccount),
      );
      // 請求額がプレースホルダ0のため、取り込み・内訳修正は提案しない。
      expect(
        kinds,
        isNot(
          contains(AssetLiabilityCardStatementFixActionKind.importStatement),
        ),
      );
      expect(
        kinds,
        isNot(
          contains(
            AssetLiabilityCardStatementFixActionKind.adjustConfiguredBreakdown,
          ),
        ),
      );
    });

    test('リボ払いカードには修正アクションを出さない', () {
      final workbook = service.buildWorkbook(
        latestSnapshot: <String, double>{
          'cash': 50000,
          'auPayカード': -530163,
          'au': -32152,
        },
        baseDate: DateTime(2026, 6, 1),
        revolvingConfigs: const <String, AssetLiabilityRevolvingCreditConfig>{
          'aupay_card': AssetLiabilityRevolvingCreditConfig(
            monthlyAmount: 10000,
            creditLimit: 500000,
          ),
        },
        cardBillingAccountIds: const <String, String>{'au': 'aupay_card'},
      );

      final group = workbook.cardStatementReconciliation.groups.singleWhere(
        (group) => group.billingAccountId == 'aupay_card',
      );
      // リボ払いは請求額 ≠ 内訳/明細合計が正常のため修正アクション対象外。
      expect(group.fixActions, isEmpty);
      expect(group.hasConfiguredMismatchFix, isFalse);
    });

    test(
      'marks monthly and default setting sources in card billing review',
      () {
        final workbook = service.buildWorkbook(
          latestSnapshot: <String, double>{
            'cash': 50000,
            'KDDI': -5764,
            'PayPay': -20000,
            'ファミペイカード': -3000,
          },
          baseDate: DateTime(2026, 5, 1),
          monthlyPaymentOverrides: const <String, double>{
            AssetLiabilityPlanningService.kddiProviderAccountId: 5764,
            'paypay_card': 20000,
            'famipay_card': 3000,
          },
          defaultCardBillingAccountIds: const <String, String>{
            AssetLiabilityPlanningService.kddiProviderAccountId: 'paypay_card',
          },
          cardBillingAccountIds: const <String, String>{
            'paypay_card': 'famipay_card',
          },
        );

        final items = [
          for (final group in workbook.cardBillingReview.cardBillingGroups)
            ...group.items,
        ];
        final kddi = items.firstWhere(
          (item) =>
              item.accountId ==
              AssetLiabilityPlanningService.kddiProviderAccountId,
        );
        final payPay = items.firstWhere(
          (item) => item.accountId == 'paypay_card',
        );

        expect(
          kddi.paymentMethodSettingSource,
          AssetLiabilityPaymentMethodSettingSource.defaultSetting,
        );
        expect(
          payPay.paymentMethodSettingSource,
          AssetLiabilityPaymentMethodSettingSource.monthlyOverride,
        );
      },
    );

    test('alerts when card billing target card is missing', () {
      final workbook = service.buildWorkbook(
        latestSnapshot: <String, double>{'cash': 50000, 'KDDI': -5764},
        baseDate: DateTime(2026, 5, 1),
        monthlyPaymentOverrides: const <String, double>{
          AssetLiabilityPlanningService.kddiProviderAccountId: 5764,
        },
        cardBillingAccountIds: const <String, String>{
          AssetLiabilityPlanningService.kddiProviderAccountId: 'missing_card',
        },
      );

      final item = workbook.cardBillingReview.needsReviewItems.firstWhere(
        (item) =>
            item.accountId ==
            AssetLiabilityPlanningService.kddiProviderAccountId,
      );

      expect(
        item.alerts,
        contains(
          AssetLiabilityPlanningService
              .cardBillingReviewRemovedBillingAccountAlert,
        ),
      );
      expect(workbook.cardBillingReview.hasDoubleCountingRisk, isFalse);
    });

    test('restores monthly state by stable id after display name changes', () {
      final workbook = service.buildWorkbook(
        latestSnapshot: <String, double>{'財布': 50000, 'SMBCカードローン': -100000},
        baseDate: DateTime(2026, 5, 1),
        monthlyPaymentOverrides: const <String, double>{
          'smbc_card_loan': 12345,
        },
        paidAccountNames: const <String>{'smbc_card_loan'},
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

      expect(workbook.cashflowRows.map((row) => row.paymentDay).toList(), <int>[
        8,
        10,
        15,
      ]);
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

    test('Anthropic Acom shopping charge is billed into acom (no cash)', () {
      const acomShoppingName =
          '\u30a2\u30b3\u30e0\u30b7\u30e7\u30c3\u30d4\u30f3\u30b0';
      final workbook = service.buildWorkbook(
        latestSnapshot: <String, double>{
          'cash': 100000,
          acomShoppingName: -200000,
        },
        baseDate: DateTime(2026, 5, 1),
        monthlyPaymentOverrides: const <String, double>{
          AssetLiabilityPlanningService.acomShoppingAccountId: 68000,
        },
      );

      final anthropicPayment = workbook.cashflowRows.singleWhere(
        (row) =>
            row.accountId ==
            AssetLiabilityPlanningService.anthropicAcomShoppingPaymentId,
      );

      expect(
        anthropicPayment.accountName,
        AssetLiabilityPlanningService.anthropicAcomShoppingPaymentName,
      );
      expect(anthropicPayment.paymentDay, 26);
      expect(
        anthropicPayment.paymentAmount,
        AssetLiabilityPlanningService.anthropicAcomShoppingPaymentAmount,
      );
      // \u30a2\u30b3\u30e0\u30b7\u30e7\u30c3\u30d4\u30f3\u30b0\u8acb\u6c42\u306b\u542b\u3080\u6271\u3044 (\u73fe\u91d1\u3067\u5225\u9014\u8fd4\u6e08\u3057\u306a\u3044)\u3002
      expect(anthropicPayment.includedInBillingAccount, isTrue);
      expect(anthropicPayment.isDirectCashflowTarget, isFalse);
      expect(
        anthropicPayment.billingAccountId,
        AssetLiabilityPlanningService.acomShoppingAccountId,
      );
      expect(
        anthropicPayment.paymentMethodLabel,
        '$acomShoppingName\u6255\u3044',
      );
      expect(workbook.cashflowRows.map((row) => row.paymentDay).toList(), <int>[
        8,
        26,
      ]);
      // \u73fe\u91d1\u652f\u51fa\u306f\u30a2\u30b3\u30e0\u6700\u4f4e\u8fd4\u6e08 (68000) \u306e\u307f\u3002Anthropic \u306e 40000 \u306f\u4e8c\u91cd\u8a08\u4e0a\u3057\u306a\u3044\u3002
      expect(workbook.monthlyScheduledPaymentTotal, 68000);
      expect(workbook.monthlyUnpaidPaymentTotal, 68000);
      expect(workbook.cashAfterScheduledPayments, 32000);
    });

    test('reflects unreceived income plans in chronological cashflow', () {
      final workbook = service.buildWorkbook(
        latestSnapshot: <String, double>{'cash': 10000, 'mobit': -100000},
        baseDate: DateTime(2026, 5, 1),
        monthlyPaymentOverrides: const <String, double>{'mobit': 20000},
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
        latestSnapshot: <String, double>{'cash': 10000, 'mobit': -100000},
        baseDate: DateTime(2026, 5, 1),
        monthlyPaymentOverrides: const <String, double>{'mobit': 20000},
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
        monthlyPaymentOverrides: const <String, double>{'mobit': 20000},
        paymentSourceAccountIds: const <String, String>{'mobit': 'custom_bank'},
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

    test('caps the transfer suggestion by the donor current balance', () {
      // ユーザー報告: 「じぶん銀行の残高より多い額を移動提案に出さないで」。
      // 移動元の projectedBalance は未着金の収入を含むため、それだけで決めると
      // 実際には無い残高の移動を提案してしまう。現在残高で上限を掛ける。
      final workbook = service.buildWorkbook(
        latestSnapshot: <String, double>{
          // 移動元: 今は 18,918 しかないが、給料 80,000 の入金予定がある。
          'cash': 18918,
          'bank': 10000,
          'mobit': -100000,
        },
        baseDate: DateTime(2026, 5, 1),
        monthlyPaymentOverrides: const <String, double>{'mobit': 60041},
        paymentSourceAccountIds: const <String, String>{'mobit': 'custom_bank'},
        incomePlans: <AssetLiabilityIncomePlan>[
          AssetLiabilityIncomePlan(
            id: 'income_cash_salary',
            date: DateTime(2026, 5, 25),
            name: 'Salary',
            amount: 80000,
            destinationAccountId: 'custom_cash',
            destinationAccountName: null,
            received: false,
          ),
        ],
      );

      final donor = workbook.accountCashflowSummaries.firstWhere(
        (summary) => summary.accountId == 'custom_cash',
      );
      final shortage = workbook.accountCashflowSummaries.firstWhere(
        (summary) => summary.accountId == 'custom_bank',
      );

      // 見込みは膨らむが、今動かせるのは現在残高まで。
      expect(donor.currentBalance, 18918);
      expect(donor.projectedBalance, 98918);
      expect(shortage.shortfall, 50041);

      final suggestion = workbook.transferSuggestions.single;
      expect(suggestion.fromAccountId, 'custom_cash');
      expect(suggestion.toAccountId, 'custom_bank');
      // 修正前は min(不足額, 見込み余剰) = 50,041 を提案していた (実行不能)。
      expect(suggestion.amount, 18918);
    });

    test('excludes already-reserved transfers from the movable amount', () {
      // 移動予約済み (未完了の移動タスク) の資金は既に他へ約束済みなので、
      // 同じ現金を二重に当て込まないよう移動可能額から差し引く。
      final workbook = service.buildWorkbook(
        latestSnapshot: <String, double>{
          'cash': 60000,
          'bank': 10000,
          'mobit': -100000,
        },
        baseDate: DateTime(2026, 5, 1),
        monthlyPaymentOverrides: const <String, double>{'mobit': 60041},
        paymentSourceAccountIds: const <String, String>{'mobit': 'custom_bank'},
        incomePlans: <AssetLiabilityIncomePlan>[
          // 未着金の収入。見込みは膨らむが今は動かせない。
          AssetLiabilityIncomePlan(
            id: 'income_cash_salary',
            date: DateTime(2026, 5, 25),
            name: 'Salary',
            amount: 100000,
            destinationAccountId: 'custom_cash',
            destinationAccountName: null,
            received: false,
          ),
        ],
        transferTasks: <AssetLiabilityTransferTask>[
          AssetLiabilityTransferTask(
            id: 'transfer_reserved',
            fromAccountId: 'custom_cash',
            fromAccountName: 'cash',
            toAccountId: 'custom_other',
            toAccountName: 'other',
            amount: 40000,
            dueDate: DateTime(2026, 5, 20),
          ),
        ],
      );

      final donor = workbook.accountCashflowSummaries.firstWhere(
        (summary) => summary.accountId == 'custom_cash',
      );
      expect(donor.currentBalance, 60000);
      expect(donor.pendingTransferOut, 40000);
      // 見込みは 60,000 + 100,000(未着金) - 40,000(予約) = 120,000 と潤沢。
      expect(donor.projectedBalance, 120000);

      // だが今動かせるのは 60,000 - 40,000(予約済み) = 20,000 まで。
      // 見込みだけで判断すると不足額 50,041 を提案してしまう。
      final suggestion = workbook.transferSuggestions.single;
      expect(suggestion.fromAccountId, 'custom_cash');
      expect(suggestion.amount, 20000);
    });

    test('applies pending transfer tasks to account-level cashflow', () {
      final workbook = service.buildWorkbook(
        latestSnapshot: <String, double>{
          'cash': 50000,
          'bank': 10000,
          'mobit': -100000,
        },
        baseDate: DateTime(2026, 5, 1),
        monthlyPaymentOverrides: const <String, double>{'mobit': 20000},
        paymentSourceAccountIds: const <String, String>{'mobit': 'custom_bank'},
        transferTasks: <AssetLiabilityTransferTask>[
          AssetLiabilityTransferTask(
            id: 'transfer_bank_topup',
            fromAccountId: 'custom_cash',
            fromAccountName: 'cash',
            toAccountId: 'custom_bank',
            toAccountName: 'bank',
            amount: 10000,
            dueDate: DateTime(2026, 5, 8),
          ),
        ],
      );

      final cashSummary = workbook.accountCashflowSummaries.firstWhere(
        (summary) => summary.accountId == 'custom_cash',
      );
      final bankSummary = workbook.accountCashflowSummaries.firstWhere(
        (summary) => summary.accountId == 'custom_bank',
      );

      expect(cashSummary.pendingTransferOut, 10000);
      expect(cashSummary.projectedBalance, 40000);
      expect(bankSummary.pendingTransferIn, 10000);
      expect(bankSummary.projectedBalance, 0);
      expect(workbook.transferSuggestions, isEmpty);
    });

    test('excludes canceled transfer tasks from account-level cashflow', () {
      final workbook = service.buildWorkbook(
        latestSnapshot: <String, double>{
          'cash': 50000,
          'bank': 10000,
          'mobit': -100000,
        },
        baseDate: DateTime(2026, 5, 1),
        monthlyPaymentOverrides: const <String, double>{'mobit': 20000},
        paymentSourceAccountIds: const <String, String>{'mobit': 'custom_bank'},
        transferTasks: <AssetLiabilityTransferTask>[
          AssetLiabilityTransferTask(
            id: 'transfer_cancelled',
            fromAccountId: 'custom_cash',
            fromAccountName: 'cash',
            toAccountId: 'custom_bank',
            toAccountName: 'bank',
            amount: 10000,
            dueDate: DateTime(2026, 5, 8),
            canceled: true,
            canceledAt: DateTime(2026, 5, 7, 21),
            cancellationReason: 'Paid from another account.',
          ),
        ],
      );

      final cashSummary = workbook.accountCashflowSummaries.firstWhere(
        (summary) => summary.accountId == 'custom_cash',
      );
      final bankSummary = workbook.accountCashflowSummaries.firstWhere(
        (summary) => summary.accountId == 'custom_bank',
      );
      final task = workbook.transferTasks.single;

      expect(task.canceled, isTrue);
      expect(task.cancellationReason, 'Paid from another account.');
      expect(cashSummary.pendingTransferOut, 0);
      expect(bankSummary.pendingTransferIn, 0);
      expect(bankSummary.projectedBalance, -10000);
    });

    test('no longer injects a hardcoded auPay funding transfer', () {
      // The old code auto-injected a fixed 80,000 transfer (SMBC Otsuka ->
      // Jibun bank) on every build. It was unrelated to any shortfall and,
      // when the salary lands in Jibun bank, double-counted (income + transfer
      // -in) and drained SMBC by 80,000, creating a phantom shortfall and a
      // reverse suggestion. It is removed; funding is now handled by the
      // shortfall-capped dynamic suggestions. With no user transfer task there
      // must be no transfer and no phantom transfer in/out.
      const smbcOtsukaName =
          '\u4e09\u4e95\u4f4f\u53cb\u9280\u884c\u5927\u585a\u652f\u5e97';
      const jibunBankName = '\u3058\u3076\u3093\u9280\u884c';
      const auPayCardName = 'auPay\u30ab\u30fc\u30c9';
      final workbook = service.buildWorkbook(
        latestSnapshot: const <String, double>{
          smbcOtsukaName: 200000,
          jibunBankName: 10000,
          auPayCardName: -80000,
        },
        baseDate: DateTime(2026, 5, 1),
        monthlyPaymentOverrides: const <String, double>{
          AssetLiabilityPlanningService.auPayCardAccountId: 80000,
        },
        paymentSourceAccountIds: const <String, String>{
          AssetLiabilityPlanningService.auPayCardAccountId:
              AssetLiabilityPlanningService.jibunBankAccountId,
        },
      );

      final smbcSummary = workbook.accountCashflowSummaries.singleWhere(
        (summary) =>
            summary.accountId ==
            AssetLiabilityPlanningService.smbcOtsukaBranchAccountId,
      );
      final jibunSummary = workbook.accountCashflowSummaries.singleWhere(
        (summary) =>
            summary.accountId ==
            AssetLiabilityPlanningService.jibunBankAccountId,
      );

      // No hardcoded built-in transfer task exists anymore.
      expect(
        workbook.transferTasks.where(
          (task) =>
              task.id ==
              AssetLiabilityPlanningService.auPayCardFundingTransferTaskId,
        ),
        isEmpty,
      );
      // And no phantom transfer in/out is applied to the accounts.
      expect(smbcSummary.pendingTransferOut, 0);
      expect(jibunSummary.pendingTransferIn, 0);
      // SMBC keeps its full projected balance (no 80,000 drain).
      expect(smbcSummary.projectedBalance, 200000);
    });

    test('does not double count completed transfer tasks', () {
      final workbook = service.buildWorkbook(
        latestSnapshot: <String, double>{
          'cash': 50000,
          'bank': 10000,
          'mobit': -100000,
        },
        baseDate: DateTime(2026, 5, 1),
        monthlyPaymentOverrides: const <String, double>{'mobit': 20000},
        paymentSourceAccountIds: const <String, String>{'mobit': 'custom_bank'},
        transferTasks: <AssetLiabilityTransferTask>[
          AssetLiabilityTransferTask(
            id: 'transfer_done',
            fromAccountId: 'custom_cash',
            fromAccountName: 'cash',
            toAccountId: 'custom_bank',
            toAccountName: 'bank',
            amount: 10000,
            dueDate: DateTime(2026, 5, 8),
            completed: true,
            completedAt: DateTime(2026, 5, 8, 9),
          ),
        ],
      );

      final bankSummary = workbook.accountCashflowSummaries.firstWhere(
        (summary) => summary.accountId == 'custom_bank',
      );

      expect(bankSummary.pendingTransferIn, 0);
      expect(bankSummary.projectedBalance, -10000);
      expect(workbook.transferSuggestions.single.amount, 10000);
    });

    test('applies default payment source to unset monthly items', () {
      final workbook = service.buildWorkbook(
        latestSnapshot: <String, double>{
          'cash': 50000,
          'bank': 10000,
          'mobit': -100000,
        },
        baseDate: DateTime(2026, 5, 1),
        monthlyPaymentOverrides: const <String, double>{'mobit': 20000},
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
        latestSnapshot: <String, double>{'cash': 10000, 'mobit': -100000},
        baseDate: DateTime(2026, 5, 1),
        monthlyPaymentOverrides: const <String, double>{'mobit': 20000},
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

    test('adds KDDI provider and rent as separate fixed payments', () {
      final workbook = service.buildWorkbook(
        latestSnapshot: <String, double>{'cash': 50000, 'au': -32152},
        baseDate: DateTime(2026, 5, 1),
        defaultPaymentSourceAccountIds: const <String, String>{
          AssetLiabilityPlanningService.kddiProviderAccountId: 'custom_cash',
        },
        includeDefaultFixedPayments: true,
      );

      final au = workbook.debtMasterRows.firstWhere((row) => row.id == 'au');
      final kddi = workbook.debtMasterRows.firstWhere(
        (row) => row.id == AssetLiabilityPlanningService.kddiProviderAccountId,
      );
      final rent = workbook.debtMasterRows.firstWhere(
        (row) => row.id == AssetLiabilityPlanningService.rentAccountId,
      );
      final gas = workbook.debtMasterRows.firstWhere(
        (row) => row.id == AssetLiabilityPlanningService.gasBillAccountId,
      );
      final kddiCashflow = workbook.cashflowRows.firstWhere(
        (row) =>
            row.accountId ==
            AssetLiabilityPlanningService.kddiProviderAccountId,
      );

      expect(au.name, 'au');
      expect(au.paymentDay, 11);
      expect(
        au.paymentMethodLabel,
        AssetLiabilityPlanningService.auPayCardPaymentMethodLabel,
      );
      expect(
        au.billingAccountId,
        AssetLiabilityPlanningService.auPayCardAccountId,
      );
      expect(au.includedInBillingAccount, isTrue);
      expect(au.isDirectCashflowTarget, isFalse);
      expect(kddi.name, AssetLiabilityPlanningService.kddiProviderAccountName);
      expect(kddi.kind, AssetLiabilityAccountKind.utility);
      expect(kddi.paymentDay, 25);
      expect(kddi.paymentMethod, AssetLiabilityPaymentMethod.direct);
      expect(kddi.manualPaymentAmount, 5764);
      expect(kddi.paymentAmountEstimated, isFalse);
      expect(
        kddi.scheduledPaymentAmount,
        AssetLiabilityPlanningService.kddiProviderMonthlyPaymentAmount,
      );
      expect(kddi.paymentSourceAccountId, 'custom_cash');
      expect(kddi.paymentSourceAccountName, 'cash');
      expect(kddiCashflow.paymentDay, 25);
      expect(
        kddiCashflow.paymentAmount,
        AssetLiabilityPlanningService.kddiProviderMonthlyPaymentAmount,
      );
      expect(kddiCashflow.paid, isFalse);
      expect(rent.name, AssetLiabilityPlanningService.rentAccountName);
      expect(rent.paymentDay, 25);
      expect(rent.scheduledPaymentAmount, 63000);
      expect(rent.isDirectCashflowTarget, isTrue);
      expect(
        kddiCashflow.cashAfterPayment,
        closeTo(
          kddiCashflow.cashBeforePayment -
              AssetLiabilityPlanningService.kddiProviderMonthlyPaymentAmount,
          0.001,
        ),
      );
      expect(
        workbook.monthlyUnpaidPaymentTotal,
        closeTo(
          kddi.scheduledPaymentAmount +
              rent.scheduledPaymentAmount +
              gas.scheduledPaymentAmount,
          0.001,
        ),
      );
    });

    test('adds the bimonthly water bill only on even months', () {
      final june = service.buildWorkbook(
        latestSnapshot: const <String, double>{'三井住友銀行大塚支店': 63539},
        baseDate: DateTime(2026, 6, 14),
        includeDefaultFixedPayments: true,
      );
      final water = june.debtMasterRows.firstWhere(
        (row) => row.id == AssetLiabilityPlanningService.waterBillAccountId,
      );
      expect(water.name, AssetLiabilityPlanningService.waterBillAccountName);
      expect(water.kind, AssetLiabilityAccountKind.utility);
      expect(water.paymentDay, 22);
      expect(water.scheduledPaymentAmount, 2400);
      expect(
        water.paymentSourceAccountId,
        AssetLiabilityPlanningService.smbcOtsukaBranchAccountId,
      );

      // 奇数月(7月)は水道代を計上しない。
      final july = service.buildWorkbook(
        latestSnapshot: const <String, double>{'三井住友銀行大塚支店': 63539},
        baseDate: DateTime(2026, 7, 14),
        includeDefaultFixedPayments: true,
      );
      expect(
        july.debtMasterRows.any(
          (row) => row.id == AssetLiabilityPlanningService.waterBillAccountId,
        ),
        isFalse,
      );
    });

    test('adds the monthly gas bill every month including odd months', () {
      AssetLiabilityDebtRow gasRowFor(int month) {
        final workbook = service.buildWorkbook(
          latestSnapshot: const <String, double>{'三井住友銀行大塚支店': 63539},
          baseDate: DateTime(2026, month, 14),
          includeDefaultFixedPayments: true,
        );
        return workbook.debtMasterRows.firstWhere(
          (row) => row.id == AssetLiabilityPlanningService.gasBillAccountId,
        );
      }

      // 偶数月(6月)・奇数月(7月)いずれもガス代を計上する。
      for (final month in const <int>[6, 7]) {
        final gas = gasRowFor(month);
        expect(gas.name, AssetLiabilityPlanningService.gasBillAccountName);
        expect(gas.kind, AssetLiabilityAccountKind.utility);
        expect(gas.paymentDay, 12);
        expect(gas.scheduledPaymentAmount, 4500);
        expect(
          gas.paymentSourceAccountId,
          AssetLiabilityPlanningService.smbcOtsukaBranchAccountId,
        );
      }
    });

    test('lets a manual override replace the default monthly gas bill', () {
      final workbook = service.buildWorkbook(
        latestSnapshot: const <String, double>{'三井住友銀行大塚支店': 63539},
        baseDate: DateTime(2026, 7, 14),
        monthlyPaymentOverrides: const <String, double>{
          AssetLiabilityPlanningService.gasBillAccountId: 5800,
        },
        includeDefaultFixedPayments: true,
      );
      final gas = workbook.debtMasterRows.firstWhere(
        (row) => row.id == AssetLiabilityPlanningService.gasBillAccountId,
      );
      expect(gas.scheduledPaymentAmount, 5800);
    });

    test('honors a name-keyed override for a default fixed cost', () {
      // 名称キー (口座ID ではなく口座名) の今月上書きでも既定額で shadow せず
      // ユーザー額を採用する。データ駆動化後も両キーガードを保つ回帰ピン。
      final workbook = service.buildWorkbook(
        latestSnapshot: const <String, double>{'メインバンク': 200000},
        baseDate: DateTime(2026, 6, 14),
        monthlyPaymentOverrides: const <String, double>{
          AssetLiabilityPlanningService.rentAccountName: 70000,
        },
        includeDefaultFixedPayments: true,
      );
      final rent = workbook.debtMasterRows.firstWhere(
        (row) => row.id == AssetLiabilityPlanningService.rentAccountId,
      );
      expect(rent.scheduledPaymentAmount, 70000);
      expect(rent.paymentAmountEstimated, isFalse);
    });

    test(
      'positive-balance accounts sharing a substring do not suppress defaults',
      () {
        // 「家賃保証金」「KDDIポイント」「ガスト」は名前に家賃/kddi/ガスを含むが
        // 資産(正残高)であり、既定固定費(家賃/KDDI/ガス)を抑止してはならない。
        final workbook = service.buildWorkbook(
          latestSnapshot: const <String, double>{
            'メインバンク': 200000,
            '家賃保証金': 500000,
            'KDDIポイント': 1200,
            'ガスト': 3000,
          },
          baseDate: DateTime(2026, 6, 14),
          includeDefaultFixedPayments: true,
        );
        bool hasDefault(String id) =>
            workbook.debtMasterRows.any((row) => row.id == id);
        expect(hasDefault(AssetLiabilityPlanningService.rentAccountId), isTrue);
        expect(
          hasDefault(AssetLiabilityPlanningService.kddiProviderAccountId),
          isTrue,
        );
        expect(
          hasDefault(AssetLiabilityPlanningService.gasBillAccountId),
          isTrue,
        );
      },
    );

    test(
      'a real liability sharing the rent id still suppresses the default rent',
      () {
        // ユーザーが実際の家賃を負債として登録している場合は二重計上せず、
        // 既定63,000円ではなくユーザーの実額を優先する。
        final workbook = service.buildWorkbook(
          latestSnapshot: const <String, double>{
            'メインバンク': 200000,
            '家賃': -58000,
          },
          baseDate: DateTime(2026, 6, 14),
          includeDefaultFixedPayments: true,
        );
        final rentRows = workbook.debtMasterRows
            .where(
              (row) => row.id == AssetLiabilityPlanningService.rentAccountId,
            )
            .toList();
        expect(rentRows.length, 1);
        expect(rentRows.first.balance, -58000);
      },
    );

    test('treats paid KDDI provider payment as reflected in cashflow', () {
      final workbook = service.buildWorkbook(
        latestSnapshot: <String, double>{'cash': 50000, 'au': -32152},
        baseDate: DateTime(2026, 5, 1),
        paidAccountNames: const <String>{
          AssetLiabilityPlanningService.kddiProviderAccountId,
        },
        includeDefaultFixedPayments: true,
      );

      final au = workbook.debtMasterRows.firstWhere((row) => row.id == 'au');
      final kddi = workbook.debtMasterRows.firstWhere(
        (row) => row.id == AssetLiabilityPlanningService.kddiProviderAccountId,
      );
      final rent = workbook.debtMasterRows.firstWhere(
        (row) => row.id == AssetLiabilityPlanningService.rentAccountId,
      );
      final gas = workbook.debtMasterRows.firstWhere(
        (row) => row.id == AssetLiabilityPlanningService.gasBillAccountId,
      );
      final kddiCashflow = workbook.cashflowRows.firstWhere(
        (row) =>
            row.accountId ==
            AssetLiabilityPlanningService.kddiProviderAccountId,
      );

      expect(au.includedInBillingAccount, isTrue);
      expect(kddi.paid, isTrue);
      expect(kddiCashflow.paid, isTrue);
      expect(kddiCashflow.cashBeforePayment, kddiCashflow.cashAfterPayment);
      expect(
        workbook.monthlyUnpaidPaymentTotal,
        closeTo(
          rent.scheduledPaymentAmount + gas.scheduledPaymentAmount,
          0.001,
        ),
      );
    });

    test('applies manual payment day override to unknown cards', () {
      final workbook = service.buildWorkbook(
        latestSnapshot: const <String, double>{
          'bank': 50000,
          'ファミマカード': -25000,
        },
        baseDate: DateTime(2026, 6, 1),
        paymentDayOverrides: const <String, int>{'ファミマカード': 27},
      );

      final row = workbook.debtMasterRows.firstWhere(
        (row) => row.name == 'ファミマカード',
      );
      expect(row.paymentDay, 27);
      expect(
        workbook.cashflowRows.any(
          (cashflow) =>
              cashflow.accountId == row.id && cashflow.paymentDate.day == 27,
        ),
        isTrue,
      );
    });

    test('manual payment day override replaces the built-in default', () {
      final workbook = service.buildWorkbook(
        latestSnapshot: const <String, double>{
          'bank': 50000,
          'PayPayカード': -30000,
        },
        baseDate: DateTime(2026, 6, 1),
        paymentDayOverrides: const <String, int>{'paypay_card': 15},
      );

      final row = workbook.debtMasterRows.firstWhere(
        (row) => row.id == 'paypay_card',
      );
      expect(row.paymentDay, 15);
    });

    test('ignores out-of-range payment day overrides', () {
      final workbook = service.buildWorkbook(
        latestSnapshot: const <String, double>{
          'bank': 50000,
          'ファミマカード': -25000,
        },
        baseDate: DateTime(2026, 6, 1),
        paymentDayOverrides: const <String, int>{'ファミマカード': 45},
      );

      final row = workbook.debtMasterRows.firstWhere(
        (row) => row.name == 'ファミマカード',
      );
      expect(row.paymentDay, isNull);
    });

    test('marks full-payment fixed costs on debt rows', () {
      final workbook = service.buildWorkbook(
        latestSnapshot: const <String, double>{'cash': 50000, 'モビット': -100000},
        baseDate: DateTime(2026, 5, 12),
        includeDefaultFixedPayments: true,
      );

      final rent = workbook.debtMasterRows.firstWhere(
        (row) => row.id == AssetLiabilityPlanningService.rentAccountId,
      );
      final kddi = workbook.debtMasterRows.firstWhere(
        (row) => row.id == AssetLiabilityPlanningService.kddiProviderAccountId,
      );
      final mobit = workbook.debtMasterRows.firstWhere(
        (row) => row.id == 'mobit',
      );

      expect(rent.fullPaymentEstimate, isTrue);
      expect(kddi.fullPaymentEstimate, isTrue);
      expect(mobit.fullPaymentEstimate, isFalse);
    });
  });

  group('AssetLiabilityPlanningService.buildWorkbook (salary cycle)', () {
    const service = AssetLiabilityPlanningService();
    final snapshot = <String, double>{
      '三井住友銀行大塚支店': 25677,
      'アコムショッピング': -2234106, // 支払日 8 / 特別行は 26
      'モビット': -1553260, // 支払日 15 (直接対象)
      '横浜銀行': -161437,
    };

    test(
        'payment day >= salaryDay lands in the first cycle month, < in the '
        'second', () {
      final workbook = service.buildWorkbook(
        latestSnapshot: snapshot,
        baseDate: DateTime(2026, 6, 26), // サイクル 6/25〜7/24
        salaryDay: 25,
      );
      final payments =
          workbook.cashflowRows.where((row) => row.isPayment).toList();
      expect(payments, isNotEmpty);
      for (final row in payments) {
        final day = row.paymentDay;
        expect(row.paymentDate.year, 2026);
        if (day >= 25) {
          expect(row.paymentDate.month, 6, reason: '${row.accountName} d=$day');
        } else {
          expect(row.paymentDate.month, 7, reason: '${row.accountName} d=$day');
        }
      }
    });

    test(
        'a pre-salaryDay payment is overdue under calendar but not under '
        'the salary cycle (払ったのに未払い 逆戻りの根治)', () {
      final base = DateTime(2026, 6, 26);
      final calendar = service.buildWorkbook(
        latestSnapshot: snapshot,
        baseDate: base,
      );
      final cycle = service.buildWorkbook(
        latestSnapshot: snapshot,
        baseDate: base,
        salaryDay: 25,
      );
      final calRows = calendar.cashflowRows
          .where(
            (row) =>
                row.isPayment &&
                row.paymentDay < 25 &&
                row.isDirectCashflowTarget &&
                !row.paid,
          )
          .toList();
      expect(calRows, isNotEmpty);
      final calRow = calRows.first;
      final cycRow = cycle.cashflowRows.firstWhere(
        (row) => row.accountId == calRow.accountId,
      );

      // 暦月: 当月(6月)の支払日 <= 6/26 → 期限超過。
      expect(calRow.paymentDate.month, 6);
      expect(calRow.overdue, isTrue);
      // サイクル: 第2暦月(7月)→ 6/26 より後 → 期限超過でない。
      expect(cycRow.paymentDate.month, 7);
      expect(cycRow.overdue, isFalse);
    });

    test('without salaryDay, payment dates stay in the calendar month', () {
      final workbook = service.buildWorkbook(
        latestSnapshot: snapshot,
        baseDate: DateTime(2026, 6, 26),
      );
      for (final row in workbook.cashflowRows.where((row) => row.isPayment)) {
        expect(row.paymentDate.month, 6, reason: row.accountName);
      }
    });

    test('bimonthly water bill applies based on its cycle calendar month', () {
      // 水道代(22日/偶数月)。salaryDay 25, baseDate 6/10 → サイクル 5/25〜6/24、
      // 22<25 → 第2暦月=6月(偶数)→ 計上。
      final included = service.buildWorkbook(
        latestSnapshot: snapshot,
        baseDate: DateTime(2026, 6, 10),
        salaryDay: 25,
        includeDefaultFixedPayments: true,
      );
      expect(included.accounts.any((a) => a.name.contains('水道')), isTrue);

      // baseDate 6/26 → サイクル 6/25〜7/24、22<25 → 第2暦月=7月(奇数)→ 非計上。
      final excluded = service.buildWorkbook(
        latestSnapshot: snapshot,
        baseDate: DateTime(2026, 6, 26),
        salaryDay: 25,
        includeDefaultFixedPayments: true,
      );
      expect(excluded.accounts.any((a) => a.name.contains('水道')), isFalse);
    });

    test('treats a self-referential payment source as unset', () {
      // 振替元が自分自身を指す不正設定は「未設定」に正規化する
      // (ローンを自分自身からは返済できない / 自己宛て誤ルーティング防止)。
      final selfRef = service.buildWorkbook(
        latestSnapshot: snapshot,
        baseDate: DateTime(2026, 5, 12),
        paymentSourceAccountIds: const <String, String>{'mobit': 'mobit'},
      );
      final selfMobit = selfRef.debtMasterRows.firstWhere(
        (row) => row.name == 'モビット',
      );
      expect(selfMobit.paymentSourceAccountId, isNull);
      expect(selfMobit.paymentSourceAccountName, isNull);

      // 自分以外の口座IDは従来どおり保持する (回帰なし)。
      final other = service.buildWorkbook(
        latestSnapshot: snapshot,
        baseDate: DateTime(2026, 5, 12),
        paymentSourceAccountIds: const <String, String>{'mobit': 'smbc_otsuka'},
      );
      final otherMobit = other.debtMasterRows.firstWhere(
        (row) => row.name == 'モビット',
      );
      expect(otherMobit.paymentSourceAccountId, 'smbc_otsuka');
    });

    test('treats a cardLoan payment source as unset', () {
      // 振替元がカードローン (現金借入 = mobit) を指す設定は不正扱いで未設定に
      // 正規化する。cardLoan はどのセレクタにも候補として出ないのに legacy 移行の
      // 名前衝突で保存され得る。非 null のままだと「原資未設定」レビューに出ず、
      // 現金系口座の見込み残高からも静かに消えるため。
      final loanSourced = service.buildWorkbook(
        latestSnapshot: snapshot,
        baseDate: DateTime(2026, 5, 12),
        paymentSourceAccountIds: <String, String>{
          AssetLiabilityPlanningService.acomShoppingAccountId: 'mobit',
        },
      );
      final acom = loanSourced.debtMasterRows.firstWhere(
        (row) => row.name == 'アコムショッピング',
      );
      expect(acom.paymentSourceAccountId, isNull);
      expect(acom.paymentSourceAccountName, isNull);
      // 未設定へ倒れることで原資未設定レビュー (修正導線) の対象になる。
      expect(
        loanSourced.paymentSourceMissingRows.any(
          (row) => row.name == 'アコムショッピング',
        ),
        isTrue,
      );
    });

    test('じぶん銀行(預金)とじぶん銀行カードローンを別IDに分離する', () {
      // 名前に「じぶん」を含むだけで同一IDに潰れると、預金を振替元に選べない。
      final workbook = service.buildWorkbook(
        latestSnapshot: const <String, double>{
          'じぶん銀行': 18918,
          'じぶん銀行カードローン': -994562,
        },
        baseDate: DateTime(2026, 5, 12),
      );
      final deposit = workbook.accounts.firstWhere(
        (account) => account.name == 'じぶん銀行',
      );
      final loan = workbook.accounts.firstWhere(
        (account) => account.name == 'じぶん銀行カードローン',
      );
      expect(deposit.id, AssetLiabilityPlanningService.jibunBankAccountId);
      expect(deposit.kind, AssetLiabilityAccountKind.deposit);
      expect(loan.id, AssetLiabilityPlanningService.jibunBankCardLoanAccountId);
      expect(loan.kind, AssetLiabilityAccountKind.cardLoan);
      expect(deposit.id, isNot(loan.id));
    });

    test('じぶん銀行を振替元に選ぶと原資未設定に倒れない', () {
      // 預金じぶん銀行を auPayカードの振替元に設定 → 未設定へ倒れず正しく解決。
      final workbook = service.buildWorkbook(
        latestSnapshot: const <String, double>{
          'じぶん銀行': 18918,
          'auPayカード': -36926,
        },
        baseDate: DateTime(2026, 5, 12),
        paymentSourceAccountIds: <String, String>{
          AssetLiabilityPlanningService.auPayCardAccountId:
              AssetLiabilityPlanningService.jibunBankAccountId,
        },
      );
      final aupay = workbook.debtMasterRows.firstWhere(
        (row) => row.name == 'auPayカード',
      );
      expect(
        aupay.paymentSourceAccountId,
        AssetLiabilityPlanningService.jibunBankAccountId,
      );
      expect(aupay.paymentSourceAccountName, 'じぶん銀行');
      expect(
        workbook.paymentSourceMissingRows.any((row) => row.name == 'auPayカード'),
        isFalse,
      );
    });

    test('旧衝突ID(カードローンID)の振替元をじぶん銀行(預金)へ移行する', () {
      // 衝突していた頃に保存された振替元 = カードローンID。預金が存在すれば
      // 預金へ読み替えて既存設定を自動回復する。
      final workbook = service.buildWorkbook(
        latestSnapshot: const <String, double>{
          'じぶん銀行': 18918,
          'auPayカード': -36926,
        },
        baseDate: DateTime(2026, 5, 12),
        paymentSourceAccountIds: <String, String>{
          AssetLiabilityPlanningService.auPayCardAccountId:
              AssetLiabilityPlanningService.jibunBankCardLoanAccountId,
        },
      );
      final aupay = workbook.debtMasterRows.firstWhere(
        (row) => row.name == 'auPayカード',
      );
      expect(
        aupay.paymentSourceAccountId,
        AssetLiabilityPlanningService.jibunBankAccountId,
      );
      expect(aupay.paymentSourceAccountName, 'じぶん銀行');
    });
  });
}
