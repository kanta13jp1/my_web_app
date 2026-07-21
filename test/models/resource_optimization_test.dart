import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/resource_optimization.dart';

void main() {
  test('report parses correlations, frontier, recommendations, and scaling',
      () {
    final report = ResourceOptimizationReport.fromJson({
      'generated_by': 'gemini',
      'window_days': 90,
      'sample_count': 12,
      'correlations': {
        'time_to_performance': -0.42,
        'fatigue_to_performance': '0.18',
      },
      'metrics': [
        {
          'habit_id': 'habit-1',
          'habit_title': '英語復習',
          'sample_count': '12',
          'avg_time_minutes': '20.5',
          'avg_fatigue_score': 3.2,
          'avg_goal_contribution_score': 78,
          'resource_cost_index': 52.5,
          'efficiency_score': 1.49,
          'is_pareto_optimal': true,
        },
      ],
      'pareto_frontier': [
        {
          'habit_id': 'habit-1',
          'habit_title': '英語復習',
          'sample_count': 12,
          'avg_time_minutes': 20.5,
          'avg_fatigue_score': 3.2,
          'avg_goal_contribution_score': 78,
          'resource_cost_index': 52.5,
          'efficiency_score': 1.49,
          'is_pareto_optimal': true,
        },
      ],
      'mentor_summary': 'この習慣を基準にします。',
      'recommendations': [
        {'habit_id': 'habit-1', 'title': '英語復習', 'reason': '効率が高い'},
      ],
      'scaling_plan': [
        {
          'stage': 1,
          'duration_days': 7,
          'load_multiplier': 1.1,
          'target': '10%増やす',
          'guardrail': '疲労時は戻す',
        },
      ],
    });

    expect(report.hasData, isTrue);
    expect(report.generatedBy, 'gemini');
    expect(report.timePerformanceCorrelation, -0.42);
    expect(report.fatiguePerformanceCorrelation, 0.18);
    expect(report.metrics.single.averageTimeMinutes, 20.5);
    expect(report.paretoFrontier.single.isParetoOptimal, isTrue);
    expect(report.recommendations.single.habitId, 'habit-1');
    expect(report.scalingPlan.single.loadMultiplier, 1.1);
  });

  test('metric and scaling values are clamped to supported ranges', () {
    final metric = HabitResourceMetric.fromJson({
      'habit_id': 'habit-1',
      'avg_time_minutes': 2000,
      'avg_fatigue_score': 20,
      'avg_goal_contribution_score': -5,
      'resource_cost_index': -1,
      'efficiency_score': -2,
    });
    final step = ResourceScalingStep.fromJson({
      'stage': 9,
      'duration_days': 100,
      'load_multiplier': 3,
    });

    expect(metric.averageTimeMinutes, 1440);
    expect(metric.averageFatigueScore, 10);
    expect(metric.averageGoalContributionScore, 0);
    expect(metric.resourceCostIndex, 0);
    expect(step.stage, 3);
    expect(step.durationDays, 30);
    expect(step.loadMultiplier, 1.25);
  });
}
