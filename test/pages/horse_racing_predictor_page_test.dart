import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/features/horse_racing/horse_racing_data_gateway.dart';
import 'package:my_web_app/features/horse_racing/horse_racing_performance_view_model.dart';
import 'package:my_web_app/pages/horse_racing_predictor_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.navigation, null);
  });

  testWidgets('未ログイン状態でも責任ある利用と購入記録の制限を表示する', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HorseRacingPredictorPage(
          initialTabIndex: 3,
          gateway: _FakeHorseRacingGateway(authenticated: false),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(HorseRacingPredictorPage), findsOneWidget);
    expect(find.textContaining('AI予測は購入を勧めず'), findsOneWidget);
    expect(find.text('ログインすると購入馬券を記録できます'), findsOneWidget);
  });

  testWidgets('取得エラーを再試行可能な状態として表示する', (tester) async {
    final gateway = _FakeHorseRacingGateway(
      authenticated: true,
      loadError: Exception('network timeout'),
    );

    await tester.pumpWidget(
      MaterialApp(home: HorseRacingPredictorPage(gateway: gateway)),
    );
    await tester.pumpAndSettle();

    expect(find.text('ネットワーク接続エラー'), findsOneWidget);
    expect(find.text('再試行'), findsOneWidget);
  });

  testWidgets('投下額・払戻・ROI・母数・信頼区間・較正を同じ判断面に表示する', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final gateway = _FakeHorseRacingGateway(
      authenticated: true,
      snapshot: const HorseRacingDashboardSnapshot(
        accuracyStats: {
          'total_predictions': 24,
          'total_results': 20,
          'correct_count': 8,
          'hit_rate_pct': 40.0,
          'average_predicted_probability_pct': 55.0,
          'bet_type_accuracy': [
            {
              'bet_type': 'ワイド',
              'total_predictions': 20,
              'hits': 8,
              'hit_rate_pct': 40.0,
            },
          ],
        },
        betTickets: [
          {
            'id': 'ticket-1',
            'metadata': {
              'race_date': '2026-09-01',
              'total_amount': 1000,
              'payout_amount': 800,
              'settled': true,
              'lines': [
                {'bet_type': 'ワイド', 'combination': '1-2', 'amount': 1000},
              ],
            },
          },
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HorseRacingPredictorPage(initialTabIndex: 2, gateway: gateway),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('データ不足のためランキング・購入推奨を保留'), findsOneWidget);
    expect(find.text('期間 2026-09-01'), findsOneWidget);
    expect(find.text('投下額 ¥1,000'), findsOneWidget);
    expect(find.text('払戻額 ¥800'), findsOneWidget);
    expect(find.text('ROI -20.0%'), findsOneWidget);
    expect(find.text('母数 20件'), findsOneWidget);
    expect(find.textContaining('95%信頼区間'), findsWidgets);
    expect(find.text('平均予測確率 55.0%'), findsOneWidget);
    expect(find.text('較正差 15.0pt'), findsOneWidget);
  });

  testWidgets('休止操作で購入記録を明示的に停止できる', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HorseRacingPredictorPage(
          gateway: _FakeHorseRacingGateway(authenticated: false),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('horse-racing-pause-action')));
    await tester.pump();

    expect(find.byKey(const Key('horse-racing-paused-chip')), findsOneWidget);
    expect(find.text('購入記録を休止中'), findsOneWidget);
    expect(find.text('休止を解除'), findsOneWidget);
  });

  testWidgets('タブ変更を対応するURLへ同期する', (tester) async {
    final locations = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.navigation, (call) async {
      if (call.method == 'routeInformationUpdated') {
        final arguments = Map<Object?, Object?>.from(call.arguments as Map);
        locations.add(arguments['location']?.toString() ?? '');
      }
      return null;
    });

    await tester.pumpWidget(
      MaterialApp(
        home: HorseRacingPredictorPage(
          gateway: _FakeHorseRacingGateway(authenticated: false),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('購入馬券'));
    await tester.pumpAndSettle();

    expect(locations, contains('/horse-racing/bets'));
  });

  test('成績表示モデルは賭金正規化ROIとWilson信頼区間を計算する', () {
    final summary = HorseRacingPerformanceViewModel.from(
      accuracyStats: const {
        'total_results': 100,
        'correct_count': 45,
        'hit_rate_pct': 45.0,
        'average_predicted_probability_pct': 50.0,
      },
      betTickets: const [
        {
          'metadata': {
            'race_date': '2026-08-01',
            'total_amount': 2000,
            'payout_amount': 1500,
            'lines': [
              {'bet_type': '複勝', 'amount': 2000},
            ],
          },
        },
      ],
    );

    expect(summary.roiPercent, -25);
    expect(summary.calibrationGapPoints, 5);
    expect(summary.confidenceInterval, isNotNull);
    expect(summary.confidenceInterval!.lowerPercent, closeTo(35.6, 0.2));
    expect(summary.confidenceInterval!.upperPercent, closeTo(54.8, 0.2));
    expect(summary.rankingOnHold, isFalse);
  });
}

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
  Future<List<Map<String, dynamic>>> fetchBetTickets() async {
    return snapshot.betTickets;
  }

  @override
  Future<Map<String, dynamic>> runPredictions({
    required String date,
    required String raceType,
    String? raceId,
  }) async {
    return const {};
  }

  @override
  Future<void> refreshAccuracyLearning() async {}

  @override
  Future<Map<String, dynamic>> runLearningBackfill({
    required String dateTo,
  }) async {
    return const {};
  }

  @override
  Future<void> createBetTicket(Map<String, dynamic> metadata) async {}

  @override
  Future<void> settleBetTicket({
    required Object ticketId,
    required Map<String, dynamic> metadata,
  }) async {}
}
