import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/tiger_review_lane_status.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final testCase in <(String, String, String)>[
    (
      'assets/data/tiger_reviewer_league_status.json',
      'reviewer_league',
      'reviewers',
    ),
    ('assets/data/tiger_site_review_status.json', 'site_review', 'none'),
    ('assets/data/tiger_course_review_status.json', 'course_review', 'courses'),
    (
      'assets/data/tiger_feature_review_status.json',
      'feature_review',
      'features',
    ),
  ]) {
    test('parses independent ${testCase.$2} asset', () async {
      final source = await rootBundle.loadString(testCase.$1);
      final status = TigerReviewLaneStatus.fromJsonString(source);

      expect(status.schemaVersion, 3);
      expect(status.lane, testCase.$2);
      if (testCase.$3 == 'reviewers') {
        expect(status.entries, hasLength(125));
      }
      if (testCase.$3 == 'none') {
        expect(status.entries, isEmpty);
      }
    });
  }
}
