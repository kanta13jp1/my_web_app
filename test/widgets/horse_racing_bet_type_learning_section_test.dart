import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/features/horse_racing/horse_racing_bet_type_learning_section.dart';
import 'package:my_web_app/features/horse_racing/horse_racing_performance_view_model.dart';

Widget _buildTestHarness({
  required List<Map<String, Object?>> betTypeAccuracy,
  required Map<String, Object?> learning,
  required HorseRacingPerformanceViewModel performance,
  bool isPredicting = false,
  VoidCallback? onRefreshAccuracyLearning,
  VoidCallback? onRunLearningBackfill,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
      child: Scaffold(
        body: SingleChildScrollView(
          child: HorseRacingBetTypeLearningSection(
            betTypeAccuracy: betTypeAccuracy,
            learning: learning,
            performance: performance,
            isPredicting: isPredicting,
            onRefreshAccuracyLearning: onRefreshAccuracyLearning ?? () {},
            onRunLearningBackfill: onRunLearningBackfill ?? () {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'renders normal accuracy cards, daily trend, and backfill at 360x800 @ 2.0x',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const performance = HorseRacingPerformanceViewModel(
        totalStakeYen: 1500,
        totalPayoutYen: 2100,
        netYen: 600,
        roiPercent: 140.0,
        resultCount: 35,
        hits: 21,
        hitRatePercent: 60.0,
        predictedProbabilityPercent: 55.0,
        calibrationGapPoints: 5.0,
        confidenceInterval: HorseRacingConfidenceInterval(43.6, 74.4),
        periodLabel: '2026-11-01〜2026-11-28',
        rankingOnHold: false,
        betTypes: [
          HorseRacingBetTypeEvidence(
            betType: '複勝',
            sampleSize: 20,
            hits: 12,
            hitRatePercent: 60.0,
            stakeYen: 1000,
            payoutYen: 1500,
            roiPercent: 150.0,
            confidenceInterval: HorseRacingConfidenceInterval(38.7, 78.1),
          ),
          HorseRacingBetTypeEvidence(
            betType: 'ワイド',
            sampleSize: 15,
            hits: 5,
            hitRatePercent: 33.3,
            stakeYen: 500,
            payoutYen: 600,
            roiPercent: 120.0,
            confidenceInterval: HorseRacingConfidenceInterval(15.2, 58.3),
          ),
        ],
      );

      await tester.pumpWidget(
        _buildTestHarness(
          betTypeAccuracy: const [
            {
              'bet_type': '複勝',
              'total_predictions': 20,
              'hits': 12,
              'hit_rate_pct': 60.0,
            },
            {
              'bet_type': 'ワイド',
              'total_predictions': 15,
              'hits': 5,
              'hit_rate_pct': 33.3,
            },
          ],
          learning: const {
            'best_low_risk_bet_type': '複勝',
            'daily_accuracy': [
              {
                'race_date': '2026-11-28',
                'evaluated_races': 12,
                'avg_learning_score': 0.84,
                'place_hit_rate_pct': 65,
                'wide_hit_rate_pct': 40,
                'skip_accuracy_pct': 80,
              },
            ],
            'backfill_status': [
              {
                'race_date': '2026-11-27',
                'source': 'netkeiba',
                'races': 24,
                'races_with_results': 24,
                'baseline_predictions': 24,
                'baseline_evaluated_races': 24,
              },
            ],
          },
          performance: performance,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('券種別学習AI'), findsOneWidget);
      expect(find.text('複勝命中率'), findsOneWidget);
      expect(find.text('ワイド命中率'), findsOneWidget);
      expect(find.text('60.0%'), findsNWidgets(2));
      expect(find.text('33.3%'), findsNWidgets(2));
      expect(find.text('12 / 20 的中（母数 20）'), findsOneWidget);
      expect(find.text('95%信頼区間 38.7–78.1%'), findsOneWidget);
      expect(find.text('投下 ¥1,000 / ROI 150.0%'), findsOneWidget);
      expect(
        find.text('参考指標: 複勝 の統計を継続観測中（購入推奨ではありません）'),
        findsOneWidget,
      );
      expect(find.text('日次学習推移'), findsOneWidget);
      expect(find.text('2026-11-28'), findsOneWidget);
      expect(find.text('過去レース学習データ'), findsOneWidget);
      expect(find.text('2026-11-27 / netkeiba'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'renders empty and insufficient-sample hold state at 360x800 @ 2.0x',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const performance = HorseRacingPerformanceViewModel(
        totalStakeYen: 0,
        totalPayoutYen: 0,
        netYen: 0,
        roiPercent: null,
        resultCount: 0,
        hits: 0,
        hitRatePercent: 0,
        predictedProbabilityPercent: null,
        calibrationGapPoints: null,
        confidenceInterval: null,
        periodLabel: '-',
        rankingOnHold: true,
        betTypes: [],
      );

      await tester.pumpWidget(
        _buildTestHarness(
          betTypeAccuracy: const [],
          learning: const {'best_low_risk_bet_type': '集計中'},
          performance: performance,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          '結果取得後に、購入しない判断・単勝・複勝・枠連・馬連・ワイド・馬単・3連複・3連単の的中率を自動集計します。',
        ),
        findsOneWidget,
      );
      expect(
        find.text('参考指標: データ不足のため券種ランキングと購入推奨を保留中'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'triggers refresh and backfill callbacks when enabled and blocks when predicting',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const performance = HorseRacingPerformanceViewModel(
        totalStakeYen: 0,
        totalPayoutYen: 0,
        netYen: 0,
        roiPercent: null,
        resultCount: 0,
        hits: 0,
        hitRatePercent: 0,
        predictedProbabilityPercent: null,
        calibrationGapPoints: null,
        confidenceInterval: null,
        periodLabel: '-',
        rankingOnHold: true,
        betTypes: [],
      );

      var refreshCount = 0;
      var backfillCount = 0;

      await tester.pumpWidget(
        _buildTestHarness(
          betTypeAccuracy: const [],
          learning: const {},
          performance: performance,
          isPredicting: false,
          onRefreshAccuracyLearning: () => refreshCount++,
          onRunLearningBackfill: () => backfillCount++,
        ),
      );
      await tester.pumpAndSettle();

      final refreshButton = find.text('結果分析を更新');
      final backfillButton = find.text('過去21日を学習');

      await tester.ensureVisible(refreshButton);
      await tester.tap(refreshButton);
      await tester.ensureVisible(backfillButton);
      await tester.tap(backfillButton);
      await tester.pumpAndSettle();

      expect(refreshCount, 1);
      expect(backfillCount, 1);

      await tester.pumpWidget(
        _buildTestHarness(
          betTypeAccuracy: const [],
          learning: const {},
          performance: performance,
          isPredicting: true,
          onRefreshAccuracyLearning: () => refreshCount++,
          onRunLearningBackfill: () => backfillCount++,
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(refreshButton);
      await tester.tap(refreshButton);
      await tester.ensureVisible(backfillButton);
      await tester.tap(backfillButton);
      await tester.pumpAndSettle();

      expect(refreshCount, 1);
      expect(backfillCount, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
