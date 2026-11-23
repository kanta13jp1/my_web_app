import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/project_gantt_page.dart';
import 'package:my_web_app/services/project_gantt_focus_view_service.dart';
import 'package:my_web_app/widgets/project_gantt_focus_views.dart';

WbsTask _sampleTask({
  required String id,
  required String title,
  String category = '開発',
  String description = '',
  String status = 'pending',
  int progress = 0,
  String priority = 'medium',
  DateTime? plannedStartDate,
  DateTime? plannedEndDate,
  String? milestoneCode,
  String ownerInstance = 'codex',
  List<String> dependsOnTitles = const <String>[],
  int? githubIssueNumber,
  String githubIssueState = '',
  String githubIssueUrl = '',
  String recoveryPlan = '',
  int rescheduledCount = 0,
  String remainingWork = '',
}) {
  return WbsTask(
    id: id,
    category: category,
    categoryIcon: '🛠️',
    categoryOrder: 1,
    title: title,
    description: description,
    instance: ownerInstance,
    status: status,
    progress: progress,
    plannedStartDate: plannedStartDate,
    plannedEndDate: plannedEndDate,
    milestoneCode: milestoneCode,
    priority: priority,
    ownerInstance: ownerInstance,
    dependsOnTitles: dependsOnTitles,
    githubIssueNumber: githubIssueNumber,
    githubIssueState: githubIssueState,
    githubIssueUrl: githubIssueUrl,
    recoveryPlan: recoveryPlan,
    rescheduledCount: rescheduledCount,
    remainingWork: remainingWork,
  );
}

void main() {
  final fixedNow = DateTime(2026, 11, 25, 10);

  group('ProjectGanttFocusViewService (#2230 #2231 #2233)', () {
    test('buildSprintSummary selects current week, overdue, and active tasks',
        () {
      final overdue = _sampleTask(
        id: 't1',
        title: '遅延タスク',
        status: 'pending',
        progress: 20,
        plannedStartDate: DateTime(2026, 11, 10),
        plannedEndDate: DateTime(2026, 11, 20),
      );
      final inWindow = _sampleTask(
        id: 't2',
        title: '今週スプリント課題',
        status: 'in_progress',
        progress: 60,
        plannedStartDate: DateTime(2026, 11, 24),
        plannedEndDate: DateTime(2026, 11, 28),
      );
      final future = _sampleTask(
        id: 't3',
        title: '来月課題',
        status: 'pending',
        progress: 0,
        plannedStartDate: DateTime(2026, 12, 10),
        plannedEndDate: DateTime(2026, 12, 20),
      );
      final doneThisWeek = _sampleTask(
        id: 't4',
        title: '完了済み今週課題',
        status: 'completed',
        progress: 100,
        plannedStartDate: DateTime(2026, 11, 23),
        plannedEndDate: DateTime(2026, 11, 24),
      );

      final summary = ProjectGanttFocusViewService.buildSprintSummary(
        [future, inWindow, doneThisWeek, overdue],
        now: fixedNow,
      );

      expect(summary.activeTasks.map((t) => t.id), ['t1', 't2']);
      expect(summary.overdueCount, 1);
      expect(summary.inProgressCount, 1);
      expect(summary.completedInWindowTasks.map((t) => t.id), ['t4']);
      expect(summary.averageProgress, 40.0);
    });

    test('buildMilestoneSummaries calculates completion rates and unassigned',
        () {
      final milestones = [
        WbsMilestone(
          code: 'v1.1',
          name: 'スプリント機能公開',
          targetDate: DateTime(2026, 12, 1),
          goalUsers: 10,
          description: '',
          color: const Color(0xFFFF6B35),
        ),
      ];
      final tasks = [
        _sampleTask(
          id: 'm1',
          title: '完了課題',
          status: 'completed',
          progress: 100,
          milestoneCode: 'v1.1',
        ),
        _sampleTask(
          id: 'm2',
          title: '進行課題',
          status: 'in_progress',
          progress: 50,
          milestoneCode: 'v1.1',
        ),
        _sampleTask(
          id: 'u1',
          title: '未割当課題',
          status: 'pending',
          progress: 0,
        ),
      ];

      final groups = ProjectGanttFocusViewService.buildMilestoneSummaries(
        milestones,
        tasks,
        now: fixedNow,
      );

      expect(groups.length, 2);
      expect(groups.first.milestone?.code, 'v1.1');
      expect(groups.first.completedCount, 1);
      expect(groups.first.inProgressCount, 1);
      expect(groups.first.completionRate, 0.5);
      expect(groups.first.isAtRisk, isTrue);
      expect(groups.last.milestone, isNull);
      expect(groups.last.tasks.map((t) => t.id), ['u1']);
    });

    test('buildBlockerItems detects dependency title and #issue blockers', () {
      final rootBlocker = _sampleTask(
        id: 'b1',
        title: '[Issue #2230] API基盤整備',
        status: 'in_progress',
        githubIssueNumber: 2230,
      );
      final waiterByTitle = _sampleTask(
        id: 'w1',
        title: 'UI統合',
        dependsOnTitles: const ['API基盤整備'],
      );
      final waiterByIssue = _sampleTask(
        id: 'w2',
        title: 'E2E検証',
        dependsOnTitles: const ['#2230'],
      );
      final explicitBlocked = _sampleTask(
        id: 'b2',
        title: '手動承認待ち',
        status: 'blocked',
        recoveryPlan: 'レビュー完了待ち',
      );
      final completed = _sampleTask(
        id: 'done',
        title: '完了済み前提',
        status: 'completed',
        progress: 100,
      );

      final items = ProjectGanttFocusViewService.buildBlockerItems(
        [waiterByTitle, explicitBlocked, rootBlocker, waiterByIssue, completed],
      );

      expect(items.length, 2);
      expect(items.first.task.id, 'b1');
      expect(
        items.first.downstreamBlockedTasks.map((t) => t.id),
        containsAll(['w1', 'w2']),
      );
      expect(items.last.task.id, 'b2');
      expect(items.last.hasExplicitBlockedStatus, isTrue);
      expect(items.last.hasRecoveryPlan, isTrue);
    });

    test('buildBlockerItems returns empty list when no blockers exist', () {
      final clean = [
        _sampleTask(id: 'c1', title: '通常タスク', status: 'in_progress'),
      ];
      expect(ProjectGanttFocusViewService.buildBlockerItems(clean), isEmpty);
    });
  });

  group('ProjectGanttFocusViewService phase 2 (#2234 #2237 #2242)', () {
    test(
        'buildOwnerGroups aggregates incomplete, completed, and overdue by owner',
        () {
      final tasks = [
        _sampleTask(
          id: 'o1',
          title: 'Codex期限超過課題',
          ownerInstance: 'codex',
          status: 'in_progress',
          progress: 40,
          plannedEndDate: DateTime(2026, 11, 20),
        ),
        _sampleTask(
          id: 'o2',
          title: 'Codex完了課題',
          ownerInstance: 'codex',
          status: 'completed',
          progress: 100,
        ),
        _sampleTask(
          id: 'o3',
          title: 'Claude進行中1',
          ownerInstance: 'claude',
          status: 'in_progress',
          progress: 60,
        ),
        _sampleTask(
          id: 'o4',
          title: 'Claude未着手2',
          ownerInstance: 'claude',
          status: 'pending',
          progress: 0,
        ),
      ];

      final groups = ProjectGanttFocusViewService.buildOwnerGroups(
        tasks,
        now: fixedNow,
      );

      expect(groups.length, 2);
      expect(groups.first.ownerKey, 'claude');
      expect(groups.first.incompleteCount, 2);
      expect(groups.first.averageProgress, 30.0);
      expect(groups.last.ownerKey, 'codex');
      expect(groups.last.overdueCount, 1);
      expect(groups.last.completedCount, 1);
    });

    test(
        'buildProgressDashboard computes counts, overdue, blockers, categories',
        () {
      final tasks = [
        _sampleTask(
          id: 'd1',
          title: '完了項目',
          category: 'UI',
          status: 'completed',
          progress: 100,
          priority: 'high',
        ),
        _sampleTask(
          id: 'd2',
          title: 'ブロック前提',
          category: 'API',
          status: 'in_progress',
          progress: 50,
          githubIssueNumber: 2237,
          plannedEndDate: DateTime(2026, 11, 20),
        ),
        _sampleTask(
          id: 'd3',
          title: '後続待機',
          category: 'UI',
          status: 'pending',
          progress: 0,
          dependsOnTitles: const <String>['#2237'],
        ),
      ];

      final summary = ProjectGanttFocusViewService.buildProgressDashboard(
        tasks,
        now: fixedNow,
      );

      expect(summary.totalCount, 3);
      expect(summary.completedCount, 1);
      expect(summary.incompleteCount, 2);
      expect(summary.overdueCount, 1);
      expect(summary.blockerCount, 1);
      expect(summary.categoryCounts['UI'], 2);
      expect(summary.categoryCounts['API'], 1);
    });

    test('buildTechDebtItems extracts explicit debt/rescheduled without noise',
        () {
      final tasks = [
        _sampleTask(
          id: 'td1',
          title: '認証周りリファクタリング',
          description: '技術的負債として分割',
          status: 'pending',
          remainingWork: '単体テスト分離',
        ),
        _sampleTask(
          id: 'td2',
          title: '再計画タスク',
          rescheduledCount: 2,
          recoveryPlan: 'テスト分割で対応',
        ),
        _sampleTask(
          id: 'normal',
          title: '通常の低優先度機能',
          priority: 'low',
          status: 'pending',
        ),
        _sampleTask(
          id: 'doneDebt',
          title: '完了済みリファクタ',
          status: 'completed',
          progress: 100,
        ),
      ];

      final items = ProjectGanttFocusViewService.buildTechDebtItems(tasks);
      expect(items.map((e) => e.task.id), <String>['td2', 'td1']);
      expect(items.first.isRescheduled, isTrue);
      expect(items.last.classificationReason, contains('リファクタ'));
    });

    test('buildGitHubIssueLinkSummary groups open, closed, and unlinked tasks',
        () {
      final tasks = [
        _sampleTask(
          id: 'gh1',
          title: 'Open linked issue',
          githubIssueNumber: 2235,
          githubIssueState: 'OPEN',
        ),
        _sampleTask(
          id: 'gh2',
          title: 'Closed linked issue',
          status: 'completed',
          progress: 100,
          githubIssueNumber: 2230,
          githubIssueState: 'CLOSED',
        ),
        _sampleTask(
          id: 'gh3',
          title: 'Local WBS only',
        ),
      ];

      final summary =
          ProjectGanttFocusViewService.buildGitHubIssueLinkSummary(tasks);
      expect(summary.linkedTasks.map((t) => t.id), <String>['gh2', 'gh1']);
      expect(summary.openIssueTasks.map((t) => t.id), <String>['gh1']);
      expect(summary.closedIssueTasks.map((t) => t.id), <String>['gh2']);
      expect(summary.unlinkedTasks.map((t) => t.id), <String>['gh3']);
    });

    test(
        'buildRiskSummary reuses milestone warnings, flags load failure, and scores tasks',
        () {
      final tasks = [
        _sampleTask(
          id: 'r1',
          title: '仕様未確定のまま遅延中の課題',
          priority: 'p0',
          plannedEndDate: DateTime(2026, 11, 20),
          rescheduledCount: 2,
          dependsOnTitles: const <String>['#2230'],
        ),
        _sampleTask(
          id: 'r2',
          title: '正常進行タスク',
          priority: 'low',
          plannedEndDate: DateTime(2026, 12, 20),
        ),
      ];
      final summary = ProjectGanttFocusViewService.buildRiskSummary(
        tasks,
        milestoneRisks: const <Map<String, dynamic>>[
          <String, dynamic>{
            'milestone_code': 'v1.1',
            'risk_status': 'over_capacity',
          },
          <String, dynamic>{
            'milestone_code': 'v1.2',
            'risk_status': 'healthy',
          },
        ],
        milestoneRiskLoadFailed: true,
        now: fixedNow,
      );

      expect(summary.milestoneRiskLoadFailed, isTrue);
      expect(summary.milestoneWarnings, hasLength(1));
      expect(summary.taskRisks.map((e) => e.task.id), <String>['r1']);
      expect(summary.taskRisks.first.severity, 'high');
      expect(
        summary.taskRisks.first.reasons,
        containsAll(<String>['期限超過 (5日)', '遅延＋復旧計画未記入', '再計画 2回']),
      );
    });

    test(
        'buildTestTargetSummary separates explicit test scope and unevaluated tasks',
        () {
      final tasks = [
        _sampleTask(
          id: 'tt1',
          title: 'FocusView 単体テストとE2E検証',
          priority: 'p1',
        ),
        _sampleTask(
          id: 'tt2',
          title: '未評価のまま残っている実装タスク',
          priority: 'p0',
          githubIssueNumber: 2241,
        ),
        _sampleTask(
          id: 'ttDone',
          title: '完了済み項目',
          status: 'completed',
          progress: 100,
        ),
      ];

      final summary =
          ProjectGanttFocusViewService.buildTestTargetSummary(tasks);
      expect(summary.explicitTestItems.map((e) => e.task.id), <String>['tt1']);
      expect(summary.unevaluatedItems.map((e) => e.task.id), <String>['tt2']);
      expect(summary.unevaluatedItems.first.evaluationLabel, contains('未評価'));
    });
  });

  group('ProjectGantt focus views widget & a11y', () {
    Future<void> pumpFocusHarness(
      WidgetTester tester, {
      required Size viewport,
      required List<WbsTask> tasks,
      required List<WbsMilestone> milestones,
      List<Map<String, dynamic>> milestoneRisks =
          const <Map<String, dynamic>>[],
      bool milestoneRiskLoadFailed = false,
    }) async {
      tester.view.physicalSize = viewport;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var selected = ProjectGanttFocusView.wbs;
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey<Size>(viewport),
          theme: ThemeData.dark(),
          home: Scaffold(
            backgroundColor: const Color(0xFF0A0A0A),
            body: StatefulBuilder(
              builder: (context, setState) {
                final sprint = ProjectGanttFocusViewService.buildSprintSummary(
                  tasks,
                  now: fixedNow,
                );
                final msGroups =
                    ProjectGanttFocusViewService.buildMilestoneSummaries(
                  milestones,
                  tasks,
                  now: fixedNow,
                );
                final blockers =
                    ProjectGanttFocusViewService.buildBlockerItems(tasks);
                final ownerGroups =
                    ProjectGanttFocusViewService.buildOwnerGroups(
                  tasks,
                  now: fixedNow,
                );
                final dashboard =
                    ProjectGanttFocusViewService.buildProgressDashboard(
                  tasks,
                  now: fixedNow,
                );
                final techDebt =
                    ProjectGanttFocusViewService.buildTechDebtItems(tasks);
                final issueLinkSummary =
                    ProjectGanttFocusViewService.buildGitHubIssueLinkSummary(
                  tasks,
                );
                final riskSummary =
                    ProjectGanttFocusViewService.buildRiskSummary(
                  tasks,
                  milestoneRisks: milestoneRisks,
                  milestoneRiskLoadFailed: milestoneRiskLoadFailed,
                  now: fixedNow,
                );
                final testTargetSummary =
                    ProjectGanttFocusViewService.buildTestTargetSummary(tasks);
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ProjectGanttFocusViewBar(
                        selectedView: selected,
                        onSelect: (v) => setState(() => selected = v),
                        sprintCount: sprint.activeTasks.length,
                        milestoneCount: milestones.length,
                        blockerCount: blockers.length,
                        ownerCount: ownerGroups.length,
                        dashboardCount: tasks.length,
                        techDebtCount: techDebt.length,
                        githubIssueCount: issueLinkSummary.linkedTasks.length,
                        riskCount: riskSummary.totalRiskCount,
                        testTargetCount: testTargetSummary.totalCount,
                      ),
                      const SizedBox(height: 12),
                      switch (selected) {
                        ProjectGanttFocusView.wbs => const Text('開発WBS本体'),
                        ProjectGanttFocusView.sprint =>
                          ProjectGanttSprintView(data: sprint),
                        ProjectGanttFocusView.milestone =>
                          ProjectGanttMilestoneView(groups: msGroups),
                        ProjectGanttFocusView.blocker =>
                          ProjectGanttBlockerView(items: blockers),
                        ProjectGanttFocusView.owner =>
                          ProjectGanttOwnerView(groups: ownerGroups),
                        ProjectGanttFocusView.dashboard =>
                          ProjectGanttProgressDashboardView(summary: dashboard),
                        ProjectGanttFocusView.techDebt =>
                          ProjectGanttTechDebtView(items: techDebt),
                        ProjectGanttFocusView.githubIssues =>
                          ProjectGanttGitHubIssueView(
                              summary: issueLinkSummary),
                        ProjectGanttFocusView.risk =>
                          ProjectGanttRiskView(summary: riskSummary),
                        ProjectGanttFocusView.testTargets =>
                          ProjectGanttTestTargetView(
                            summary: testTargetSummary,
                          ),
                      },
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('switches all 10 focus views on desktop and mobile',
        (tester) async {
      final tasks = [
        _sampleTask(
          id: 't1',
          title: 'スプリント主課題 (技術的負債解消)',
          status: 'in_progress',
          progress: 55,
          plannedStartDate: DateTime(2026, 11, 23),
          plannedEndDate: DateTime(2026, 11, 29),
          milestoneCode: 'v1.1',
          ownerInstance: 'codex',
          githubIssueNumber: 2230,
          githubIssueState: 'OPEN',
        ),
        _sampleTask(
          id: 't2',
          title: '後続リリース作業',
          status: 'pending',
          progress: 0,
          priority: 'p0',
          plannedEndDate: DateTime(2026, 11, 20),
          milestoneCode: 'v1.1',
          ownerInstance: 'claude',
          dependsOnTitles: const ['#2230'],
        ),
      ];
      final milestones = [
        WbsMilestone(
          code: 'v1.1',
          name: 'フォーカスビュー公開',
          targetDate: DateTime(2026, 11, 30),
          goalUsers: 5,
          description: '',
          color: const Color(0xFFFF6B35),
        ),
      ];
      const risks = <Map<String, dynamic>>[
        <String, dynamic>{
          'milestone_code': 'v1.1',
          'risk_status': 'tight',
        },
      ];

      for (final size in const [Size(1280, 900), Size(390, 844)]) {
        await pumpFocusHarness(
          tester,
          viewport: size,
          tasks: tasks,
          milestones: milestones,
          milestoneRisks: risks,
          milestoneRiskLoadFailed: true,
        );

        expect(find.text('開発WBS本体'), findsOneWidget);

        await tester.ensureVisible(
          find.byKey(const Key('gantt_focus_view_sprint')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('gantt_focus_view_sprint')));
        await tester.pumpAndSettle();
        expect(find.byType(ProjectGanttSprintView), findsOneWidget);
        expect(find.text('スプリント主課題 (技術的負債解消)'), findsOneWidget);

        await tester.ensureVisible(
          find.byKey(const Key('gantt_focus_view_milestone')),
        );
        await tester.tap(find.byKey(const Key('gantt_focus_view_milestone')));
        await tester.pumpAndSettle();
        expect(find.byType(ProjectGanttMilestoneView), findsOneWidget);
        expect(find.text('v1.1: フォーカスビュー公開'), findsOneWidget);

        await tester.ensureVisible(
          find.byKey(const Key('gantt_focus_view_blocker')),
        );
        await tester.tap(find.byKey(const Key('gantt_focus_view_blocker')));
        await tester.pumpAndSettle();
        expect(find.byType(ProjectGanttBlockerView), findsOneWidget);
        expect(find.text('1件をブロック中'), findsOneWidget);
        expect(find.text('後続リリース作業'), findsOneWidget);

        await tester.ensureVisible(
          find.byKey(const Key('gantt_focus_view_owner')),
        );
        await tester.tap(find.byKey(const Key('gantt_focus_view_owner')));
        await tester.pumpAndSettle();
        expect(find.byType(ProjectGanttOwnerView), findsOneWidget);
        expect(
          find.byKey(const Key('gantt_owner_group_codex')),
          findsOneWidget,
        );

        await tester.ensureVisible(
          find.byKey(const Key('gantt_focus_view_dashboard')),
        );
        await tester.tap(find.byKey(const Key('gantt_focus_view_dashboard')));
        await tester.pumpAndSettle();
        expect(
          find.byType(ProjectGanttProgressDashboardView),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('gantt_progress_dashboard_card')),
          findsOneWidget,
        );

        await tester.ensureVisible(
          find.byKey(const Key('gantt_focus_view_tech_debt')),
        );
        await tester.tap(find.byKey(const Key('gantt_focus_view_tech_debt')));
        await tester.pumpAndSettle();
        expect(find.byType(ProjectGanttTechDebtView), findsOneWidget);
        expect(
          find.byKey(const Key('gantt_tech_debt_card_t1')),
          findsOneWidget,
        );

        await tester.ensureVisible(
          find.byKey(const Key('gantt_focus_view_github_issues')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('gantt_focus_view_github_issues')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ProjectGanttGitHubIssueView), findsOneWidget);
        expect(find.byKey(const Key('gantt_github_issue_card_t1')),
            findsOneWidget);
        await tester.ensureVisible(
          find.byKey(const Key('gantt_github_filter_unlinked')),
        );
        await tester.tap(find.byKey(const Key('gantt_github_filter_unlinked')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('gantt_github_issue_card_t2')),
            findsOneWidget);
        expect(
            find.byKey(const Key('gantt_github_issue_card_t1')), findsNothing);

        await tester.ensureVisible(
          find.byKey(const Key('gantt_focus_view_risk')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('gantt_focus_view_risk')));
        await tester.pumpAndSettle();
        expect(find.byType(ProjectGanttRiskView), findsOneWidget);
        expect(find.byKey(const Key('gantt_risk_load_error_banner')),
            findsOneWidget);
        expect(find.byKey(const Key('gantt_milestone_risk_0')), findsOneWidget);
        expect(find.byKey(const Key('gantt_risk_card_t2')), findsOneWidget);

        await tester.ensureVisible(
          find.byKey(const Key('gantt_focus_view_test_targets')),
        );
        await tester.pumpAndSettle();
        await tester
            .tap(find.byKey(const Key('gantt_focus_view_test_targets')));
        await tester.pumpAndSettle();
        expect(find.byType(ProjectGanttTestTargetView), findsOneWidget);
        expect(
            find.byKey(const Key('gantt_test_target_card_t2')), findsOneWidget);

        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('meets accessibility tap target and label guidelines',
        (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        await pumpFocusHarness(
          tester,
          viewport: const Size(390, 844),
          tasks: <WbsTask>[
            _sampleTask(
              id: 'a11y1',
              title: '連携済み課題',
              githubIssueNumber: 2235,
              githubIssueState: 'OPEN',
            ),
          ],
          milestones: const <WbsMilestone>[],
        );

        await tester.ensureVisible(
          find.byKey(const Key('gantt_focus_view_github_issues')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('gantt_focus_view_github_issues')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ProjectGanttGitHubIssueView), findsOneWidget);

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        expect(tester.takeException(), isNull);
      } finally {
        handle.dispose();
      }
    });
  });
}
