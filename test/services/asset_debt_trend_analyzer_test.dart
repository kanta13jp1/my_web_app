import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_debt_trend_analyzer.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';

void main() {
  const planner = AssetLiabilityPlanningService();
  const analyzer = AssetDebtTrendAnalyzer();
  final baseDate = DateTime(2026, 6, 1);

  String debtId(AssetLiabilityWorkbook workbook, String name) {
    return workbook.debtMasterRows.firstWhere((row) => row.name == name).id;
  }

  group('AssetDebtTrendAnalyzer.estimatePayoff', () {
    test('returns null months when payment does not exceed interest', () {
      // 30万円 @ 年15% → 月利息 3,750円。返済 3,000円では元金が減らない。
      final estimate = AssetDebtTrendAnalyzer.estimatePayoff(
        balance: 300000,
        monthlyRate: 0.15 / 12,
        monthlyPayment: 3000,
      );
      expect(estimate.everPaysOff, isFalse);
      expect(estimate.months, isNull);
    });

    test('returns finite months when payment exceeds interest', () {
      final estimate = AssetDebtTrendAnalyzer.estimatePayoff(
        balance: 100000,
        monthlyRate: 0.15 / 12,
        monthlyPayment: 20000,
      );
      expect(estimate.everPaysOff, isTrue);
      expect(estimate.months, isNotNull);
      expect(estimate.months! > 0, isTrue);
      expect(estimate.totalInterest > 0, isTrue);
    });

    test('returns zero months for a cleared balance', () {
      final estimate = AssetDebtTrendAnalyzer.estimatePayoff(
        balance: 0,
        monthlyRate: 0.15 / 12,
        monthlyPayment: 1000,
      );
      expect(estimate.months, 0);
      expect(estimate.everPaysOff, isTrue);
    });
  });

  group('AssetDebtTrendAnalyzer.analyze', () {
    test('flags negative amortization when payment is below interest', () {
      // 30万円 @ 15% / 返済 3,000円 → 月利息 3,750円 > 返済 → 元金が減らない。
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          'bank': 50000,
          'リボカード': -300000,
        },
        baseDate: baseDate,
        monthlyPaymentOverrides: const <String, double>{'リボカード': 3000},
      );

      final insights = analyzer.analyze(workbook: workbook);

      expect(insights, hasLength(1));
      final insight = insights.single;
      expect(insight.category, AssetDebtTrendCategory.negativeAmortization);
      expect(insight.severity, AssetDebtTrendSeverity.critical);
      expect(insight.estimatedPayoffMonths, isNull);
      expect(insight.nextMonthAction.contains('一括返済'), isTrue);
      expect(insight.nextMonthAction.contains('新規利用'), isTrue);
      expect(insight.problem.contains('元金'), isTrue);
    });

    test(
        'flags a revolving balance that grew month over month '
        '(the FamiPay example)', () {
      // 先月 3万円 → 今月 10万円 (+7万) なのに返済は 5,000円。
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          'bank': 80000,
          'ファミペイ': -100000,
        },
        baseDate: baseDate,
        monthlyPaymentOverrides: const <String, double>{'ファミペイ': 5000},
      );
      final famipayId = debtId(workbook, 'ファミペイ');

      final insights = analyzer.analyze(
        workbook: workbook,
        priorBalancesByAccountId: <String, double>{famipayId: 30000},
      );

      expect(insights, hasLength(1));
      final insight = insights.single;
      expect(insight.category, AssetDebtTrendCategory.balanceIncreasing);
      // 増加額 7万 > 返済 5,000 → 払っても追いつかない → critical。
      expect(insight.severity, AssetDebtTrendSeverity.critical);
      expect(insight.balanceDelta, 70000);
      expect(insight.problem.contains('先月比+70,000円'), isTrue);
      expect(insight.problem.contains('純増'), isTrue);
      expect(insight.nextMonthAction.contains('新規利用'), isTrue);
      expect(insight.nextMonthAction.contains('一括返済'), isTrue);
    });

    test('flags a very slow payoff even without history', () {
      // 30万円 @ 15% / 返済 6,000円 → 元金は減るが完済まで 60ヶ月超。
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          'bank': 50000,
          'ショッピングカード': -300000,
        },
        baseDate: baseDate,
        monthlyPaymentOverrides: const <String, double>{'ショッピングカード': 6000},
      );

      final insights = analyzer.analyze(workbook: workbook);

      expect(insights, hasLength(1));
      final insight = insights.single;
      expect(insight.category, AssetDebtTrendCategory.slowPayoff);
      expect(insight.estimatedPayoffMonths, isNotNull);
      expect(insight.estimatedPayoffMonths! > 60, isTrue);
      expect(insight.problem.contains('完済まで'), isTrue);
    });

    test('produces no insight for a healthy, shrinking revolving balance', () {
      // 5万円 @ 15% / 返済 2万円 → すぐ完済。先月より残高は減少。
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          'bank': 200000,
          '優等生カード': -50000,
        },
        baseDate: baseDate,
        monthlyPaymentOverrides: const <String, double>{'優等生カード': 20000},
      );
      final cardId = debtId(workbook, '優等生カード');

      final insights = analyzer.analyze(
        workbook: workbook,
        priorBalancesByAccountId: <String, double>{cardId: 80000},
      );

      expect(insights, isEmpty);
    });

    test('ignores non-revolving kinds', () {
      expect(
        AssetDebtTrendAnalyzer.isRevolvingLikeKind(
          AssetLiabilityAccountKind.utility,
        ),
        isFalse,
      );
      expect(
        AssetDebtTrendAnalyzer.isRevolvingLikeKind(
          AssetLiabilityAccountKind.creditCard,
        ),
        isTrue,
      );
      expect(
        AssetDebtTrendAnalyzer.isRevolvingLikeKind(
          AssetLiabilityAccountKind.cardLoan,
        ),
        isTrue,
      );
    });

    test('prioritises critical insights first', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          'bank': 50000,
          'リボカード':
              -300000, // payment < interest → negative amortization (critical)
          'ショッピングカード': -300000, // slow payoff (warning)
        },
        baseDate: baseDate,
        monthlyPaymentOverrides: const <String, double>{
          'リボカード': 3000,
          'ショッピングカード': 6000,
        },
      );

      final insights = analyzer.analyze(workbook: workbook);

      expect(insights.length, 2);
      expect(insights.first.severity, AssetDebtTrendSeverity.critical);
      expect(
        insights.first.category,
        AssetDebtTrendCategory.negativeAmortization,
      );
    });
  });
}
