import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';
import 'package:my_web_app/services/asset_liability_workbook_memoizer.dart';

void main() {
  group('AssetLiabilityWorkbookMemoizer', () {
    const planner = AssetLiabilityPlanningService();

    AssetLiabilityWorkbook? resolveWith(
      AssetLiabilityWorkbookMemoizer memoizer, {
      required Map<String, double> latestSnapshot,
      DateTime? baseDate,
      Map<String, double>? confirmedPaymentDays,
      Map<String, double>? monthlyPaymentOverrides,
      Map<String, double>? actualPaymentAmounts,
      Map<String, String>? paymentDifferenceReasons,
      Map<String, double>? annualRateOverrides,
      Map<String, int>? paymentDayOverrides,
      Set<String>? paidAccountNames,
      Set<String>? billingConfirmedAccountIds,
      Map<String, String>? paymentSourceAccountIds,
      Map<String, String>? defaultPaymentSourceAccountIds,
      Map<String, String>? defaultCardBillingAccountIds,
      Map<String, String>? cardBillingAccountIds,
      Map<String, AssetLiabilityRevolvingCreditConfig>? revolvingConfigs,
      Map<String, AssetCardUsagePolicy>? cardUsagePolicies,
      List<AssetLiabilityIncomePlan>? incomePlans,
      List<AssetLiabilityCardStatementLine>? cardStatementLines,
      List<AssetLiabilityTransferTask>? transferTasks,
      List<AssetRecurringFixedCost>? recurringFixedCosts,
      bool includeDefaultFixedPayments = true,
      int? salaryDay = 25,
    }) {
      return memoizer.resolve(
        planner: planner,
        latestSnapshot: latestSnapshot,
        baseDate: baseDate ?? DateTime(2026, 11, 23),
        confirmedPaymentDays: confirmedPaymentDays ?? const <String, double>{},
        monthlyPaymentOverrides:
            monthlyPaymentOverrides ?? const <String, double>{},
        actualPaymentAmounts: actualPaymentAmounts ?? const <String, double>{},
        paymentDifferenceReasons:
            paymentDifferenceReasons ?? const <String, String>{},
        annualRateOverrides: annualRateOverrides ?? const <String, double>{},
        paymentDayOverrides: paymentDayOverrides ?? const <String, int>{},
        paidAccountNames: paidAccountNames ?? const <String>{},
        billingConfirmedAccountIds:
            billingConfirmedAccountIds ?? const <String>{},
        paymentSourceAccountIds:
            paymentSourceAccountIds ?? const <String, String>{},
        defaultPaymentSourceAccountIds:
            defaultPaymentSourceAccountIds ?? const <String, String>{},
        defaultCardBillingAccountIds:
            defaultCardBillingAccountIds ?? const <String, String>{},
        cardBillingAccountIds:
            cardBillingAccountIds ?? const <String, String>{},
        revolvingConfigs: revolvingConfigs ??
            const <String, AssetLiabilityRevolvingCreditConfig>{},
        cardUsagePolicies:
            cardUsagePolicies ?? const <String, AssetCardUsagePolicy>{},
        incomePlans: incomePlans ?? const <AssetLiabilityIncomePlan>[],
        cardStatementLines:
            cardStatementLines ?? const <AssetLiabilityCardStatementLine>[],
        transferTasks: transferTasks ?? const <AssetLiabilityTransferTask>[],
        recurringFixedCosts:
            recurringFixedCosts ?? const <AssetRecurringFixedCost>[],
        includeDefaultFixedPayments: includeDefaultFixedPayments,
        salaryDay: salaryDay,
      );
    }

    test('hits cache on equivalent inputs regardless of map key order', () {
      final memoizer = AssetLiabilityWorkbookMemoizer();
      final firstSnapshot = <String, double>{
        '三井住友銀行大塚支店': 25000,
        'PayPayカード': -50000,
      };
      final reorderedSnapshot = <String, double>{
        'PayPayカード': -50000,
        '三井住友銀行大塚支店': 25000,
      };

      final w1 = resolveWith(memoizer, latestSnapshot: firstSnapshot);
      final w2 = resolveWith(memoizer, latestSnapshot: reorderedSnapshot);

      expect(w1, isNotNull);
      expect(identical(w1, w2), isTrue);
      expect(memoizer.cacheMisses, 1);
      expect(memoizer.cacheHits, 1);
    });

    test('invalidates cache on in-place map/set mutations and option changes',
        () {
      final memoizer = AssetLiabilityWorkbookMemoizer();
      final snapshot = <String, double>{
        '三井住友銀行大塚支店': 25000,
        'PayPayカード': -50000,
      };
      final confirmedPaymentDays = <String, double>{'PayPayカード': 27};
      final paidNames = <String>{};
      final revolvingConfigs = <String, AssetLiabilityRevolvingCreditConfig>{
        'PayPayカード': const AssetLiabilityRevolvingCreditConfig(
          monthlyAmount: 10000,
        ),
      };
      final cardUsagePolicies = <String, AssetCardUsagePolicy>{
        'PayPayカード': AssetCardUsagePolicy(
          enforceOneShot: true,
          changedAt: DateTime.utc(2026, 11, 1),
          memo: 'initial',
        ),
      };
      final recurringFixedCosts = <AssetRecurringFixedCost>[
        const AssetRecurringFixedCost(
          id: 'rfc1',
          name: '電気代',
          amount: 8000,
          paymentDay: 15,
        ),
      ];

      final base = resolveWith(
        memoizer,
        latestSnapshot: snapshot,
        confirmedPaymentDays: confirmedPaymentDays,
        paidAccountNames: paidNames,
        revolvingConfigs: revolvingConfigs,
        cardUsagePolicies: cardUsagePolicies,
        recurringFixedCosts: recurringFixedCosts,
      );
      expect(memoizer.cacheMisses, 1);

      // In-place snapshot mutation
      snapshot['三井住友銀行大塚支店'] = 35000;
      final afterSnapshot = resolveWith(
        memoizer,
        latestSnapshot: snapshot,
        confirmedPaymentDays: confirmedPaymentDays,
        paidAccountNames: paidNames,
        revolvingConfigs: revolvingConfigs,
        cardUsagePolicies: cardUsagePolicies,
        recurringFixedCosts: recurringFixedCosts,
      );
      expect(identical(base, afterSnapshot), isFalse);
      expect(memoizer.cacheMisses, 2);

      // In-place set mutation
      paidNames.add('PayPayカード');
      final afterPaid = resolveWith(
        memoizer,
        latestSnapshot: snapshot,
        confirmedPaymentDays: confirmedPaymentDays,
        paidAccountNames: paidNames,
        revolvingConfigs: revolvingConfigs,
        cardUsagePolicies: cardUsagePolicies,
        recurringFixedCosts: recurringFixedCosts,
      );
      expect(identical(afterSnapshot, afterPaid), isFalse);
      expect(memoizer.cacheMisses, 3);

      // In-place confirmedPaymentDays mutation
      confirmedPaymentDays['PayPayカード'] = 28;
      resolveWith(
        memoizer,
        latestSnapshot: snapshot,
        confirmedPaymentDays: confirmedPaymentDays,
        paidAccountNames: paidNames,
        revolvingConfigs: revolvingConfigs,
        cardUsagePolicies: cardUsagePolicies,
        recurringFixedCosts: recurringFixedCosts,
      );
      expect(memoizer.cacheMisses, 4);

      // Scalar changes: salaryDay, includeDefaultFixedPayments, baseDate
      resolveWith(
        memoizer,
        latestSnapshot: snapshot,
        confirmedPaymentDays: confirmedPaymentDays,
        paidAccountNames: paidNames,
        revolvingConfigs: revolvingConfigs,
        cardUsagePolicies: cardUsagePolicies,
        recurringFixedCosts: recurringFixedCosts,
        salaryDay: 26,
      );
      resolveWith(
        memoizer,
        latestSnapshot: snapshot,
        confirmedPaymentDays: confirmedPaymentDays,
        paidAccountNames: paidNames,
        revolvingConfigs: revolvingConfigs,
        cardUsagePolicies: cardUsagePolicies,
        recurringFixedCosts: recurringFixedCosts,
        salaryDay: 26,
        includeDefaultFixedPayments: false,
      );
      resolveWith(
        memoizer,
        latestSnapshot: snapshot,
        confirmedPaymentDays: confirmedPaymentDays,
        paidAccountNames: paidNames,
        revolvingConfigs: revolvingConfigs,
        cardUsagePolicies: cardUsagePolicies,
        recurringFixedCosts: recurringFixedCosts,
        salaryDay: 26,
        includeDefaultFixedPayments: false,
        baseDate: DateTime(2026, 11, 24),
      );
      expect(memoizer.cacheMisses, 7);

      // List/model changes: recurringFixedCosts usdAmount, incomePlans, transferTasks, cardStatementLines
      recurringFixedCosts[0] = const AssetRecurringFixedCost(
        id: 'rfc1',
        name: 'Claude Pro',
        amount: 3100,
        paymentDay: 15,
        currency: AssetRecurringFixedCostCurrency.usd,
        usdAmount: 20,
      );
      resolveWith(
        memoizer,
        latestSnapshot: snapshot,
        confirmedPaymentDays: confirmedPaymentDays,
        paidAccountNames: paidNames,
        revolvingConfigs: revolvingConfigs,
        cardUsagePolicies: cardUsagePolicies,
        recurringFixedCosts: recurringFixedCosts,
        salaryDay: 26,
        includeDefaultFixedPayments: false,
        baseDate: DateTime(2026, 11, 24),
        incomePlans: <AssetLiabilityIncomePlan>[
          AssetLiabilityIncomePlan(
            id: 'inc1',
            date: DateTime(2026, 11, 25),
            name: '給与',
            amount: 250000,
            destinationAccountId: 'otsuka',
            destinationAccountName: '三井住友銀行大塚支店',
            received: false,
          ),
        ],
        transferTasks: const <AssetLiabilityTransferTask>[
          AssetLiabilityTransferTask(
            id: 'tr1',
            fromAccountId: 'otsuka',
            fromAccountName: '三井住友銀行大塚支店',
            toAccountId: 'paypay_card',
            toAccountName: 'PayPayカード',
            amount: 50000,
            dueDate: null,
          ),
        ],
        cardStatementLines: <AssetLiabilityCardStatementLine>[
          AssetLiabilityCardStatementLine(
            id: 'csl1',
            billingAccountId: 'paypay_card',
            billingAccountName: 'PayPayカード',
            postedAt: DateTime(2026, 11, 10),
            description: '食材',
            amount: 3200,
          ),
        ],
      );
      expect(memoizer.cacheMisses, 8);
      expect(memoizer.cacheHits, 0);
    });

    test('clears cache on empty snapshot and rebuilds on next snapshot', () {
      final memoizer = AssetLiabilityWorkbookMemoizer();
      final snapshot = <String, double>{'三井住友銀行大塚支店': 25000};

      final w1 = resolveWith(memoizer, latestSnapshot: snapshot);
      expect(w1, isNotNull);

      final empty =
          resolveWith(memoizer, latestSnapshot: const <String, double>{});
      expect(empty, isNull);

      final w2 = resolveWith(memoizer, latestSnapshot: snapshot);
      expect(w2, isNotNull);
      expect(identical(w1, w2), isFalse);
      expect(memoizer.cacheMisses, 2);
      expect(memoizer.cacheHits, 0);
    });
  });
}
