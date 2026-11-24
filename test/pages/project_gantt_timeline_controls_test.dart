import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/project_gantt_page.dart';

void main() {
  group('Gantt timeline responsive controls', () {
    testWidgets('GanttColumnToggleBar wraps inside 390px', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      String? toggledKey;
      bool? toggledValue;
      String? selectedOwner;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GanttColumnToggleBar(
              colVisible: const {'flags': true},
              filterInstance: null,
              onToggleColumn: (key, visible) {
                toggledKey = key;
                toggledValue = visible;
              },
              onFilterInstance: (v) => selectedOwner = v,
            ),
          ),
        ),
      );

      expect(find.byType(Wrap), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsNothing);

      for (final label in [
        'タスク',
        '注意',
        '全て',
        'Claude Code',
        'Codex',
        'User',
        'Automation',
        'Unassigned',
      ]) {
        final rect = tester.getRect(find.text(label));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(390));
      }

      await tester.tap(find.text('注意'));
      await tester.tap(find.text('Unassigned'));
      await tester.pump();

      expect(toggledKey, 'flags');
      expect(toggledValue, isFalse);
      expect(selectedOwner, 'unassigned');
      expect(tester.takeException(), isNull);
    });

    testWidgets('GanttMilestoneRiskBanner wraps inside 390px', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final warnings = <Map<String, dynamic>>[
        {
          'code': 'mvp-launch',
          'risk_status': 'critical_overdue',
          'overdue_tasks': 5,
        },
        {
          'code': 'seed',
          'risk_status': 'over_capacity',
          'remaining_hours': 120,
          'available_hours': 80,
        },
        {
          'code': 'v1',
          'risk_status': 'tight',
          'days_left': 12,
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GanttMilestoneRiskBanner(warnings: warnings),
          ),
        ),
      );

      expect(find.byType(Wrap), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsNothing);

      for (final snippet in ['マイルストーン警告', 'mvp-launch', 'seed', 'v1']) {
        final rect = tester.getRect(find.textContaining(snippet).first);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(390));
      }

      expect(tester.takeException(), isNull);
    });
  });
}
