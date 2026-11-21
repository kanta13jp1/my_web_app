import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/project_gantt_page.dart';

WbsTask _sampleTask() {
  return const WbsTask(
    id: 'task-1',
    category: 'UI改善',
    categoryIcon: 'code',
    categoryOrder: 1,
    title: 'サンプルタスク',
    description: '',
    instance: 'claude',
    status: 'in_progress',
    progress: 50,
    priority: 'medium',
    ownerInstance: 'claude',
    remainingWork: '',
  );
}

void main() {
  group('GanttTimelineTab empty filter state', () {
    testWidgets('keeps filter bar mounted when filtered to 0', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      String? filterInstance = 'unassigned';
      var hideCompleted = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GanttTimelineTab(
              milestones: const [],
              tasks: [_sampleTask()],
              loading: false,
              hideCompleted: hideCompleted,
              onToggleHideCompleted: (v) => hideCompleted = v ?? false,
              filterInstance: filterInstance,
              onFilterInstance: (v) => filterInstance = v,
              milestoneRisks: const [],
            ),
          ),
        ),
      );

      expect(find.byType(GanttColumnToggleBar), findsOneWidget);
      expect(find.byType(GanttFilteredEmptyState), findsOneWidget);
      expect(find.text('表示 0 / 全体 1 件'), findsOneWidget);
      expect(find.text('条件に一致するタスクはありません（全 1 件中 0 件）'), findsOneWidget);
      expect(find.textContaining('WBS migration'), findsNothing);

      await tester.tap(find.text('フィルターをリセット'));
      await tester.pump();

      expect(filterInstance, isNull);
      expect(hideCompleted, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows clean empty card when no tasks loaded', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GanttTimelineTab(
              milestones: const [],
              tasks: const [],
              loading: false,
              hideCompleted: false,
              onToggleHideCompleted: (_) {},
              filterInstance: null,
              onFilterInstance: (_) {},
              milestoneRisks: const [],
            ),
          ),
        ),
      );

      expect(find.text('表示できるタスクがまだありません'), findsOneWidget);
      expect(find.textContaining('WBS migration'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
