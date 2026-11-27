import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/features/horse_racing/horse_racing_data_gateway.dart';
import 'package:my_web_app/features/horse_racing/horse_racing_decision_support.dart';
import 'package:my_web_app/features/horse_racing/horse_racing_performance_view_model.dart';
import 'package:my_web_app/pages/horse_racing_predictor_page.dart';

void main() {
  const mobileViewport = Size(360, 800);

  Widget wrapMobile2x(Widget child) {
    return MediaQuery(
      data: const MediaQueryData(
        size: mobileViewport,
        textScaler: TextScaler.linear(2.0),
      ),
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: child),
        ),
      ),
    );
  }

  group('HorseRacingResponsibleUseCard @ 360x800 2.0x', () {
    testWidgets(
        'shows non-guarantee/loss notices, updates budget limit, and toggles pause',
        (tester) async {
      await tester.binding.setSurfaceSize(mobileViewport);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var budget = 2000;
      var paused = false;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return wrapMobile2x(
              HorseRacingResponsibleUseCard(
                dailyBudgetYen: budget,
                paused: paused,
                onBudgetChanged: (value) => setState(() => budget = value),
                onPauseChanged: (value) => setState(() => paused = value),
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('horse-racing-responsible-use-card')),
        findsOneWidget,
      );
      expect(find.textContaining('AI予測は購入を勧めず、結果を保証しません'), findsOneWidget);
      expect(find.textContaining('損失の可能性があります'), findsOneWidget);

      await tester.tap(find.byKey(const Key('horse-racing-budget-limit')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('¥5,000').last);
      await tester.pumpAndSettle();
      expect(budget, 5000);

      await tester.tap(find.byKey(const Key('horse-racing-pause-action')));
      await tester.pump();
      expect(paused, isTrue);
      expect(find.byKey(const Key('horse-racing-paused-chip')), findsOneWidget);
      expect(find.text('購入記録を休止中'), findsOneWidget);
    });
  });

  group('HorseRacingEvidencePanel & PerformanceViewModel @ 360x800 2.0x', () {
    testWidgets('holds ranking/recommendation when sample size < 30',
        (tester) async {
      await tester.binding.setSurfaceSize(mobileViewport);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final summary = HorseRacingPerformanceViewModel.from(
        accuracyStats: const {
          'total_results': 12,
          'correct_count': 3,
          'hit_rate_pct': 25.0,
          'average_predicted_probability_pct': 35.0,
        },
        betTickets: const [
          {
            'id': 't1',
            'metadata': {
              'race_date': '2026-09-01',
              'total_amount': 2000,
              'payout_amount': 1500,
              'lines': [
                {'bet_type': '複勝', 'amount': 2000},
              ],
            },
          },
        ],
      );

      expect(summary.rankingOnHold, isTrue);
      expect(summary.roiPercent, -25.0);
      expect(summary.calibrationGapPoints, 10.0);

      await tester.pumpWidget(
        wrapMobile2x(HorseRacingEvidencePanel(summary: summary)),
      );
      await tester.pumpAndSettle();

      expect(find.text('データ不足のためランキング・購入推奨を保留'), findsOneWidget);
      expect(find.text('ROI -25.0%'), findsOneWidget);
      expect(find.text('母数 12件'), findsOneWidget);
      expect(find.text('較正差 10.0pt'), findsOneWidget);
    });

    testWidgets(
        'shows non-computable ROI/calibration when stake is 0 and probability missing',
        (tester) async {
      await tester.binding.setSurfaceSize(mobileViewport);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final summary = HorseRacingPerformanceViewModel.from(
        accuracyStats: const {
          'total_results': 40,
          'correct_count': 10,
          'hit_rate_pct': 25.0,
        },
        betTickets: const [],
      );

      expect(summary.rankingOnHold, isTrue);
      expect(summary.roiPercent, isNull);
      expect(summary.predictedProbabilityPercent, isNull);

      await tester.pumpWidget(
        wrapMobile2x(HorseRacingEvidencePanel(summary: summary)),
      );
      await tester.pumpAndSettle();

      expect(find.text('ROI 算出不可'), findsOneWidget);
      expect(find.text('平均予測確率 未提供'), findsOneWidget);
      expect(find.text('較正差 未評価'), findsOneWidget);
    });

    test('releases ranking hold when sample >= 30, stake > 0, and calibrated',
        () {
      final summary = HorseRacingPerformanceViewModel.from(
        accuracyStats: const {
          'total_results': 40,
          'correct_count': 18,
          'hit_rate_pct': 45.0,
          'average_predicted_probability_pct': 42.0,
        },
        betTickets: const [
          {
            'id': 't2',
            'metadata': {
              'race_date': '2026-09-02',
              'total_amount': 1000,
              'payout_amount': 1500,
              'lines': [
                {'bet_type': 'ワイド', 'amount': 1000},
              ],
            },
          },
        ],
      );

      expect(summary.rankingOnHold, isFalse);
      expect(summary.roiPercent, 50.0);
      expect(summary.calibrationGapPoints, 3.0);
    });
  });

  group('HorseRacingPredictorPage states @ 360x800 2.0x', () {
    testWidgets('unauthenticated bet tab keeps responsible notice visible',
        (tester) async {
      await tester.binding.setSurfaceSize(mobileViewport);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: mobileViewport,
            textScaler: TextScaler.linear(2.0),
          ),
          child: MaterialApp(
            home: HorseRacingPredictorPage(
              initialTabIndex: 3,
              gateway: _FakeHorseRacingGateway(authenticated: false),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('horse-racing-responsible-use-card')),
        findsOneWidget,
      );
      expect(find.text('ログインすると購入馬券を記録できます'), findsOneWidget);
    });

    testWidgets('error state shows retry alongside responsible notice',
        (tester) async {
      await tester.binding.setSurfaceSize(mobileViewport);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: mobileViewport,
            textScaler: TextScaler.linear(2.0),
          ),
          child: MaterialApp(
            home: HorseRacingPredictorPage(
              gateway: _FakeHorseRacingGateway(
                authenticated: true,
                loadError: Exception('network timeout'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('horse-racing-responsible-use-card')),
        findsOneWidget,
      );
      expect(find.text('ネットワーク接続エラー'), findsOneWidget);
      expect(find.text('再試行'), findsOneWidget);
    });

    testWidgets('skip recommendation renders 見送り alongside responsible notice',
        (tester) async {
      await tester.binding.setSurfaceSize(mobileViewport);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final gateway = _FakeHorseRacingGateway(
        authenticated: true,
        snapshot: const HorseRacingDashboardSnapshot(
          todayRaces: [
            {
              'id': 'race-skip-1',
              'race_name': 'テスト記念',
              'venue': '東京',
              'race_number': 11,
              'course_type': '芝',
              'distance': 2000,
              'grade': 'G1',
              'status': 'scheduled',
              'horse_entries': [
                {'horse_name': 'サンプルA', 'post_position': 1},
                {'horse_name': 'サンプルB', 'post_position': 2},
                {'horse_name': 'サンプルC', 'post_position': 3},
              ],
              'horse_predictions': {
                'first_pick': 'サンプルA',
                'second_pick': 'サンプルB',
                'third_pick': 'サンプルC',
                'confidence': 0.25,
                'recommended_bets': [
                  {
                    'bet_type': '購入しない',
                    'combination': '見送り',
                    'rationale': 'データ不足のため見送り',
                  },
                ],
              },
            },
          ],
        ),
      );

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: mobileViewport,
            textScaler: TextScaler.linear(2.0),
          ),
          child: MaterialApp(
            home: HorseRacingPredictorPage(gateway: gateway),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('horse-racing-responsible-use-card')),
        findsOneWidget,
      );
      await tester.tap(find.text('テスト記念'));
      await tester.pumpAndSettle();
      expect(find.textContaining('見送り'), findsWidgets);
    });
  });
}

typedef _JsonMap = Map<String, dynamic>;

class _FakeHorseRacingGateway implements HorseRacingDataGateway {
  _FakeHorseRacingGateway({
    required this.authenticated,
    this.snapshot = const HorseRacingDashboardSnapshot(),
    this.loadError,
  });

  final bool authenticated;
  final HorseRacingDashboardSnapshot snapshot;
  final Exception? loadError;

  @override
  bool get isAuthenticated => authenticated;

  @override
  String? get userId => authenticated ? 'test-user' : null;

  @override
  Future<HorseRacingDashboardSnapshot> loadDashboard({
    required String date,
    required String raceType,
  }) async {
    if (loadError != null) throw loadError!;
    return snapshot;
  }

  @override
  Future<List<_JsonMap>> fetchBetTickets() async => snapshot.betTickets;

  @override
  Future<_JsonMap> runPredictions({
    required String date,
    required String raceType,
    String? raceId,
  }) async =>
      const {};

  @override
  Future<void> refreshAccuracyLearning() async {}

  @override
  Future<_JsonMap> runLearningBackfill({
    required String dateTo,
  }) async =>
      const {};

  @override
  Future<void> createBetTicket(_JsonMap metadata) async {}

  @override
  Future<void> settleBetTicket({
    required Object ticketId,
    required _JsonMap metadata,
  }) async {}
}
