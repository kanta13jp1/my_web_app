import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/card_statement_reconciliation_planner.dart';

void main() {
  // auPAY example from the requests: billed 40,163 / configured 32,152 /
  // statement 23,182 / no imported statement lines → configured is 8,011 short.
  CardReconciliationPlan auPay({List<CardManualAdjustment> adj = const []}) =>
      CardReconciliationPlan(
        billedAmount: 40163,
        configuredDetailTotal: 32152,
        statementLineTotal: 23182,
        hasStatementLines: false,
        manualAdjustments: adj,
      );

  group('CardReconciliationPlan', () {
    test('computes the configured difference and flags review', () {
      final plan = auPay();
      expect(plan.configuredDifference, -8011);
      expect(plan.isConfiguredBalanced, isFalse);
      expect(plan.needsReview, isTrue);
      expect(plan.alerts, contains('設定済みカード内訳合計が請求額と一致しません'));
      expect(plan.alerts, contains('カード明細の取り込みが未実施です'));
    });

    test('suggestedBalancingAmount is billed minus effective configured', () {
      expect(auPay().suggestedBalancingAmount, 8011);
    });

    test('previewing the balancing amount resolves the alert', () {
      final preview = auPay().previewAdjustment(8011);
      expect(preview.valid, isTrue);
      expect(preview.resolvesAlert, isTrue);
      expect(preview.resultingDifference, 0);
      expect(preview.overshoots, isFalse);
    });

    test('an overshooting adjustment is flagged and does not resolve', () {
      final preview = auPay().previewAdjustment(20000);
      expect(preview.resolvesAlert, isFalse);
      expect(preview.overshoots, isTrue); // -8011 + 20000 = +11989 (sign flip)
    });

    test('applying the balancing amount makes the plan balanced', () {
      final plan = auPay().withAdjustment(
        const CardManualAdjustment(amount: 8011, memo: '手動補正'),
      );
      expect(plan.effectiveConfiguredTotal, 40163);
      expect(plan.configuredDifference, 0);
      expect(plan.isConfiguredBalanced, isTrue);
      // Missing-import alert remains until statement lines are imported.
      expect(plan.alerts, contains('カード明細の取り込みが未実施です'));
      expect(plan.alerts,
          isNot(contains('設定済みカード内訳合計が請求額と一致しません')));
    });

    test('provisional adjustments are excluded from official totals (#3349)', () {
      final plan = auPay(adj: <CardManualAdjustment>[
        const CardManualAdjustment(amount: 8011, memo: '仮', provisional: true),
      ]);
      expect(plan.provisionalTotal, 8011);
      expect(plan.officialAdjustmentTotal, 0);
      expect(plan.effectiveConfiguredTotal, 32152); // unchanged
      expect(plan.configuredDifference, -8011); // still off
      expect(plan.isConfiguredBalanced, isFalse);
    });

    test('promoting a provisional line moves it into the official total', () {
      final provisional =
          const CardManualAdjustment(amount: 8011, provisional: true);
      final plan = auPay(adj: <CardManualAdjustment>[provisional.promote()]);
      expect(plan.officialAdjustmentTotal, 8011);
      expect(plan.isConfiguredBalanced, isTrue);
    });

    test('previewing a provisional proposal leaves the official diff unmoved', () {
      final preview = auPay().previewAdjustment(8011, provisional: true);
      expect(preview.valid, isTrue);
      expect(preview.resultingDifference, -8011);
      expect(preview.resolvesAlert, isFalse);
    });

    test('rejects a zero or non-finite amount', () {
      expect(auPay().previewAdjustment(0).valid, isFalse);
      expect(auPay().previewAdjustment(double.nan).valid, isFalse);
    });

    test('a balanced card with imported lines needs no review', () {
      const plan = CardReconciliationPlan(
        billedAmount: 40163,
        configuredDetailTotal: 40163,
        statementLineTotal: 40163,
        hasStatementLines: true,
      );
      expect(plan.isConfiguredBalanced, isTrue);
      expect(plan.needsReview, isFalse);
      expect(plan.alerts, isEmpty);
      expect(plan.statementDifference, 0);
    });

    test('revolving cards suppress mismatch alerts', () {
      const plan = CardReconciliationPlan(
        billedAmount: 40163,
        configuredDetailTotal: 32152,
        hasStatementLines: false,
        isRevolving: true,
      );
      expect(plan.needsReview, isFalse);
      expect(plan.alerts, isEmpty);
    });
  });
}
