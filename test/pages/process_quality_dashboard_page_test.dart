import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/process_quality_metric.dart';
import 'package:my_web_app/pages/process_quality_dashboard_page.dart';
import 'package:my_web_app/services/process_quality_metric_service.dart';

class _FakeProcessQualityMetricRepository
    implements ProcessQualityMetricRepository {
  _FakeProcessQualityMetricRepository(this.metrics);

  final List<ProcessQualityMetric> metrics;
  ProcessQualityMetricDraft? lastDraft;

  @override
  Future<List<ProcessQualityMetric>> list() async =>
      List<ProcessQualityMetric>.unmodifiable(metrics);

  @override
  Future<ProcessQualityMetric> add(ProcessQualityMetricDraft draft) async {
    lastDraft = draft;
    final metric = ProcessQualityMetric(
      id: 'saved-${metrics.length + 1}',
      projectName: draft.projectName.trim(),
      featureName: draft.featureName.trim(),
      scopeUnit: draft.scopeUnit,
      scopeSize: draft.scopeSize,
      reviewMinutes: draft.reviewMinutes,
      findingCount: draft.findingCount,
      minimumReviewDensity: draft.minimumReviewDensity,
      minimumFindingDensity: draft.minimumFindingDensity,
      reviewedAt: draft.reviewedAt,
    );
    metrics.insert(0, metric);
    return metric;
  }
}

void main() {
  testWidgets('shows calculated densities and warnings', (tester) async {
    final repository = _FakeProcessQualityMetricRepository(
      <ProcessQualityMetric>[
        ProcessQualityMetric(
          id: 'metric-1',
          projectName: 'Website',
          featureName: 'Checkout',
          scopeUnit: 'pages',
          scopeSize: 4,
          reviewMinutes: 20,
          findingCount: 1,
          minimumReviewDensity: 8,
          minimumFindingDensity: 0.5,
          reviewedAt: DateTime.utc(2026, 9, 3),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ProcessQualityDashboardPage(repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('プロセス品質ダッシュボード'), findsOneWidget);
    final chart = find.byKey(const ValueKey<String>('quality-density-chart'));
    await tester.scrollUntilVisible(
      chart,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(chart, findsOneWidget);
    expect(find.textContaining('レビュー 5.00分/単位'), findsOneWidget);
    expect(find.textContaining('指摘 0.25件/単位'), findsOneWidget);
    expect(find.text('要確認'), findsOneWidget);
  });

  testWidgets('saves a valid review record', (tester) async {
    final repository = _FakeProcessQualityMetricRepository(
      <ProcessQualityMetric>[],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ProcessQualityDashboardPage(repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('quality-project')),
      'Product A',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('quality-feature')),
      'Search',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('quality-scope-size')),
      '2',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('quality-review-minutes')),
      '20',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('quality-findings')),
      '4',
    );
    final save = find.byKey(const ValueKey<String>('quality-save'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(repository.lastDraft?.projectName, 'Product A');
    expect(repository.lastDraft?.featureName, 'Search');
    expect(repository.lastDraft?.scopeSize, 2);
    expect(repository.lastDraft?.reviewMinutes, 20);
    expect(repository.lastDraft?.findingCount, 4);
    expect(find.text('レビュー記録を保存しました。'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('基準到達'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('基準到達'), findsOneWidget);
  });
}
