@TestOn('browser')

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/completion_goal_service.dart';

void main() {
  group('CompletionGoalService', () {
    test('counts completions by completed_at before falling back to task_date',
        () {
      final now = DateTime(2026, 3, 14, 9, 0);
      final todos = <Map<String, dynamic>>[
        {
          'id': 'today-1',
          'is_completed': true,
          'completed_at': '2026-03-14T08:10:00+09:00',
          'task_date': '2026-03-10',
        },
        {
          'id': 'today-2',
          'is_completed': true,
          'completed_at': '2026-03-14T11:30:00+09:00',
          'task_date': '2026-03-14',
        },
        {
          'id': 'yesterday',
          'is_completed': true,
          'completed_at': '2026-03-13T21:00:00+09:00',
          'task_date': '2026-03-13',
        },
        {
          'id': 'legacy-fallback',
          'is_completed': true,
          'completed_at': null,
          'task_date': '2026-03-13',
        },
        {
          'id': 'open-task',
          'is_completed': false,
          'completed_at': '2026-03-14T12:00:00+09:00',
          'task_date': '2026-03-14',
        },
      ];

      final snapshot = CompletionGoalService.buildSnapshot(
        todos: todos,
        now: now,
      );

      expect(snapshot.todayCompletedCount, 2);
      expect(snapshot.yesterdayCompletedCount, 2);
      expect(snapshot.targetCount, 3);
      expect(snapshot.remainingCount, 1);
      expect(snapshot.isAchieved, isFalse);
    });

    test('marks challenge achieved when today beats yesterday', () {
      final now = DateTime(2026, 3, 14, 20, 0);
      final todos = <Map<String, dynamic>>[
        {
          'is_completed': true,
          'completed_at': '2026-03-13T10:00:00+09:00',
        },
        {
          'is_completed': true,
          'completed_at': '2026-03-14T09:00:00+09:00',
        },
        {
          'is_completed': true,
          'completed_at': '2026-03-14T14:00:00+09:00',
        },
      ];

      final snapshot = CompletionGoalService.buildSnapshot(
        todos: todos,
        now: now,
      );

      expect(snapshot.yesterdayCompletedCount, 1);
      expect(snapshot.todayCompletedCount, 2);
      expect(snapshot.targetCount, 2);
      expect(snapshot.remainingCount, 0);
      expect(snapshot.deltaFromYesterday, 1);
      expect(snapshot.isAchieved, isTrue);
      expect(snapshot.progress, 1.0);
    });
  });
}
