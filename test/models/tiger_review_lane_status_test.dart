import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/tiger_review_lane_status.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('treats an empty Issue trace as not applicable', () {
    final trace = TigerCountermeasureTrace.fromJson(<String, dynamic>{
      'issue': <String, dynamic>{},
    });

    expect(trace.issue, isNull);
  });

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

      expect(status.schemaVersion, 4);
      expect(status.lane, testCase.$2);
      expect(status.history, isNotEmpty);
      expect(status.history.first.countermeasure.label, isNotEmpty);
      final reviewOnly = status.history.where(
        (entry) => entry.reviewStatus == 'review_only',
      );
      expect(
        reviewOnly.every((entry) => entry.countermeasure.issue != null),
        isTrue,
        reason: '未対策レビューにはIssue追跡情報が必要です。',
      );
      if (testCase.$3 == 'reviewers') {
        expect(status.entries, hasLength(125));
      }
      if (testCase.$3 == 'none') {
        expect(status.entries, isEmpty);
      }
    });
  }

  test('parses reconciled remediation and release proof', () {
    final trace = TigerCountermeasureTrace.fromJson(<String, dynamic>{
      'issue': <String, dynamic>{
        'number': 10,
        'url': 'https://github.com/kanta13jp1/my_web_app/issues/10',
        'github_state': 'CLOSED',
        'remediation_state': 'production_verified',
        'queue_status': 'SUCCEEDED',
        'synced_at': '2026-08-28T00:00:00Z',
      },
      'implementation': <String, dynamic>{
        'pr_number': 11,
        'pr_url': 'https://github.com/kanta13jp1/my_web_app/pull/11',
        'commit_sha': 'abc1234',
        'workflow_run': '123',
        'workflow_url':
            'https://github.com/kanta13jp1/my_web_app/actions/runs/123',
        'release_status': 'passed',
      },
    });

    expect(trace.issue?.remediationState, 'production_verified');
    expect(trace.issue?.queueStatus, 'SUCCEEDED');
    expect(trace.issue?.syncedAt, DateTime.utc(2026, 8, 28));
    expect(trace.implementation?.prNumber, 11);
    expect(trace.implementation?.workflowRun, '123');
  });
}
