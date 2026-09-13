import 'dart:io';

import 'package:my_web_app/utils/home_feature_request_failure.dart';
import 'package:test/test.dart';

void main() {
  test('three Home feature-request failures expose stable safe copy', () {
    expect(
      HomeFeatureRequestFailure.values.map((failure) => failure.code).toSet(),
      {
        'attachment_selection_failed',
        'attachment_analysis_failed',
        'feature_request_submission_failed',
      },
    );

    for (final failure in HomeFeatureRequestFailure.values) {
      expect(failure.userMessage, isNotEmpty);
      expect(failure.retryLabel, isNotEmpty);
      expect(failure.userMessage, isNot(contains('Exception')));
      expect(failure.userMessage, isNot(contains('エラー:')));
    }
  });

  test('all three Home catches use safe copy and a retry action', () {
    final source = File('lib/pages/home_page.dart').readAsStringSync();

    for (final failure in HomeFeatureRequestFailure.values) {
      expect(
        source,
        contains('HomeFeatureRequestFailure.${failure.name}'),
        reason: '${failure.code} must be wired into Home',
      );
    }
    expect(
      RegExp(r'_showFeatureRequestFailure\(').allMatches(source),
      hasLength(4),
    );
    expect(source, isNot(contains("Text('画像の選択に失敗しました: \$e')")));
    expect(source, isNot(contains("Text('画像AI診断に失敗しました: \$e')")));
    expect(source, isNot(contains("Text('追加要望の登録に失敗しました: \$e')")));
  });
}
