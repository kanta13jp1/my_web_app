import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/migrations/'
    '20260829142055_remediate_llm_mechanics_course.sql',
  );

  test('LLM lesson pins sources, goals, reading order, and rubric', () {
    final sql = migration.readAsStringSync();

    expect(sql, contains('revision 1370470611'));
    expect(sql, contains('https://arxiv.org/abs/1706.03762v7'));
    expect(sql, contains('https://arxiv.org/abs/2206.07682v2'));
    expect(sql, contains('https://arxiv.org/abs/2304.15004v2'));
    expect(sql, contains('## この完結編の到達目標'));
    expect(sql, contains('## 読解順序'));
    expect(sql, contains('## 10分概念マップ課題と採点基準'));
    expect(sql, contains("where provider = 'academic'"));
    expect(sql, contains("and category = 'llm_mechanics'"));
  });

  test('outcome tuple stays finite and stores no learner content', () {
    final sql = migration.readAsStringSync();

    expect(
      sql,
      contains("task_version = 'academic_llm_mechanics_20260829_v1'"),
    );
    expect(sql, contains('correct_answers between 0 and 3'));
    expect(sql, contains('total_questions = 3'));
    expect(sql, contains('self_rating between 1 and 5'));
    expect(sql, contains('to anon, authenticated'));
    expect(sql, isNot(contains('user_id')));
    expect(sql, isNot(contains('session_id')));
    expect(sql, isNot(contains('answer_text')));
    expect(sql, isNot(contains('free_text')));
  });

  test('course UI renders and records the fixed LLM task', () {
    final page = File(
      'lib/pages/gemini_university_v2_page.dart',
    ).readAsStringSync();

    expect(
      page,
      contains("provider == 'academic' && category == 'llm_mechanics'"),
    );
    expect(page, contains('AiUniversityLlmMechanicsTaskCard('));
    expect(page, contains('AiUniversityLearningOutcomeTask.llmMechanics'));
    expect(
      page,
      contains('_llmMechanicsLearningOutcomeAnalytics.recordCompleted'),
    );
  });
}
