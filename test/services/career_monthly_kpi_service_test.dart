import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/career_monthly_kpi.dart';
import 'package:my_web_app/services/career_monthly_kpi_service.dart';

void main() {
  test('summarize calculates completion and average monthly progress', () {
    final items = <CareerMonthlyKpi>[
      const CareerMonthlyKpi(
        monthKey: '2026-05',
        annualGoal: 'Win promotion readiness',
        category: 'career',
        metricName: 'Portfolio demos',
        targetValue: 4,
        actualValue: 2,
        unit: 'items',
      ),
      const CareerMonthlyKpi(
        monthKey: '2026-05',
        annualGoal: 'Win promotion readiness',
        category: 'career',
        metricName: 'Stakeholder reviews',
        targetValue: 2,
        actualValue: 2,
        unit: 'reviews',
      ),
      const CareerMonthlyKpi(
        monthKey: '2026-04',
        annualGoal: 'Old goal',
        category: 'career',
        metricName: 'Ignored',
        targetValue: 1,
        actualValue: 1,
      ),
    ];

    final summary = CareerMonthlyKpiService.summarize(items, '2026-05');

    expect(summary.totalMetrics, 2);
    expect(summary.completedMetrics, 1);
    expect(summary.averageProgress, 0.75);
    expect(summary.primaryGoal, 'Win promotion readiness');
  });

  test('buildMonthlyReport emits a close report for the selected month', () {
    final report = CareerMonthlyKpiService.buildMonthlyReport(
      const <CareerMonthlyKpi>[
        CareerMonthlyKpi(
          monthKey: '2026-05',
          annualGoal: 'Build career assets',
          category: 'career',
          metricName: 'Published case studies',
          targetValue: 2,
          actualValue: 1,
          unit: 'docs',
          reflection: 'One draft shipped.',
          nextAction: 'Schedule the second case study.',
        ),
      ],
      '2026-05',
    );

    expect(report, contains('# Career Monthly Close: 2026-05'));
    expect(report, contains('Published case studies'));
    expect(report, contains('50%'));
    expect(report, contains('Schedule the second case study.'));
  });

  test('fromHubItem reads metadata values from tools-hub records', () {
    final item = CareerMonthlyKpi.fromHubItem({
      'id': 'abc',
      'created_at': '2026-05-03T00:00:00Z',
      'metadata': {
        'month_key': '2026-05',
        'annual_goal': 'Career system',
        'category': 'career',
        'metric_name': 'Mentor reviews',
        'target_value': '3',
        'actual_value': 1,
        'unit': 'calls',
      },
    });

    expect(item.id, 'abc');
    expect(item.monthKey, '2026-05');
    expect(item.targetValue, 3);
    expect(item.actualValue, 1);
    expect(item.achievementPercentLabel, '33%');
  });
}
