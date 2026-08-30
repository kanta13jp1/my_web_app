import 'dart:io';

import 'package:test/test.dart';

void main() {
  final migration = File(
    'supabase/migrations/'
    '20260830040000_remediate_adept_fuyu_course_evidence.sql',
  );

  test('lesson pins the official Fuyu exercise and its limitations', () {
    final sql = migration.readAsStringSync();

    expect(sql, contains('Fuyu-8B 公開モデルカード検証入門'));
    expect(sql, contains('f41defefdb89be0d28cac19d94ce216e37cb6be5'));
    expect(
      sql,
      contains(
        'resolve/f41defefdb89be0d28cac19d94ce216e37cb6be5/'
        'bus.png',
      ),
    );
    expect(sql, contains('Transformers Fuyu documentation v5.15.1'));
    expect(sql, contains('CC-BY-NC-4.0'));
    expect(sql, contains('研究用途向けのbase model'));
    expect(sql, contains(r'Generate a coco-style caption.\n'));
    expect(sql, contains('`max_new_tokens`を`7`'));
    expect(sql, contains('A blue bus parked on the side of a road.'));
  });

  test('lesson defines prerequisites, one attempt, fallback, and rubric', () {
    final sql = migration.readAsStringSync();

    expect(sql, contains('## 実行前提'));
    expect(sql, contains('## 1回だけの推論課題'));
    expect(sql, contains('## 読解専用フォールバック'));
    expect(sql, contains('処理段階、例外型、エラーメッセージ全文'));
    expect(sql, contains('## 4項目rubric（4/4で合格）'));
    expect(sql, contains('根拠確認日: 2026-08-30 (JST)'));
    expect(sql, contains('公開時点の実測値は0件で、学習成果を断定しません'));
    expect(sql, contains('初回成功率、平均完了時間、自己回復率'));
  });

  test('unsupported API, commercial, and learner claims are absent', () {
    final sql = migration.readAsStringSync();

    expect(sql, contains('現行ホステッドAPIを説明または利用する講座ではありません'));
    expect(sql, contains('それらの有無をこの講座から結論づけません'));
    expect(sql, isNot(contains('一般向けAPIキーは提供されていない')));
    expect(sql, isNot(contains('Apache 2.0ライセンスで完全商用利用可能')));
    expect(sql, isNot(contains('AWS Bedrock等で展開予定')));
    expect(sql, isNot(contains('年間契約')));
    expect(sql, isNot(contains('学習者の90%')));
  });

  test('update is fail-closed, narrow, complete, and replay-safe', () {
    final sql = migration.readAsStringSync();
    final updates = RegExp(
      r'\bupdate\s+public\.ai_university_content\b',
      caseSensitive: false,
    ).allMatches(sql);

    expect(updates, hasLength(1));
    expect(sql, contains('expected exactly one adept/api AI University row'));
    expect(sql, contains('if v_target_count <> 1 then'));
    expect(sql, contains("where provider = 'adept'"));
    expect(sql, contains("and category = 'api'"));
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
    expect(sql, contains("v_published_at constant date := date '2026-08-30'"));
    expect(sql, contains("timestamptz '2026-08-30 00:00:00+09'"));
  });

  test('anonymous outcomes are finite, private, and start empty', () {
    final sql = migration.readAsStringSync();
    final events = sql.substring(
      sql.indexOf(
        'create table if not exists public.ai_university_fuyu_lab_events',
      ),
    );

    expect(events, contains("event_name in ('lab_started', 'lab_completed')"));
    expect(
      events,
      contains("task_version = 'adept_fuyu_model_card_20260830_v1'"),
    );
    expect(events, contains("task_mode in ('inference', 'reading_fallback')"));
    expect(events, contains("'first_try_success'"));
    expect(events, contains("'success_after_error'"));
    expect(events, contains("'success_after_difference'"));
    expect(events, contains("'unresolved_error'"));
    expect(events, contains("'unresolved_difference'"));
    expect(events, contains("'reading_completed'"));
    expect(events, contains('completion_seconds between 1 and 86400'));
    expect(events, contains('rubric_score between 0 and 4'));
    expect(events, contains('num_nonnulls('));
    expect(events, contains('first_attempt_success_percent'));
    expect(events, contains('average_completion_seconds'));
    expect(events, contains('self_recovery_percent'));
    expect(events, contains('with (security_invoker = true)'));
    expect(events, contains('enable row level security'));
    expect(events, contains('to anon, authenticated'));
    expect(events, contains('to service_role'));
    expect(events, isNot(contains('insert into')));
    for (final prohibited in <String>[
      'user_id',
      'session_id',
      'ip_address',
      'prompt_text',
      'generated_text',
      'error_text',
    ]) {
      expect(events, isNot(contains(prohibited)));
    }
  });

  test('course UI renders the explicit Fuyu start and completion path', () {
    final page = File(
      'lib/pages/gemini_university_v2_page.dart',
    ).readAsStringSync();

    expect(page, contains("provider == 'adept' && category == 'api'"));
    expect(page, contains('AiUniversityFuyuLabTaskCard('));
    expect(page, contains('onStart: _fuyuLabAnalytics.recordStarted'));
    expect(page, contains('onSubmit: _fuyuLabAnalytics.recordCompleted'));
  });
}
