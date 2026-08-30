import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/migrations/'
    '20260831024000_remediate_adobe_firefly_api_course.sql',
  );

  test('Firefly lesson teaches the official server-side production boundary',
      () {
    final sql = migration.readAsStringSync();

    expect(sql, contains('Adobe公式資料確認日: 2026-08-31 (JST)'));
    expect(sql, contains('secretはserver-sideだけ'));
    expect(sql, contains('expires_in'));
    expect(sql, contains('24時間'));
    expect(sql, contains('/v3/images/generate-async'));
    expect(sql, contains('1件request'));
    expect(sql, contains('複数件request'));
    expect(sql, contains('Retry-After'));
    expect(sql, contains('structured log'));
    expect(sql, contains('4 requests/minute、9,000 requests/day'));
    expect(sql, contains('production-readiness checklist'));
    expect(
      sql,
      contains(
        'https://developer.adobe.com/firefly-services/docs/'
        'firefly-api/getting-started/',
      ),
    );
    expect(sql, contains("where provider = 'adobe_firefly'"));
    expect(sql, contains("and category = 'api'"));
  });

  test('Firefly outcomes are finite, anonymous, and role-aggregated', () {
    final sql = migration.readAsStringSync();

    expect(sql, contains("task_version = 'adobe_firefly_api_20260831_v1'"));
    expect(sql, contains('learner_role text'));
    expect(sql, contains('first_call_succeeded boolean'));
    expect(sql, contains('secret_handling_passed boolean'));
    expect(sql, contains('api_selection_passed boolean'));
    expect(sql, contains('non_2xx_recovery_passed boolean'));
    expect(sql, contains('estimated_daily_requests between 1 and 9000'));
    expect(sql, contains('completion_seconds between 1 and 3600'));
    expect(
      sql,
      contains("'developer', 'operations', 'creator', 'product_owner'"),
    );
    expect(sql, contains('ai_university_firefly_api_outcome_summary'));
    expect(sql, contains('first_call_success_percent'));
    expect(sql, contains('non_2xx_recovery_pass_percent'));
    expect(sql, contains('average_estimated_daily_requests'));
    expect(sql, contains('average_completion_seconds'));
    expect(sql, contains('to anon, authenticated'));
    expect(sql, contains('to service_role'));
    expect(sql, isNot(contains('user_id text')));
    expect(sql, isNot(contains('session_id text')));
    expect(sql, isNot(contains('prompt text')));
    expect(sql, isNot(contains('answer_text')));
    expect(sql, isNot(contains('free_text')));
  });

  test('Adobe Firefly API row renders the bounded lab and analytics task', () {
    final page = File(
      'lib/pages/gemini_university_v2_page.dart',
    ).readAsStringSync();

    expect(
      page,
      contains("provider == 'adobe_firefly' && category == 'api'"),
    );
    expect(page, contains('AiUniversityFireflyApiTaskCard('));
    expect(page, contains('AiUniversityLearningOutcomeTask.fireflyApi'));
    expect(page, contains('recordFireflyCompleted'));
  });
}
