import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/process_quality_metric.dart';

void main() {
  group('ProcessQualityMetric', () {
    test('calculates both densities and threshold warnings', () {
      final metric = ProcessQualityMetric(
        id: 'metric-1',
        projectName: 'Project',
        featureName: 'Checkout',
        scopeUnit: 'features',
        scopeSize: 4,
        reviewMinutes: 40,
        findingCount: 2,
        minimumReviewDensity: 8,
        minimumFindingDensity: 0.75,
        reviewedAt: DateTime.utc(2026, 9, 3),
      );

      expect(metric.reviewDensity, 10);
      expect(metric.findingDensity, 0.5);
      expect(metric.reviewDensityBelowThreshold, isFalse);
      expect(metric.findingDensityBelowThreshold, isTrue);
      expect(metric.needsAttention, isTrue);
    });

    test('parses numeric database values returned as strings', () {
      final metric = ProcessQualityMetric.fromJson(<String, dynamic>{
        'id': 'metric-2',
        'project_name': 'Project',
        'feature_name': '',
        'scope_unit': 'pages',
        'scope_size': '2.5',
        'review_minutes': '25',
        'finding_count': '5',
        'minimum_review_density': '5.0',
        'minimum_finding_density': '1.0',
        'reviewed_at': '2026-09-03T00:00:00Z',
      });

      expect(metric.scopeSize, 2.5);
      expect(metric.reviewDensity, 10);
      expect(metric.findingDensity, 2);
      expect(metric.reviewedAt, DateTime.utc(2026, 9, 3));
    });

    test('draft trims names and uses the authenticated user id', () {
      final draft = ProcessQualityMetricDraft(
        projectName: '  Project  ',
        featureName: '  Feature  ',
        scopeUnit: 'documents',
        scopeSize: 3,
        reviewMinutes: 15,
        findingCount: 1,
        minimumReviewDensity: 5,
        minimumFindingDensity: 0.25,
        reviewedAt: DateTime.utc(2026, 9, 3),
      );

      expect(
        draft.toInsertRow('user-1'),
        containsPair('user_id', 'user-1'),
      );
      expect(draft.toInsertRow('user-1')['project_name'], 'Project');
      expect(draft.toInsertRow('user-1')['feature_name'], 'Feature');
    });
  });
}
