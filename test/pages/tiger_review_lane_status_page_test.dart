import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/tiger_review_lane_status.dart';
import 'package:my_web_app/pages/tiger_review_lane_status_page.dart';

void main() {
  testWidgets('hub exposes four independent review lanes', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TigerReviewHubPage()));

    for (final lane in TigerReviewLane.values) {
      expect(find.byKey(Key('tiger-lane-${lane.lane}')), findsOneWidget);
    }
  });

  testWidgets('feature lane renders only feature standings', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TigerReviewLaneStatusPage(
          kind: TigerReviewLane.features,
          loader: () async => _status(
            lane: 'feature_review',
            entries: const <Map<String, dynamic>>[
              <String, dynamic>{
                'slug': 'home',
                'title': 'ホーム',
                'kind': 'page',
                'division': 3,
                'eligible': true,
                'completed_cycles': 1,
                'utility_score': 72.5,
              },
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('機能 1〜5部'), findsOneWidget);
    expect(find.text('ホーム'), findsOneWidget);
    expect(find.text('AI大学講座 1〜5部'), findsNothing);
    expect(find.text('虎レビュアー 1〜5部'), findsNothing);
  });

  testWidgets('course lane rejects a mismatched feature asset', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TigerReviewLaneStatusPage(
          kind: TigerReviewLane.courses,
          loader: () async => _status(lane: 'feature_review'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('公開データの系統が一致しません。'), findsOneWidget);
  });

  testWidgets('narrow lane reloads without a layout exception', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var loadCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: TigerReviewLaneStatusPage(
          kind: TigerReviewLane.features,
          loader: () async {
            loadCount += 1;
            return _status(lane: 'feature_review');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(loadCount, 1);

    await tester.tap(
      find.byKey(const Key('tiger-lane-refresh-feature_review')),
    );
    await tester.pumpAndSettle();

    expect(loadCount, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('history shows findings and countermeasure trace', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TigerReviewLaneStatusPage(
          kind: TigerReviewLane.features,
          loader: () async => _status(
            lane: 'feature_review',
            history: <TigerReviewHistoryEntry>[
              TigerReviewHistoryEntry(
                cycleId: 'cycle-1',
                startedAt: DateTime.utc(2026, 8, 23, 9),
                subject: const TigerReviewHistorySubject(
                  kind: 'feature',
                  id: 'home',
                  title: 'ホーム',
                ),
                reviewer: const TigerReviewHistoryReviewer(
                  seat: 7,
                  name: '榊原 清一',
                ),
                reviewStatus: 'fixed',
                validationStatus: 'passed',
                findings: const <TigerReviewHistoryFinding>[
                  TigerReviewHistoryFinding(
                    id: 'loading-state',
                    summary: '読み込み状態を通知する',
                    severity: 'p1',
                    suggestedAction: 'Semanticsを追加する',
                  ),
                ],
                countermeasure: const TigerCountermeasureTrace(
                  state: 'implemented',
                  label: '対策実施・検証済み',
                  detail: '個別の指摘IDとの紐付けも記録済みです。',
                  summary: 'Semanticsを追加した。',
                  files: <String>['lib/pages/home.dart'],
                  validationStatus: 'passed',
                  validationMessages: <String>['flutter test: passed'],
                  findingsWithoutIndividualTrace: <String>[],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('レビュー履歴・対策トレース'), findsOneWidget);
    expect(find.text('対策実施・検証済み'), findsOneWidget);
    expect(find.textContaining('読み込み状態を通知する'), findsOneWidget);
    expect(find.textContaining('flutter test: passed'), findsOneWidget);
  });
}

TigerReviewLaneStatus _status({
  required String lane,
  List<Map<String, dynamic>> entries = const <Map<String, dynamic>>[],
  List<TigerReviewHistoryEntry> history = const <TigerReviewHistoryEntry>[],
}) {
  return TigerReviewLaneStatus(
    schemaVersion: 3,
    lane: lane,
    generatedAt: DateTime.utc(2026, 8, 23),
    publicationState: 'latest_review',
    automation: const TigerLaneAutomation(
      id: 'test',
      name: 'test',
      status: 'ACTIVE',
      schedule: '1時間ごと',
    ),
    pool: const <String, dynamic>{
      'total': 1,
      'eligible': 1,
      'division_1': 0,
      'division_2': 0,
      'division_3': 1,
      'division_4': 0,
      'division_5': 0,
    },
    latest: null,
    history: history,
    entries: entries,
    disclaimer: 'simulation',
  );
}
