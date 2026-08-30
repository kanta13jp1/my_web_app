import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/migrations/'
    '20260824135127_add_ai_university_evidence_and_content_analytics.sql',
  );

  test('course evidence is additive, attributed, and all-or-none', () {
    final sql = migration.readAsStringSync();

    expect(sql, contains('add column if not exists target_audience text'));
    expect(sql, contains('observable_learning_outcome text'));
    expect(sql, contains('assessment_verification_method text'));
    expect(sql, contains('evidence_source_url text'));
    expect(sql, contains('evidence_verified_at timestamptz'));
    expect(sql, contains('ai_university_course_evidence_complete'));
    expect(sql, contains('num_nonnulls('));
    expect(sql, contains(') = 0'));
    expect(sql, contains(') = 5'));
    expect(sql, isNot(contains('update public.ai_university_content')));
  });

  test('anonymous event schema has a finite no-PII insert contract', () {
    final sql = migration.readAsStringSync();
    final eventTable = sql.substring(
      sql.indexOf(
        'create table if not exists public.ai_university_content_events',
      ),
    );

    for (final event in <String>[
      'content_fetch_failed',
      'fallback_shown',
      'retry_requested',
      'retry_succeeded',
      'retry_failed',
    ]) {
      expect(eventTable, contains("'$event'"));
    }
    expect(eventTable, contains('enable row level security'));
    expect(eventTable, contains('grant insert (event_name, surface)'));
    expect(eventTable, isNot(contains('grant select')));
    expect(eventTable, isNot(contains('user_id')));
    expect(eventTable, isNot(contains('exception')));
    expect(eventTable, isNot(contains('content text')));
  });
}
