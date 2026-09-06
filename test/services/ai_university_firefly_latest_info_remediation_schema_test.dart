import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/migrations/'
    '20260903095000_remediate_adobe_firefly_latest_info_course.sql',
  );

  test('Firefly latest lesson has dated official release evidence', () {
    final sql = migration.readAsStringSync();

    expect(sql, contains('Adobe公式情報確認日: 2026-09-03 (JST)'));
    expect(sql, contains('公式ページ最終更新: 2026-08-19'));
    expect(sql, contains('最新release month: 2026-08'));
    expect(sql, contains('一元化されたワークスペース'));
    expect(sql, contains('最大500個の入力アセット'));
    expect(sql, contains('30分workflow比較課題'));
    expect(sql, contains('freshness threshold: 45日'));
    expect(sql, contains('stale fallback'));
    expect(
      sql,
      contains(
        'https://helpx.adobe.com/firefly/web/whats-new/'
        'new-features/whats-new.html',
      ),
    );
    expect(sql, contains("where provider = 'adobe_firefly'"));
    expect(sql, contains("and category = 'news'"));
  });

  test('workflow outcomes are finite, anonymous, and service-role summarized',
      () {
    final sql = migration.readAsStringSync();

    expect(sql, contains("task_version = 'adobe_firefly_news_20260903_v1'"));
    expect(sql, contains('release_feature text'));
    expect(sql, contains('output_kind text'));
    expect(sql, contains('input_asset_count integer'));
    expect(sql, contains('legacy_workflow_minutes between 1 and 120'));
    expect(sql, contains('latest_workflow_minutes between 1 and 120'));
    expect(sql, contains('revision_count between 0 and 20'));
    expect(sql, contains('usable_output boolean'));
    expect(sql, contains('workplace_applicable boolean'));
    expect(sql, contains("'adopt', 'pilot', 'defer'"));
    expect(sql, contains('ai_university_firefly_news_outcome_summary'));
    expect(sql, contains('average_minutes_saved'));
    expect(sql, contains('usable_output_percent'));
    expect(sql, contains('workplace_applicable_percent'));
    expect(sql, contains('to anon, authenticated'));
    expect(sql, contains('to service_role'));
    expect(sql, isNot(contains('user_id text')));
    expect(sql, isNot(contains('session_id text')));
    expect(sql, isNot(contains('input_text')));
    expect(sql, isNot(contains('output_text')));
  });

  test('Adobe Firefly news row renders the bounded comparison task', () {
    final page = File(
      'lib/pages/gemini_university_v2_page.dart',
    ).readAsStringSync();

    expect(
      page,
      contains("provider == 'adobe_firefly' && category == 'news'"),
    );
    expect(page, contains('AiUniversityFireflyLatestInfoTaskCard('));
    expect(
      page,
      contains('AiUniversityLearningOutcomeTask.fireflyLatestInfo'),
    );
    expect(page, contains('recordFireflyLatestInfoCompleted'));
  });
}
