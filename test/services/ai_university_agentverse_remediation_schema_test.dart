import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/migrations/'
    '20260903113000_remediate_agentverse_course.sql',
  );

  test('lesson pins the real exports, CLI, and complete version contract', () {
    final sql = migration.readAsStringSync();

    expect(sql, contains('f90c4bd9680fdd3bcff8c52c9170911a59b23478'));
    expect(sql, contains('4ed4783f248875bc9e6efeda33482cc2d460f139'));
    expect(sql, contains('from agentverse import TaskSolving'));
    expect(
      sql,
      contains('agentverse-tasksolving --task tasksolving/brainstorming'),
    );
    expect(sql, contains('Python 3.9以上'));
    expect(sql, contains('gpt-3.5-turbo'));
    expect(sql, contains('OPENAI_API_KEY'));
    expect(sql, contains('requirements.txt'));
    expect(sql, contains('mainのsimulationは公式README上でrefactor中'));
    expect(sql, isNot(contains('from agentverse import AgentVerse')));
    expect(sql, isNot(contains('ConversationAgent')));
    expect(sql, isNot(contains('TaskDrivenAgentVerse')));
  });

  test('lesson provides deterministic evidence and the three-run lab', () {
    final sql = migration.readAsStringSync();

    expect(sql, contains('## 公式exportとCLIだけを使う開始手順'));
    expect(sql, contains('### 期待出力と合格条件'));
    expect(sql, contains('ModuleNotFoundError: agentverse'));
    expect(sql, contains('## 60分lab: 同じ固定taskを3条件で比較'));
    expect(sql, contains('### Run 1: single agent'));
    expect(sql, contains('### Run 2: fixed role team'));
    expect(sql, contains('### Run 3: conditional role team'));
    expect(sql, contains('品質rubric 0〜4、wall time秒、合計tokens、実測cost USD'));
    expect(sql, contains('## 4項目rubric（4/4で合格）'));
    expect(sql, contains('公開時点の実在学習者データは0件'));
  });

  test('course update is narrow, fail-closed, and replay safe', () {
    final sql = migration.readAsStringSync();
    final updates = RegExp(
      r'\bupdate\s+public\.ai_university_content\b',
      caseSensitive: false,
    ).allMatches(sql);

    expect(updates, hasLength(1));
    expect(
      sql,
      contains('expected exactly one agentverse/overview AI University row'),
    );
    expect(sql, contains('if v_target_count <> 1 then'));
    expect(sql, contains("where provider = 'agentverse'"));
    expect(sql, contains("and category = 'overview'"));
    expect(sql, contains('is distinct from'));
    expect(sql, isNot(contains('updated_at = now()')));
    for (final column in <String>[
      'target_audience',
      'observable_learning_outcome',
      'assessment_verification_method',
      'evidence_source_url',
      'evidence_verified_at',
    ]) {
      expect(sql, contains('$column ='));
    }
  });

  test('anonymous evidence is bounded, private, and starts empty', () {
    final sql = migration.readAsStringSync();
    final events = sql.substring(
      sql.indexOf(
        'create table if not exists '
        'public.ai_university_agentverse_lab_events',
      ),
    );

    expect(
      events,
      contains(
        "event_name in ('lab_started', 'import_checked', 'lab_completed')",
      ),
    );
    expect(
      events,
      contains("task_version = 'agentverse_role_comparison_20260903_v1'"),
    );
    expect(events, contains("import_outcome in ('succeeded', 'failed')"));
    expect(events, contains('single_quality_score between 0 and 4'));
    expect(events, contains('fixed_wall_seconds between 1 and 3600'));
    expect(events, contains('conditional_token_count between 1 and 10000000'));
    expect(events, contains('conditional_cost_usd between 0 and 100'));
    expect(events, contains("'quality_gate_failed'"));
    expect(events, contains("'no_role_added'"));
    expect(events, contains('completion_seconds between 1 and 7200'));
    expect(events, contains('enable row level security'));
    expect(events, contains('to anon, authenticated'));
    expect(events, contains('to service_role'));
    expect(events, contains('with (security_invoker = true)'));
    expect(events, isNot(contains('user_id')));
    expect(events, isNot(contains('session_id')));
    expect(events, isNot(contains('prompt_text')));
    expect(events, isNot(contains('error_text')));
    expect(
      RegExp(
        r'insert\s+into\s+public\.ai_university_agentverse_lab_events',
        caseSensitive: false,
      ).hasMatch(events),
      isFalse,
    );
  });

  test('page mounts the dedicated card only on agentverse overview', () {
    final page = File('lib/pages/gemini_university_v2_page.dart')
        .readAsStringSync();

    expect(
      page,
      contains(
        "import '../services/ai_university_agentverse_lab_analytics.dart';",
      ),
    );
    expect(
      page,
      contains(
        "import '../widgets/ai_university_agentverse_lab_task_card.dart';",
      ),
    );
    expect(
      page,
      contains("provider == 'agentverse' && category == 'overview'"),
    );
    expect(page, contains('AiUniversityAgentVerseLabTaskCard('));
    expect(page, contains('_agentVerseLabAnalytics.recordImportChecked'));
  });
}
