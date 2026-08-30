import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/migrations/'
    '20260830120000_remediate_agentless_course.sql',
  );

  test(
    'Agentless evidence block keeps each benchmark configuration separate',
    () {
      final sql = migration.readAsStringSync();

      expect(sql, contains('Versioned evidence block v1'));
      expect(sql, contains('https://arxiv.org/abs/2407.01489v2'));
      expect(sql, contains('releases/tag/v1.5.0'));
      expect(sql, contains('b150f28465a77a81a7f4776384957a4271f5bd69'));
      expect(sql, contains('96/300 (32.00%)'));
      expect(sql, contains(r'$0.70/issue'));
      expect(sql, contains('82/300 (27.3%)'));
      expect(sql, contains(r'$0.34/issue'));
      expect(sql, contains('122/300 (40.7%)'));
      expect(sql, contains('254/500 (50.8%)'));
      expect(sql, contains('未公表'));
      expect(
        sql,
        contains("where id = '50609809-2da6-41ba-9c35-4bbec9668493'::uuid"),
      );
    },
  );

  test(
    'fixed lab covers localization through final patch with success gates',
    () {
      final sql = migration.readAsStringSync();

      expect(sql, contains('60分lab v1: `django__django-10914`'));
      expect(sql, contains('suspicious file'));
      expect(sql, contains('edit location'));
      expect(sql, contains('4候補patch'));
      expect(sql, contains('regression tests'));
      expect(sql, contains('reproduction test'));
      expect(sql, contains('reranking'));
      expect(sql, contains('final patch'));
      expect(sql, contains('明示的な成功基準'));
      expect(sql, contains('6ec7bb89b9342f664a54a6e0a6ea6501d3437cc2'));
    },
  );

  test('run manifest records the complete fixed execution contract', () {
    final sql = migration.readAsStringSync();

    for (final field in <String>[
      'python_version',
      'agentless_release',
      'agentless_revision',
      'dataset_revision',
      'model',
      'candidate_count',
      'max_threads',
      'prompt_tokens',
      'completion_tokens',
      'embedding_tokens',
      'api_cost_usd',
      'wall_time_seconds',
      'regression_result',
      'reproduction_result',
      'test_result',
    ]) {
      expect(sql, contains(field), reason: 'missing manifest field $field');
    }
  });

  test('one-cohort evidence is bounded, private, and starts empty', () {
    final sql = migration.readAsStringSync();
    final events = sql.substring(
      sql.indexOf(
        'create table if not exists '
        'public.ai_university_agentless_lab_events',
      ),
    );

    expect(events, contains("event_name in ('lab_started', 'lab_completed')"));
    expect(events, contains("task_version = 'agentless_lab_20260830_v1'"));
    expect(events, contains('localization_correct'));
    expect(events, contains('num_nonnulls('));
    expect(events, contains(') = 21'));
    expect(events, contains('prompt_tokens <= 100000000'));
    expect(events, contains('prompt_tokens + completion_tokens > 0'));
    expect(events, contains('api_cost_usd > 0'));
    expect(events, contains('average_cost_prediction_error_percent'));
    expect(events, contains('reproduced_percent'));
    expect(events, contains('workplace_applied_percent'));
    expect(events, contains('enable row level security'));
    expect(events, contains('to anon, authenticated'));
    expect(events, contains('to service_role'));
    expect(events, isNot(contains('insert into')));
    expect(events, isNot(contains('user_id')));
    expect(events, isNot(contains('session_id')));
    expect(events, isNot(contains('ip_address')));
    expect(events, isNot(contains('answer_text')));
    expect(events, isNot(contains('patch_text')));
    expect(events, isNot(contains('issue_text')));
  });

  test('course UI renders the explicit Agentless lab start and completion path',
      () {
    final page = File(
      'lib/pages/gemini_university_v2_page.dart',
    ).readAsStringSync();

    expect(
      page,
      contains("provider == 'agentless' && category == 'overview'"),
    );
    expect(page, contains('AiUniversityAgentlessLabTaskCard('));
    expect(page, contains('onStart: _agentlessLabAnalytics.recordStarted'));
    expect(page, contains('onSubmit: _agentlessLabAnalytics.recordCompleted'));
  });
}
