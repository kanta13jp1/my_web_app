import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/project_gantt_page.dart';

void main() {
  group('GanttTimelineHeader', () {
    testWidgets('wraps controls inside 390px', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool? toggledHideCompleted;
      var scrollCalled = false;
      var aiReportCalled = false;
      var repairCalled = false;
      var exportCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 390,
              height: 844,
              child: GanttTimelineHeader(
                taskCount: 12,
                totalCount: 20,
                invertedCount: 2,
                hideCompleted: false,
                onToggleHideCompleted: (v) => toggledHideCompleted = v,
                onScrollToGraph: () => scrollCalled = true,
                onShowAiReport: () => aiReportCalled = true,
                onAutoRepair: () => repairCalled = true,
                onExportCsv: () => exportCalled = true,
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(Wrap), findsOneWidget);
      expect(find.text('日付補正 2件'), findsOneWidget);

      final checkboxRect = tester.getRect(find.byType(Checkbox));
      expect(checkboxRect.left, greaterThanOrEqualTo(0));
      expect(checkboxRect.right, lessThanOrEqualTo(390));

      final toggleRect = tester.getRect(find.text('未完了のみ'));
      expect(toggleRect.left, greaterThanOrEqualTo(0));
      expect(toggleRect.right, lessThanOrEqualTo(390));

      for (final label in [
        'グラフへ',
        'AI 概観',
        '依存修復',
        'CSV',
      ]) {
        final textRect = tester.getRect(find.text(label));
        expect(textRect.left, greaterThanOrEqualTo(0));
        expect(textRect.right, lessThanOrEqualTo(390));

        final button = find.ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate((w) => w is OutlinedButton),
        );
        final buttonRect = tester.getRect(button);
        expect(buttonRect.left, greaterThanOrEqualTo(0));
        expect(buttonRect.right, lessThanOrEqualTo(390));
      }

      await tester.tap(find.text('未完了のみ'));
      await tester.tap(find.text('グラフへ'));
      await tester.tap(find.text('AI 概観'));
      await tester.tap(find.text('依存修復'));
      await tester.tap(find.text('CSV'));
      await tester.pump();

      expect(toggledHideCompleted, isTrue);
      expect(scrollCalled, isTrue);
      expect(aiReportCalled, isTrue);
      expect(repairCalled, isTrue);
      expect(exportCalled, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows filtered count and loading state', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var aiReportCalled = false;
      var repairCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 390,
              height: 844,
              child: GanttTimelineHeader(
                taskCount: 3,
                totalCount: 10,
                hideCompleted: true,
                aiReportLoading: true,
                repairLoading: true,
                onToggleHideCompleted: (_) {},
                onScrollToGraph: () {},
                onShowAiReport: () => aiReportCalled = true,
                onAutoRepair: () => repairCalled = true,
                onExportCsv: () {},
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('未完了 3 / 全体 10 件'), findsOneWidget);
      expect(find.text('分析中'), findsOneWidget);
      expect(find.text('修復中'), findsOneWidget);

      await tester.tap(find.text('分析中'));
      await tester.tap(find.text('修復中'));
      await tester.pump();

      expect(aiReportCalled, isFalse);
      expect(repairCalled, isFalse);
      expect(tester.takeException(), isNull);
    });
  });
}
