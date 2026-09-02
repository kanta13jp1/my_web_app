import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/migrations/'
    '20260828120213_remediate_01ai_latest_info_course.sql',
  );

  test('01.AI lesson is dated, sourced, and explicitly supersedes old claims',
      () {
    final sql = migration.readAsStringSync();

    expect(sql, contains('公式情報確認日: 2026-08-28 (JST)'));
    expect(sql, contains('2026.07 — TrueNorthを公開'));
    expect(sql, contains('2026.01 — WorldWise 2.5'));
    expect(sql, contains('2026-04-13版'));
    expect(sql, contains('https://www.01.ai/about.html'));
    expect(sql, contains('https://www.01.ai/TrueNorth.html'));
    expect(sql, contains('https://github.com/01-ai/Yi#news'));
    expect(sql, contains("where provider = '01ai'"));
    expect(sql, contains("and category = 'news'"));
  });

  test('learning events aggregate outcomes without learner text or identity',
      () {
    final sql = migration.readAsStringSync();
    final events = sql.substring(
      sql.indexOf(
        'create table if not exists public.ai_university_learning_outcome_events',
      ),
    );

    expect(events, contains("event_name in ('task_viewed', 'task_completed')"));
    expect(events, contains('correct_answers between 0 and 3'));
    expect(events, contains('self_rating between 1 and 5'));
    expect(events, contains('enable row level security'));
    expect(events, contains('grant insert ('));
    expect(events, contains('completion_rate_percent'));
    expect(events, contains('average_correct_percent'));
    expect(events, contains('average_self_rating'));
    expect(events, isNot(contains('user_id')));
    expect(events, isNot(contains('session_id')));
    expect(events, isNot(contains('answer text')));
    expect(events, isNot(contains('summary text')));
  });

  test('01.AI news expansion records one view and renders the outcome task',
      () {
    final page = File(
      'lib/pages/gemini_university_v2_page.dart',
    ).readAsStringSync();

    expect(page, contains("provider == '01ai' && category == 'news'"));
    expect(page, contains('_viewedLearningOutcomeTasks.add(taskViewKey)'));
    expect(page, contains('learningOutcomeAnalytics.recordViewed()'));
    expect(page, contains('AiUniversityLatestInfoTaskCard('));
    expect(
      page,
      contains('onSubmit: _learningOutcomeAnalytics.recordCompleted'),
    );
  });
}
