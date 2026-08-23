import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/landing_trial_prompt_builder.dart';

void main() {
  test('builds a structured prompt from the concern and five answers', () {
    final prompt = LandingTrialPromptBuilder.build(
      concern: 'サブスクの支払いが多く、どれから見直すか決められない',
      answers: const <String>[
        '解約候補が1件決まっている',
        '今日中に最初の一歩まで',
        '10分以内・追加費用なし',
        '請求一覧までは確認した',
        '家族が使うサービスは勝手に止めない',
      ],
    );

    expect(prompt, contains('相談:サブスクの支払いが多く'));
    expect(prompt, contains('目標:解約候補が1件決まっている'));
    expect(prompt, contains('期限:今日中に最初の一歩まで'));
    expect(prompt, contains('条件:10分以内・追加費用なし'));
    expect(prompt, contains('試行:請求一覧までは確認した'));
    expect(prompt, contains('回避:家族が使うサービスは勝手に止めない'));
    expect(prompt.runes.length, lessThanOrEqualTo(280));
  });

  test('normalizes and safely truncates long answers to the API limit', () {
    final prompt = LandingTrialPromptBuilder.build(
      concern: '😀'.padRight(300, '長'),
      answers: List<String>.filled(5, '回答'.padRight(100, '長')),
    );

    expect(prompt.runes.length, lessThanOrEqualTo(280));
    expect(prompt, contains('…'));
    expect(prompt, isNot(contains('\uFFFD')));
  });

  test('rejects an incomplete answer set', () {
    expect(
      () => LandingTrialPromptBuilder.build(
        concern: '相談',
        answers: const <String>['回答'],
      ),
      throwsArgumentError,
    );
  });
}
