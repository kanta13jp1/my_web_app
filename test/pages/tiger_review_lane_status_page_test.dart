import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/tiger_review_lane_status.dart';
import 'package:my_web_app/models/tiger_reviewer_profile.dart';
import 'package:my_web_app/pages/tiger_review_lane_status_page.dart';

void main() {
  test('profile schema invalidates the browser asset cache', () {
    final uri = buildTigerReviewAssetUri(
      Uri.parse('https://example.com/tiger-reviewers'),
      'assets/data/tiger_reviewer_profiles.json',
      schemaVersion: tigerReviewerProfileSchemaVersion,
    );

    expect(tigerReviewerProfileSchemaVersion, 3);
    expect(tigerReviewStatusSchemaVersion, 4);
    expect(
      uri.toString(),
      'https://example.com/assets/assets/data/tiger_reviewer_profiles.json'
      '?review_status_schema=3',
    );
  });

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

  testWidgets('reviewer lane loads its bundled status without a boot error', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TigerReviewLaneStatusPage(kind: TigerReviewLane.reviewers),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();

    expect(
      find.byKey(const Key('tiger-lane-content-reviewer_league')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
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

  testWidgets(
    'reviewer lane expands age, business, and title on narrow screens',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: TigerReviewLaneStatusPage(
            kind: TigerReviewLane.reviewers,
            loader: () async => _status(
              lane: 'reviewer_league',
              entries: const <Map<String, dynamic>>[
                <String, dynamic>{
                  'seat': 21,
                  'name': '遠藤 悠記',
                  'division': 2,
                  'eligible': true,
                  'completed_cycles': 2,
                  'utility_score': 78.5,
                },
              ],
            ),
            profileLoader: () async => TigerReviewerProfileCatalog(
              schemaVersion: 2,
              snapshotDate: DateTime(2026, 8, 23),
              enrichmentRound: 1,
              averageProfileCompletenessPercent: 62.8,
              averageReviewReflectionPercent: 68,
              verifiedBirthDates: 1,
              nextBatchNames: const <String>['追加調査が必要な虎'],
              profilesBySeat: <int, TigerReviewerProfile>{
                21: TigerReviewerProfile(
                  seat: 21,
                  name: '遠藤 悠記',
                  rosterStatus: 'current',
                  birthDate: DateTime(1990, 3, 17),
                  companyRole: '株式会社えん代表',
                  businessSummary: '学習塾、美容エステサロン、顧問事業',
                  businessDomains: const <String>['教育・スクール'],
                  appearances: 64,
                  investmentCount: 17,
                  publicViewpointSummary: '最後は人情を重視する。',
                  profileUrl: Uri.parse(
                    'https://reiwanotora.jp/tiger/endo-yuki/',
                  ),
                  birthDateSourceUrl: Uri.parse(
                    'https://reiwanotora.jp/tiger/endo-yuki/',
                  ),
                  evidenceLinks: <TigerReviewerEvidenceLink>[
                    TigerReviewerEvidenceLink(
                      label: '肩書き・事業内容',
                      url: Uri.parse('https://example.com/company'),
                    ),
                    TigerReviewerEvidenceLink(
                      label: '公開された事業方針',
                      url: Uri.parse('https://example.com/policy'),
                    ),
                  ],
                  evidenceConfidence: 5,
                  profileCompletenessPercent: 100,
                  reviewReflectionPercent: 100,
                  reviewReflectionMode: 'profile_guided',
                  reviewApplicationRule: '確認済み観点を優先順位づけに反映します。',
                  reviewFocusLabels: const <String>['市場需要', '収益モデル'],
                  reviewQuestions: const <String>['実在する顧客は誰か。', '誰が何に支払うのか。'],
                  nextResearchTargets: const <String>['最新肩書きの再確認'],
                ),
              },
              disclaimer: '公開情報から構成したプロフィールです。',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final reviewerTile = find.byKey(const Key('tiger-reviewer_league-21'));
      await tester.scrollUntilVisible(
        reviewerTile,
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(reviewerTile);
      await tester.pumpAndSettle();

      expect(find.text('36歳（2026年8月23日時点）'), findsOneWidget);
      expect(find.text('株式会社えん代表'), findsOneWidget);
      expect(find.text('学習塾、美容エステサロン、顧問事業'), findsOneWidget);
      expect(find.text('教育・スクール'), findsOneWidget);
      expect(find.text('出演 64回・出資 17回'), findsOneWidget);
      expect(find.text('プロフィール拡充ループ 第1回'), findsOneWidget);
      expect(find.text('100%（確認済みプロフィール観点を強く反映）'), findsOneWidget);
      expect(find.text('市場需要・収益モデル'), findsOneWidget);
      expect(find.text('• 実在する顧客は誰か。'), findsOneWidget);
      expect(find.text('最新肩書きの再確認'), findsOneWidget);
      expect(find.byKey(const Key('tiger-profile-source-21')), findsOneWidget);
      expect(
        find.byKey(const Key('tiger-profile-source-21-1')),
        findsOneWidget,
      );
      expect(find.text('肩書き・事業内容の根拠を開く'), findsOneWidget);
      expect(find.text('公開された事業方針の根拠を開く'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

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
                countermeasure: TigerCountermeasureTrace(
                  state: 'implemented',
                  label: '対策実施・検証済み',
                  detail: '個別の指摘IDとの紐付けも記録済みです。',
                  summary: 'Semanticsを追加した。',
                  files: <String>['lib/pages/home.dart'],
                  validationStatus: 'passed',
                  validationMessages: <String>['flutter test: passed'],
                  findingsWithoutIndividualTrace: <String>[],
                  issue: TigerFollowUpIssue(
                    number: 4734,
                    url: Uri.parse(
                      'https://github.com/kanta13jp1/my_web_app/issues/4734',
                    ),
                    githubState: 'OPEN',
                  ),
                  implementation: null,
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
    expect(find.byKey(const Key('tiger-review-issue-4734')), findsOneWidget);
  });

  testWidgets('history shows reconciled remediation proof', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TigerReviewLaneStatusPage(
          kind: TigerReviewLane.features,
          loader: () async => _status(
            lane: 'feature_review',
            history: <TigerReviewHistoryEntry>[
              TigerReviewHistoryEntry(
                cycleId: 'cycle-remediated',
                startedAt: DateTime.utc(2026, 8, 28),
                subject: const TigerReviewHistorySubject(
                  kind: 'feature',
                  id: 'home',
                  title: 'ホーム',
                ),
                reviewer: const TigerReviewHistoryReviewer(
                  seat: 7,
                  name: '榊原 清一',
                ),
                reviewStatus: 'review_only',
                validationStatus: 'passed',
                findings: const <TigerReviewHistoryFinding>[],
                countermeasure: TigerCountermeasureTrace(
                  state: 'production_verified',
                  label: '対策済み・Issue #10 本番検証済み',
                  detail: 'Issue、commit、workflowを再同期しました。',
                  summary: '',
                  files: const <String>[],
                  validationStatus: 'passed',
                  validationMessages: const <String>[],
                  findingsWithoutIndividualTrace: const <String>[],
                  issue: TigerFollowUpIssue(
                    number: 10,
                    url: Uri.parse(
                      'https://github.com/kanta13jp1/my_web_app/issues/10',
                    ),
                    githubState: 'CLOSED',
                    remediationState: 'production_verified',
                  ),
                  implementation: const TigerReviewImplementation(
                    commitSha: 'abc1234',
                    workflowRun: '123',
                    productionUrl: null,
                    releaseStatus: 'passed',
                    prNumber: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('対策済み・Issue #10 本番検証済み'), findsOneWidget);
    expect(find.text('対策PR: #11'), findsOneWidget);
    expect(find.textContaining('対策反映コミット: abc1234'), findsOneWidget);
    expect(find.textContaining('対策反映workflow: 123'), findsOneWidget);
    expect(find.textContaining('対策済み・本番検証済み'), findsOneWidget);
  });

  testWidgets('superseded issue is not shown as remediated', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TigerReviewLaneStatusPage(
          kind: TigerReviewLane.features,
          loader: () async => _status(
            lane: 'feature_review',
            history: <TigerReviewHistoryEntry>[
              TigerReviewHistoryEntry(
                cycleId: 'cycle-superseded',
                startedAt: DateTime.utc(2026, 8, 28),
                subject: const TigerReviewHistorySubject(
                  kind: 'feature',
                  id: 'home',
                  title: 'ホーム',
                ),
                reviewer: const TigerReviewHistoryReviewer(
                  seat: 7,
                  name: '榊原 清一',
                ),
                reviewStatus: 'review_only',
                validationStatus: 'passed',
                findings: const <TigerReviewHistoryFinding>[],
                countermeasure: TigerCountermeasureTrace(
                  state: 'issue_superseded',
                  label: '統合済み・Issue #10 → #11',
                  detail: '重複Issueとして統合されました。',
                  summary: '',
                  files: const <String>[],
                  validationStatus: 'passed',
                  validationMessages: const <String>[],
                  findingsWithoutIndividualTrace: const <String>[],
                  issue: TigerFollowUpIssue(
                    number: 10,
                    url: Uri.parse(
                      'https://github.com/kanta13jp1/my_web_app/issues/10',
                    ),
                    githubState: 'CLOSED',
                    remediationState: 'superseded',
                  ),
                  implementation: null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('統合済み・Issue #10 → #11'), findsOneWidget);
    expect(find.textContaining('重複統合済み・修正完了ではありません'), findsOneWidget);
    expect(find.textContaining('対策済み・本番検証済み'), findsNothing);
  });

  testWidgets('site history remains visible when the lane has no standings', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TigerReviewLaneStatusPage(
          kind: TigerReviewLane.site,
          loader: () async => _status(
            lane: 'site_review',
            history: <TigerReviewHistoryEntry>[_historyEntry()],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('レビュー履歴・対策トレース'), findsOneWidget);
    expect(find.text('サイト全体の虎レビュー 1〜5部'), findsNothing);
  });
}

TigerReviewHistoryEntry _historyEntry() {
  return TigerReviewHistoryEntry(
    cycleId: 'site-cycle-1',
    startedAt: DateTime.utc(2026, 8, 23, 9),
    subject: const TigerReviewHistorySubject(
      kind: 'site',
      id: 'comparison',
      title: '競合比較',
    ),
    reviewer: const TigerReviewHistoryReviewer(seat: 7, name: '榊原 清一'),
    reviewStatus: 'review_only',
    validationStatus: 'passed',
    findings: const <TigerReviewHistoryFinding>[],
    countermeasure: const TigerCountermeasureTrace(
      state: 'issue_tracking',
      label: '未対策・Issue #4739 追跡中',
      detail: '',
      summary: '',
      files: <String>[],
      validationStatus: 'passed',
      validationMessages: <String>[],
      findingsWithoutIndividualTrace: <String>[],
      issue: null,
      implementation: null,
    ),
  );
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
