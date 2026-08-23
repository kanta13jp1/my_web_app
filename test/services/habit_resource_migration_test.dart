import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _migrationPath =
    'supabase/migrations/20260721235500_add_habit_resource_optimization.sql';

void main() {
  group('habit resource optimization migration', () {
    late final String sql;

    setUpAll(() {
      sql = File(_migrationPath)
          .readAsStringSync()
          .replaceAll('\r\n', '\n')
          .toLowerCase();
    });

    test('stores time, fatigue, and goal contribution on completion logs', () {
      expect(sql, contains('time_cost_minutes integer'));
      expect(sql, contains('fatigue_score numeric(3, 1)'));
      expect(sql, contains('goal_contribution_score numeric(5, 2)'));
      expect(sql, contains('check (time_cost_minutes between 1 and 1440)'));
      expect(sql, contains('check (fatigue_score between 1 and 10)'));
      expect(
        sql,
        contains('check (goal_contribution_score between 0 and 100)'),
      );
    });

    test('calculates correlations inside Supabase for the current user', () {
      expect(sql, contains('analyze_habit_resource_efficiency'));
      expect(
        sql,
        contains('corr(goal_contribution_score, time_cost_minutes)'),
      );
      expect(sql, contains('corr(goal_contribution_score, fatigue_score)'));
      expect(sql, contains('l.user_id = (select auth.uid())'));
      expect(sql, contains('h.user_id = (select auth.uid())'));
      expect(sql, contains('security invoker'));
      expect(sql, contains("set search_path = ''"));
      expect(
        sql,
        contains(
          'revoke all on function public.analyze_habit_resource_efficiency(integer)\n  from public',
        ),
      );
    });

    test('uses time, fatigue, and performance in Pareto dominance', () {
      expect(
        sql,
        contains(
          'competitor.avg_time_minutes <= candidate.avg_time_minutes',
        ),
      );
      expect(
        sql,
        contains(
          'competitor.avg_fatigue_score <= candidate.avg_fatigue_score',
        ),
      );
      expect(
        sql,
        contains(
          'competitor.avg_goal_contribution_score >=\n          candidate.avg_goal_contribution_score',
        ),
      );
      expect(sql, contains('to authenticated;'));
      expect(sql, isNot(contains('to authenticated, service_role')));
    });

    test('indexes both goal foreign keys used by on-delete cleanup', () {
      expect(sql, contains('idx_daily_habits_goal_id'));
      expect(sql, contains('on public.daily_habits (goal_id)'));
      expect(sql, contains('idx_daily_habit_logs_goal_id'));
      expect(sql, contains('on public.daily_habit_logs (goal_id)'));
    });

    test('prevents cross-tenant habit and goal relationships', () {
      expect(sql, contains('drop policy if exists "users_own_daily_habits"'));
      expect(sql, contains('goal.id = daily_habits.goal_id'));
      expect(
        sql,
        contains(
          "goal.metadata ->> 'user_id' = daily_habits.user_id::text",
        ),
      );
      expect(sql, contains('habit.id = daily_habit_logs.habit_id'));
      expect(sql, contains('habit.user_id = daily_habit_logs.user_id'));
      expect(sql, contains('goal.id = daily_habit_logs.goal_id'));
    });
  });
}
