import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/migrations/'
    '20260903103000_remediate_01ai_yi_introduction_course.sql',
  );

  test('01.AI introduction has a dated four-layer official-source map', () {
    final sql = migration.readAsStringSync();

    expect(sql, contains('公式情報確認日: 2026-09-03 (JST)'));
    expect(sql, contains('現在の4層マップ'));
    expect(sql, contains('01.AI'));
    expect(sql, contains('Yi'));
    expect(sql, contains('WorldWise Enterprise LLM Platform'));
    expect(sql, contains('TrueNorth'));
    expect(sql, contains('学習後に説明できるべき3項目'));
    expect(sql, contains('5分の分類課題'));
    expect(sql, contains('https://www.01.ai/'));
    expect(sql, contains('https://github.com/01-ai/Yi'));
    expect(sql, contains('https://www.01.ai/TrueNorth.html'));
    expect(
      sql,
      contains("where id = 'e1712bb5-2bca-4fc0-8347-0529513411d3'::uuid"),
    );
  });

  test(
    'learner evidence is finite, anonymous, and service-role aggregated',
    () {
      final sql = migration.readAsStringSync();

      expect(sql, contains('ai_university_yi_intro_outcome_events'));
      expect(sql, contains('first_attempt_correct_answers between 0 and 3'));
      expect(sql, contains('self_rating between 1 and 5'));
      expect(sql, contains("'yi_repository', 'worldwise_overview'"));
      expect(sql, contains('completion_rate_percent'));
      expect(sql, contains('first_attempt_accuracy_percent'));
      expect(sql, contains('average_self_rating'));
      expect(sql, contains('next_page_correct_percent'));
      expect(sql, contains('to anon, authenticated'));
      expect(sql, contains('to service_role'));
      expect(sql, isNot(contains('user_id text')));
      expect(sql, isNot(contains('session_id text')));
      expect(sql, isNot(contains('answer_text')));
      expect(sql, isNot(contains('free_text text')));
    },
  );

  test('the exact course row renders the bounded introduction task', () {
    final page = File(
      'lib/pages/gemini_university_v2_page.dart',
    ).readAsStringSync();

    expect(page, contains("'e1712bb5-2bca-4fc0-8347-0529513411d3'"));
    expect(page, contains('AiUniversityYiIntroductionTaskCard('));
    expect(page, contains('AiUniversityLearningOutcomeTask.yiIntroduction'));
    expect(page, contains('recordYiIntroductionCompleted'));
  });
}
