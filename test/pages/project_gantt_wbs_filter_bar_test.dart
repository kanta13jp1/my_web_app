import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/project_gantt_page.dart';

void main() {
  group('WbsFilterBar', () {
    testWidgets('wraps all chips inside 390px viewport', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      String? selectedInstance;
      String? selectedMilestone;
      var hideCompleted = false;

      final milestones = [
        WbsMilestone(
          code: 'mvp',
          name: 'MVP ローンチ',
          targetDate: DateTime(2026, 6, 1),
          goalUsers: 100,
          description: '',
          color: const Color(0xFFFF6B35),
        ),
        WbsMilestone(
          code: 'seed',
          name: 'Seed 調達完了',
          targetDate: DateTime(2026, 9, 1),
          goalUsers: 1000,
          description: '',
          color: const Color(0xFF10B981),
        ),
        WbsMilestone(
          code: 'v1',
          name: '最終版 v1.0',
          targetDate: DateTime(2026, 12, 1),
          goalUsers: 10000,
          description: '',
          color: const Color(0xFF3D5AFE),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: WbsFilterBar(
                filterInstance: selectedInstance,
                filterMilestone: selectedMilestone,
                milestones: milestones,
                hideCompleted: hideCompleted,
                onFilterInstance: (v) => selectedInstance = v,
                onFilterMilestone: (v) => selectedMilestone = v,
                onToggleHideCompleted: (v) => hideCompleted = v ?? false,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Wrap), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsNothing);

      for (final label in [
        '全て',
        'Claude Code',
        'Codex',
        'User',
        'Automation',
        'Unassigned',
        '☐ 未完了のみ',
        '全版',
        'MVP ローンチ',
        'Seed 調達完了',
        '最終版 v1.0',
      ]) {
        final rect = tester.getRect(find.text(label));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(390));
      }

      await tester.tap(find.text('Codex'));
      await tester.tap(find.text('☐ 未完了のみ'));
      await tester.tap(find.text('最終版 v1.0'));
      await tester.pump();

      expect(selectedInstance, 'codex');
      expect(hideCompleted, isTrue);
      expect(selectedMilestone, 'v1');
      expect(tester.takeException(), isNull);
    });
  });
}
