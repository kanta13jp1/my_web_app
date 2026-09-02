import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/migrations/'
    '20260829093000_remediate_01ai_model_selection_course.sql',
  );

  test(
    '01.AI model lesson is dated and has an authenticated diff procedure',
    () {
      final sql = migration.readAsStringSync();

      expect(sql, contains('公式ドキュメント確認日: 2026-08-29 (JST)'));
      expect(sql, contains('https://api.01.ai/v1/models'));
      expect(sql, contains(r'Authorization: Bearer $YI_API_KEY'));
      expect(sql, contains('data[].id'));
      expect(sql, contains('前回の**確認日とモデルID一覧**'));
      expect(sql, contains('用途・予算・必要文脈長'));
      expect(sql, contains("where provider = '01ai'"));
      expect(sql, contains("and category = 'models'"));
    },
  );

  test('model-selection outcome events stay finite and anonymous', () {
    final sql = migration.readAsStringSync();

    expect(sql, contains("task_version = '01ai_models_20260829_v1'"));
    expect(sql, contains("category = 'models'"));
    expect(sql, contains('correct_answers between 0 and 3'));
    expect(sql, contains('total_questions = 3'));
    expect(sql, contains('self_rating between 1 and 5'));
    expect(sql, contains('to anon, authenticated'));
    expect(sql, isNot(contains('user_id')));
    expect(sql, isNot(contains('session_id')));
    expect(sql, isNot(contains('answer_text')));
    expect(sql, isNot(contains('free_text')));
  });

  test('model lesson renders its task and records task-bounded analytics', () {
    final page = File(
      'lib/pages/gemini_university_v2_page.dart',
    ).readAsStringSync();

    expect(page, contains("provider == '01ai' && category == 'models'"));
    expect(page, contains('AiUniversityModelSelectionTaskCard('));
    expect(page, contains('AiUniversityLearningOutcomeTask.modelSelection'));
    expect(
      page,
      contains('_modelSelectionLearningOutcomeAnalytics.recordCompleted'),
    );
  });
}
