import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/resource_optimization.dart';

void main() {
  test(
    'report parses correlations, frontier, recommendations, and scaling',
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
    },
  );

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

  test('correlations are finite and clamped to their mathematical range', () {
    final report = ResourceOptimizationReport.fromJson({
      'window_days': 90,
      'correlations': {
        'time_to_performance': 4,
        'fatigue_to_performance': double.nan,
      },
    });

    expect(report.timePerformanceCorrelation, 1);
    expect(report.fatiguePerformanceCorrelation, isNull);
  });

  test('insufficient-data response remains an honest empty recommendation', () {
    final report = ResourceOptimizationReport.fromJson({
      'generated_by': 'deterministic',
      'window_days': 90,
      'sample_count': 6,
      'correlations': {
        'time_to_performance': null,
        'fatigue_to_performance': null,
      },
      'metrics': [
        {
          'habit_id': 'habit-1',
          'habit_title': '英語復習',
          'sample_count': 6,
          'avg_time_minutes': 20,
          'avg_fatigue_score': 3,
          'avg_goal_contribution_score': 70,
          'performance_measurement_source':
              'self_reported_goal_contribution_proxy',
          'performance_is_proxy': true,
          'has_sufficient_data': false,
          'insufficient_data_reason': 'minimum_7_samples_required',
        },
      ],
      'pareto_frontier': const [],
      'mentor_summary': 'データ不足のため断定できません。',
      'recommendations': const [],
      'scaling_plan': const [],
    });

    expect(report.hasData, isTrue);
    expect(report.timePerformanceCorrelation, isNull);
    expect(report.fatiguePerformanceCorrelation, isNull);
    expect(report.paretoFrontier, isEmpty);
    expect(report.recommendations, isEmpty);
    expect(report.scalingPlan, isEmpty);
  });

  test('extra provenance counts do not make default-only rows analyzable', () {
    final report = ResourceOptimizationReport.fromJson({
      'generated_by': 'deterministic',
      'window_days': 90,
      'sample_count': 0,
      'total_recorded_count': 20,
      'analysis_sample_count': 0,
      'performance_measurement_source': 'habit_default_proxy',
      'correlations': const {
        'time_to_performance': null,
        'fatigue_to_performance': null,
      },
      'metrics': const [],
      'pareto_frontier': const [],
      'recommendations': const [],
      'scaling_plan': const [],
    });

    expect(report.hasData, isFalse);
    expect(report.metrics, isEmpty);
    expect(report.paretoFrontier, isEmpty);
    expect(report.recommendations, isEmpty);
    expect(report.scalingPlan, isEmpty);
  });
}
