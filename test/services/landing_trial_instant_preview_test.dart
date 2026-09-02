import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/landing_trial_instant_preview.dart';

void main() {
  test('builds a finance preview from finance wording', () {
    final preview = buildLandingTrialInstantPreview(
      '家計の固定費が高く、今月どの支出から見直すべきか決められません',
    );

    expect(preview.action, contains('固定費'));
    expect(preview.reason, contains('契約変更はせず'));
  });

  test('builds a learning preview from learning wording', () {
    final preview = buildLandingTrialInstantPreview(
      '資格の勉強が進まず、どの教材から再開すべきか迷っています',
    );

    expect(preview.action, contains('教材'));
    expect(preview.reason, contains('10分'));
  });

  test('builds a work preview for the public sample prompt', () {
    final preview = buildLandingTrialInstantPreview('仕事が多すぎて、何から始めるか決められない');

    expect(preview.action, contains('止まっている作業'));
    expect(preview.reason, contains('10分'));
  });

  test('uses a bounded generic preview for unmatched wording', () {
    final preview = buildLandingTrialInstantPreview('何から考えればいいか分かりません');

    expect(preview.action, contains('確認する相手か資料'));
    expect(preview.action, isNot(contains('AI')));
  });
}
