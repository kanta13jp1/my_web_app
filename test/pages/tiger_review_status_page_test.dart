import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/tiger_review_status.dart';
import 'package:my_web_app/pages/tiger_review_status_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows current reviewer and filters eliminated Tigers', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1180, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: TigerReviewStatusPage(loader: () async => _snapshot())),
    );
    await tester.pumpAndSettle();

    expect(find.text('機能・講座・虎 5部リーグ'), findsOneWidget);
    expect(find.text('最新レビュー'), findsOneWidget);
    expect(find.text('虎A（席1）'), findsOneWidget);
    expect(find.text('サイト機能 1〜5部'), findsOneWidget);
    expect(
      find.byKey(const Key('tiger-reviewed-feature-home')),
      findsOneWidget,
    );
    expect(find.text('3名を表示'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final division5Filter =
        find.byKey(const Key('tiger-review-filter-division_5'));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1400));
    await tester.pumpAndSettle();
    await tester.ensureVisible(division5Filter);
    await tester.tap(division5Filter);
    await tester.pump();

    expect(find.text('1名を表示'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('tiger-reviewer-3')),
      400,
    );
    expect(find.byKey(const Key('tiger-reviewer-3')), findsOneWidget);
    expect(find.byKey(const Key('tiger-reviewer-1')), findsNothing);
  });

  testWidgets('uses a single-column mobile layout without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: TigerReviewStatusPage(loader: () async => _snapshot())),
    );
    await tester.pumpAndSettle();

    expect(find.text('1部'), findsWidgets);
    expect(find.text('1〜5部の配属ルール'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reload action fetches a fresh snapshot', (tester) async {
    var loadCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: TigerReviewStatusPage(
          loader: () async {
            loadCount += 1;
            return _snapshot();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(loadCount, 1);

    await tester.tap(find.byKey(const Key('tiger-review-refresh')));
    await tester.pumpAndSettle();
    expect(loadCount, 2);
  });
}

TigerReviewStatusSnapshot _snapshot() {
  return TigerReviewStatusSnapshot(
    schemaVersion: 1,
    generatedAt: DateTime(2026, 8, 23, 13),
    publicationState: 'latest_cycle',
    automation: const TigerReviewAutomation(
      id: '125',
      name: '虎レビュー',
      status: 'ACTIVE',
      schedule: '1時間ごと',
    ),
    pool: const TigerReviewPool(
      total: 3,
      eligible: 2,
      provisional: 1,
      division1: 1,
      division2: 0,
      division3: 1,
      division4: 0,
      division5: 1,
      eliminated: 1,
      minimumEligiblePool: 12,
    ),
    coursePool: const TigerReviewPool(
      total: 1,
      eligible: 1,
      provisional: 1,
      division1: 0,
      division2: 0,
      division3: 1,
      division4: 0,
      division5: 0,
      eliminated: 0,
      minimumEligiblePool: 0,
    ),
    featurePool: const TigerReviewPool(
      total: 2,
      eligible: 1,
      provisional: 1,
      division1: 0,
      division2: 0,
      division3: 1,
      division4: 0,
      division5: 1,
      eliminated: 1,
      minimumEligiblePool: 0,
    ),
    latestCycle: TigerReviewCycle(
      cycleId: 'cycle-1',
      startedAt: DateTime(2026, 8, 23, 12),
      surfaceSlug: 'landing',
      surfaceUrl: 'https://example.test/',
      reviewerSeat: 1,
      reviewerName: '虎A',
      selectionScore: 82,
      cycleUtility: 78,
      aggregateUtility: 76,
      tier: 'active',
      division: 1,
      courseReview: const TigerCourseReviewCycle(
        contentId: 'course-1',
        provider: 'openai',
        title: 'APIの基本',
        sourceUrl: 'https://example.test/course-1',
        cycleUtility: 76,
        aggregateUtility: 76,
        division: 3,
        reason: '実践課題を確認',
      ),
      featureReview: const TigerFeatureReviewCycle(
        slug: 'home',
        title: 'ホーム',
        kind: 'page',
        cycleUtility: 72,
        aggregateUtility: 72,
        division: 3,
        reason: '利用価値と事業導線を確認',
      ),
      status: 'review_only',
      validation: 'not_applicable',
      findingCount: 1,
      topFindings: const <TigerReviewFinding>[
        TigerReviewFinding(
          summary: '収益導線を明確にする',
          severity: 'p1',
          businessDimensions: <String>['revenue_model'],
        ),
      ],
    ),
    reviewers: const <TigerReviewerStanding>[
      TigerReviewerStanding(
        seat: 1,
        name: '虎A',
        tier: 'active',
        division: 1,
        provisional: false,
        eligible: true,
        floorProtected: false,
        utilityScore: 76,
        completedCycles: 3,
        lowUtilityStreak: 0,
        lastCycleUtility: 78,
        lastSelectedAt: null,
        reason: '成果基準を達成',
      ),
      TigerReviewerStanding(
        seat: 2,
        name: '虎B',
        tier: 'challenger',
        division: 3,
        provisional: true,
        eligible: true,
        floorProtected: false,
        utilityScore: null,
        completedCycles: 0,
        lowUtilityStreak: 0,
        lastCycleUtility: null,
        lastSelectedAt: null,
        reason: '評価期間中',
      ),
      TigerReviewerStanding(
        seat: 3,
        name: '虎C',
        tier: 'eliminated',
        division: 5,
        provisional: false,
        eligible: false,
        floorProtected: false,
        utilityScore: 31,
        completedCycles: 2,
        lowUtilityStreak: 2,
        lastCycleUtility: 28,
        lastSelectedAt: null,
        reason: '低効用が2回連続',
      ),
    ],
    courses: const <TigerReviewedCourse>[
      TigerReviewedCourse(
        contentId: 'course-1',
        provider: 'openai',
        title: 'APIの基本',
        sourceUrl: 'https://example.test/course-1',
        division: 3,
        provisional: true,
        eligible: true,
        utilityScore: 76,
        completedCycles: 1,
        lastCycleUtility: 76,
        lastReviewedAt: null,
        reason: '講座レビュー実績が2回未満のため暫定3部',
      ),
    ],
    features: const <TigerReviewedFeature>[
      TigerReviewedFeature(
        slug: 'home',
        title: 'ホーム',
        kind: 'page',
        path: '/',
        source: 'lib/pages/home_dashboard_page.dart',
        priority: 'high',
        division: 3,
        provisional: true,
        eligible: true,
        utilityScore: 72,
        completedCycles: 1,
        lastCycleUtility: 72,
        lastReviewedAt: null,
        reason: '機能レビュー実績が2回未満のため暫定3部',
      ),
      TigerReviewedFeature(
        slug: 'legacy',
        title: '旧機能',
        kind: 'page',
        path: '/legacy',
        source: 'lib/pages/legacy_page.dart',
        priority: 'low',
        division: 5,
        provisional: false,
        eligible: false,
        utilityScore: 25,
        completedCycles: 2,
        lastCycleUtility: 20,
        lastReviewedAt: null,
        reason: '機能レビュー2回・効用25.0点で5部（次回候補外）',
      ),
    ],
    disclaimer: '本人による実レビューではありません。',
  );
}
