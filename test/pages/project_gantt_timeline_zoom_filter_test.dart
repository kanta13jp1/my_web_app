import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/project_gantt_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

WbsTask _makeTask({
  required String id,
  required String title,
  String status = 'in_progress',
  DateTime? plannedStartDate,
  DateTime? plannedEndDate,
}) {
  return WbsTask(
    id: id,
    category: 'UI改善',
    categoryIcon: 'code',
    categoryOrder: 1,
    title: title,
    description: '',
    instance: 'claude',
    status: status,
    progress: status == 'completed' ? 100 : 40,
    priority: 'medium',
    ownerInstance: 'claude',
    plannedStartDate: plannedStartDate,
    plannedEndDate: plannedEndDate,
  );
}

void main() {
  final fixedNow = DateTime(2026, 6, 15);

  group('ganttTimelineDateToX & ganttTimelineMatchesPeriodFilter', () {
    test('scales date-to-X proportionally across all four zoom levels', () {
      final start = DateTime(2026, 6, 1);
      final target = DateTime(2026, 6, 11); // +10 days

      expect(
        ganttTimelineDateToX(
          date: target,
          timelineStart: start,
          dayWidth: GanttTimelineZoomLevel.quarter.dayWidth,
        ),
        closeTo(35.0, 0.001),
      );
      expect(
        ganttTimelineDateToX(
          date: target,
          timelineStart: start,
          dayWidth: GanttTimelineZoomLevel.month.dayWidth,
        ),
        closeTo(70.0, 0.001),
      );
      expect(
        ganttTimelineDateToX(
          date: target,
          timelineStart: start,
          dayWidth: GanttTimelineZoomLevel.week.dayWidth,
        ),
        closeTo(140.0, 0.001),
      );
      expect(
        ganttTimelineDateToX(
          date: target,
          timelineStart: start,
          dayWidth: GanttTimelineZoomLevel.day.dayWidth,
        ),
        closeTo(240.0, 0.001),
      );
    });

    test('matches all 5 period filter buckets accurately', () {
      final overdueOpen = _makeTask(
        id: 'overdue-open',
        title: '期限超過タスク',
        plannedStartDate: DateTime(2026, 6, 1),
        plannedEndDate: DateTime(2026, 6, 10),
      );
      final overdueCompleted = _makeTask(
        id: 'overdue-done',
        title: '完了済み過去タスク',
        status: 'completed',
        plannedStartDate: DateTime(2026, 5, 1),
        plannedEndDate: DateTime(2026, 5, 20),
      );
      final juneTask = _makeTask(
        id: 'june-task',
        title: '今月タスク',
        plannedStartDate: DateTime(2026, 6, 20),
        plannedEndDate: DateTime(2026, 6, 28),
      );
      final julyTask = _makeTask(
        id: 'july-task',
        title: '30日以内タスク',
        plannedStartDate: DateTime(2026, 7, 5),
        plannedEndDate: DateTime(2026, 7, 12),
      );
      final augustTask = _makeTask(
        id: 'aug-task',
        title: '90日以内タスク',
        plannedStartDate: DateTime(2026, 8, 10),
        plannedEndDate: DateTime(2026, 8, 20),
      );
      final farTask = _makeTask(
        id: 'far-task',
        title: '半年先タスク',
        plannedStartDate: DateTime(2026, 12, 1),
        plannedEndDate: DateTime(2026, 12, 10),
      );
      final noDateTask = _makeTask(
        id: 'nodate-task',
        title: '日程未定タスク',
      );

      for (final task in [
        overdueOpen,
        overdueCompleted,
        juneTask,
        julyTask,
        augustTask,
        farTask,
        noDateTask,
      ]) {
        expect(
          ganttTimelineMatchesPeriodFilter(
            task,
            GanttTimelinePeriodFilter.all,
            now: fixedNow,
          ),
          isTrue,
        );
      }

      // thisMonth (2026-06-01 .. 2026-06-30)
      expect(
        ganttTimelineMatchesPeriodFilter(
          overdueOpen,
          GanttTimelinePeriodFilter.thisMonth,
          now: fixedNow,
        ),
        isTrue,
      );
      expect(
        ganttTimelineMatchesPeriodFilter(
          juneTask,
          GanttTimelinePeriodFilter.thisMonth,
          now: fixedNow,
        ),
        isTrue,
      );
      expect(
        ganttTimelineMatchesPeriodFilter(
          julyTask,
          GanttTimelinePeriodFilter.thisMonth,
          now: fixedNow,
        ),
        isFalse,
      );
      expect(
        ganttTimelineMatchesPeriodFilter(
          noDateTask,
          GanttTimelinePeriodFilter.thisMonth,
          now: fixedNow,
        ),
        isFalse,
      );

      // next30Days (2026-06-15 .. 2026-07-15)
      expect(
        ganttTimelineMatchesPeriodFilter(
          juneTask,
          GanttTimelinePeriodFilter.next30Days,
          now: fixedNow,
        ),
        isTrue,
      );
      expect(
        ganttTimelineMatchesPeriodFilter(
          julyTask,
          GanttTimelinePeriodFilter.next30Days,
          now: fixedNow,
        ),
        isTrue,
      );
      expect(
        ganttTimelineMatchesPeriodFilter(
          augustTask,
          GanttTimelinePeriodFilter.next30Days,
          now: fixedNow,
        ),
        isFalse,
      );

      // next90Days (2026-06-15 .. 2026-09-13)
      expect(
        ganttTimelineMatchesPeriodFilter(
          augustTask,
          GanttTimelinePeriodFilter.next90Days,
          now: fixedNow,
        ),
        isTrue,
      );
      expect(
        ganttTimelineMatchesPeriodFilter(
          farTask,
          GanttTimelinePeriodFilter.next90Days,
          now: fixedNow,
        ),
        isFalse,
      );

      // overdue (< 2026-06-15 and !isEffectivelyCompleted)
      expect(
        ganttTimelineMatchesPeriodFilter(
          overdueOpen,
          GanttTimelinePeriodFilter.overdue,
          now: fixedNow,
        ),
        isTrue,
      );
      expect(
        ganttTimelineMatchesPeriodFilter(
          overdueCompleted,
          GanttTimelinePeriodFilter.overdue,
          now: fixedNow,
        ),
        isFalse,
      );
      expect(
        ganttTimelineMatchesPeriodFilter(
          juneTask,
          GanttTimelinePeriodFilter.overdue,
          now: fixedNow,
        ),
        isFalse,
      );
    });
  });

  group('GanttTimelineTab zoom & period controls UI', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    testWidgets(
      'GanttColumnToggleBar fits zoom and period chips inside 390px Wrap',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        GanttTimelineZoomLevel? selectedZoom;
        GanttTimelinePeriodFilter? selectedPeriod;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GanttColumnToggleBar(
                colVisible: const {'flags': true},
                filterInstance: null,
                onToggleColumn: (_, __) {},
                onFilterInstance: (_) {},
                zoomLevel: GanttTimelineZoomLevel.month,
                onZoomLevelChanged: (v) => selectedZoom = v,
                periodFilter: GanttTimelinePeriodFilter.all,
                onPeriodFilterChanged: (v) => selectedPeriod = v,
              ),
            ),
          ),
        );

        expect(find.byType(Wrap), findsOneWidget);
        expect(find.byType(SingleChildScrollView), findsNothing);

        for (final level in GanttTimelineZoomLevel.values) {
          final rect = tester.getRect(
            find.byKey(Key('gantt_zoom_chip_${level.name}')),
          );
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(390));
        }
        for (final period in GanttTimelinePeriodFilter.values) {
          final rect = tester.getRect(
            find.byKey(Key('gantt_period_chip_${period.name}')),
          );
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(390));
        }

        await tester.tap(find.byKey(const Key('gantt_zoom_chip_day')));
        await tester.tap(find.byKey(const Key('gantt_period_chip_overdue')));
        await tester.pump();

        expect(selectedZoom, GanttTimelineZoomLevel.day);
        expect(selectedPeriod, GanttTimelinePeriodFilter.overdue);
        expect(tester.takeException(), isNull);
      },
    );

    Future<void> verifyZoomAndPeriodInViewport(
      WidgetTester tester,
      Size viewportSize,
    ) async {
      tester.view.physicalSize = viewportSize;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      String? filterInstance;
      var hideCompleted = false;

      final tasks = [
        _makeTask(
          id: 't-overdue',
          title: '遅延対応タスク',
          plannedStartDate: DateTime(2026, 6, 1),
          plannedEndDate: DateTime(2026, 6, 10),
        ),
        _makeTask(
          id: 't-june',
          title: '今月進行タスク',
          plannedStartDate: DateTime(2026, 6, 18),
          plannedEndDate: DateTime(2026, 6, 26),
        ),
        _makeTask(
          id: 't-aug',
          title: '再来月予定タスク',
          plannedStartDate: DateTime(2026, 8, 5),
          plannedEndDate: DateTime(2026, 8, 12),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => GanttTimelineTab(
                milestones: const [],
                tasks: tasks,
                loading: false,
                hideCompleted: hideCompleted,
                onToggleHideCompleted: (v) =>
                    setState(() => hideCompleted = v ?? false),
                filterInstance: filterInstance,
                onFilterInstance: (v) => setState(() => filterInstance = v),
                milestoneRisks: const [],
                clockNow: fixedNow,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final monthWidth =
          tester.getSize(find.byKey(const Key('gantt_timeline_canvas'))).width;

      await tester.tap(find.byKey(const Key('gantt_zoom_chip_day')));
      await tester.pumpAndSettle();
      final dayWidth =
          tester.getSize(find.byKey(const Key('gantt_timeline_canvas'))).width;

      await tester.tap(find.byKey(const Key('gantt_zoom_chip_quarter')));
      await tester.pumpAndSettle();
      final quarterWidth =
          tester.getSize(find.byKey(const Key('gantt_timeline_canvas'))).width;

      expect(dayWidth / monthWidth, closeTo(24.0 / 7.0, 0.01));
      expect(quarterWidth / monthWidth, closeTo(3.5 / 7.0, 0.01));

      await tester.tap(find.byKey(const Key('gantt_period_chip_overdue')));
      await tester.pumpAndSettle();
      expect(find.text('表示 1 / 全体 3 件'), findsOneWidget);
      expect(find.text('遅延対応タスク'), findsOneWidget);
      expect(find.text('再来月予定タスク'), findsNothing);

      await tester.tap(find.byKey(const Key('gantt_period_chip_thisMonth')));
      await tester.pumpAndSettle();
      expect(find.text('表示 2 / 全体 3 件'), findsOneWidget);
      expect(find.text('遅延対応タスク'), findsOneWidget);
      expect(find.text('今月進行タスク'), findsOneWidget);
      expect(find.text('再来月予定タスク'), findsNothing);

      // Reset to all period and verify empty-state reset path too.
      await tester.tap(find.byKey(const Key('gantt_period_chip_all')));
      await tester.pumpAndSettle();
      expect(find.text('3 タスク'), findsOneWidget);

      await tester.tap(find.byKey(const Key('gantt_period_chip_overdue')));
      await tester.tap(find.text('Unassigned'));
      await tester.pumpAndSettle();
      expect(find.byType(GanttFilteredEmptyState), findsOneWidget);

      await tester.tap(find.text('フィルターをリセット'));
      await tester.pumpAndSettle();
      expect(find.text('3 タスク'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }

    testWidgets(
      'supports zoom scaling & period filtering on desktop 1280x900',
      (tester) async {
        await verifyZoomAndPeriodInViewport(tester, const Size(1280, 900));
      },
    );

    testWidgets(
      'supports zoom scaling & period filtering on mobile 390x844',
      (tester) async {
        await verifyZoomAndPeriodInViewport(tester, const Size(390, 844));
      },
    );
  });
}
