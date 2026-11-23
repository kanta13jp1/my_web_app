import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/project_gantt_page.dart';
import 'package:my_web_app/services/project_gantt_focus_view_service.dart';
import 'package:my_web_app/widgets/project_gantt_focus_views.dart';

WbsTask _sampleTask({
  required String id,
  required String title,
  String status = 'pending',
  int progress = 0,
  String priority = 'medium',
  DateTime? plannedStartDate,
  DateTime? plannedEndDate,
  String? milestoneCode,
  List<String> dependsOnTitles = const <String>[],
  int? githubIssueNumber,
  String recoveryPlan = '',
}) {
  return WbsTask(
    id: id,
    category: '開発',
    categoryIcon: '🛠️',
    categoryOrder: 1,
    title: title,
    description: '',
    instance: 'codex',
    status: status,
    progress: progress,
    plannedStartDate: plannedStartDate,
    plannedEndDate: plannedEndDate,
    milestoneCode: milestoneCode,
    priority: priority,
    ownerInstance: 'codex',
    dependsOnTitles: dependsOnTitles,
    githubIssueNumber: githubIssueNumber,
    recoveryPlan: recoveryPlan,
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

  group('ProjectGantt focus views widget & a11y', () {
    Future<void> pumpFocusHarness(
      WidgetTester tester, {
      required Size viewport,
      required List<WbsTask> tasks,
      required List<WbsMilestone> milestones,
    }) async {
      tester.view.physicalSize = viewport;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var selected = ProjectGanttFocusView.wbs;
      await tester.pumpWidget(
        MaterialApp(
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

    testWidgets('switches all 4 focus views on desktop and mobile',
        (tester) async {
      final tasks = [
        _sampleTask(
          id: 't1',
          title: 'スプリント主課題',
          status: 'in_progress',
          progress: 55,
          plannedStartDate: DateTime(2026, 11, 23),
          plannedEndDate: DateTime(2026, 11, 29),
          milestoneCode: 'v1.1',
          githubIssueNumber: 2230,
        ),
        _sampleTask(
          id: 't2',
          title: '後続リリース作業',
          status: 'pending',
          progress: 0,
          milestoneCode: 'v1.1',
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

      for (final size in const [Size(1280, 900), Size(390, 844)]) {
        await pumpFocusHarness(
          tester,
          viewport: size,
          tasks: tasks,
          milestones: milestones,
        );

        expect(find.text('開発WBS本体'), findsOneWidget);

        await tester.tap(find.byKey(const Key('gantt_focus_view_sprint')));
        await tester.pumpAndSettle();
        expect(find.byType(ProjectGanttSprintView), findsOneWidget);
        expect(find.text('スプリント主課題'), findsOneWidget);

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

        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('meets accessibility tap target and label guidelines',
        (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      addTearDown(handle.dispose);

      await pumpFocusHarness(
        tester,
        viewport: const Size(390, 844),
        tasks: const <WbsTask>[],
        milestones: const <WbsMilestone>[],
      );

      await tester.tap(find.byKey(const Key('gantt_focus_view_sprint')));
      await tester.pumpAndSettle();
      expect(
        find.text('今スプリント期間に該当する未完了のWBSタスクはありません。'),
        findsOneWidget,
      );

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      expect(tester.takeException(), isNull);
    });
  });
}
