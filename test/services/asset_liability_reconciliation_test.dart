import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_liability_monthly_state_store.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';

void main() {
  group('AssetLiability auto-reconciliation', () {
    test(
        'Issue #5211: reconciles billing confirmations from server paid and actual amounts',
        () {
      const state = AssetLiabilityMonthlyState(
        paidAccountNames: <String>{'NOTION LABS, INC.', '横浜銀行'},
        actualPaymentAmounts: <String, double>{'mobit': 10000},
        paymentSourceAccountIds: <String, String>{'notion': 'smbc_bank'},
      );

      final autoReconciled = <String>{...state.billingConfirmedAccountIds};
      for (final paidName in state.paidAccountNames) {
        final trimmed = paidName.trim();
        autoReconciled.add(paidName);
        autoReconciled.add(trimmed);
        autoReconciled.add(trimmed.toLowerCase());
      }
      for (final entry in state.actualPaymentAmounts.entries) {
        if (entry.value > 0) {
          autoReconciled.add(entry.key);
        }
      }

      expect(autoReconciled.contains('NOTION LABS, INC.'), isTrue);
      expect(autoReconciled.contains('notion labs, inc.'), isTrue);
      expect(autoReconciled.contains('mobit'), isTrue);
    });

    test(
      'Issue #4901: revolving card suppresses mismatch alerts and flags isRevolving',
      () {
        final planner = AssetLiabilityPlanningService();
        final baseDate = DateTime(2026, 8, 26);
        final workbook = planner.buildWorkbook(
          latestSnapshot: const <String, double>{
            'bank': 500000,
            'auPAYカード': -120000,
            'ファミペイ': -30000,
          },
          baseDate: baseDate,
          revolvingConfigs: const <String, AssetLiabilityRevolvingCreditConfig>{
            'au_pay_card': AssetLiabilityRevolvingCreditConfig(
              monthlyAmount: 10000,
              newUsageAmount: 50000,
            ),
          },
        );

        final reconciliation = workbook.cardStatementReconciliation;
        final auPayGroup = reconciliation.groups.firstWhere(
          (g) =>
              g.billingAccountName.contains('auPAY') ||
              g.billingAccountId == 'au_pay_card',
        );
        expect(auPayGroup.isRevolving, isTrue);
        // リボ払いカードは明細合計と請求額の不一致アラートが抑止される
        expect(auPayGroup.alerts, isEmpty);
        expect(auPayGroup.revolvingBilling, isNotNull);

        final famipayGroup = reconciliation.groups.firstWhere(
          (g) =>
              g.billingAccountName.contains('ファミペイ') ||
              g.billingAccountId == 'famipay_card',
        );
        expect(famipayGroup.isRevolving, isFalse);
        // 非リボカードは明細未取込時にアラートが出る
        expect(famipayGroup.alerts, contains(cardStatementMissingImportAlert));
      },
    );
  });
}
