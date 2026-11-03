import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/resource_optimization_service.dart';

void main() {
  test('analyze clamps the window and returns a typed report', () async {
    Map<String, dynamic>? received;
    final service = ResourceOptimizationService(
      invoker: (body) async {
        received = body;
        return {
          'success': true,
          'generated_by': 'deterministic',
          'window_days': body['days'],
          'sample_count': 1,
          'correlations': const {},
          'metrics': [
            {
              'habit_id': 'habit-1',
              'habit_title': '読書',
              'sample_count': 1,
              'avg_time_minutes': 10,
              'avg_fatigue_score': 2,
              'avg_goal_contribution_score': 60,
              'resource_cost_index': 30,
              'efficiency_score': 2,
              'is_pareto_optimal': true,
            },
          ],
          'pareto_frontier': const [],
          'mentor_summary': '継続します。',
          'recommendations': const [],
          'scaling_plan': const [],
        };
      },
    );

    final report = await service.analyze(days: 999);

    expect(received, {
      'days': 365,
      'use_ai': false,
      'ai_data_consent': false,
    });
    expect(report.windowDays, 365);
    expect(report.metrics.single.habitTitle, '読書');
  });

  test('AI analysis sends both opt-in flags and keeps Edge status', () async {
    Map<String, dynamic>? received;
    final service = ResourceOptimizationService(
      invoker: (body) async {
        received = body;
        return {
          'success': true,
          'generated_by': 'deterministic',
          'ai_status': 'daily_limit',
          'window_days': body['days'],
          'sample_count': 0,
          'correlations': const {},
          'metrics': const [],
          'pareto_frontier': const [],
          'mentor_summary': '統計分析を表示します。',
          'recommendations': const [],
          'scaling_plan': const [],
        };
      },
    );

    final analysis = await service.analyzeWithAiConsent(days: 1);

    expect(received, {
      'days': 7,
      'use_ai': true,
      'ai_data_consent': true,
    });
    expect(analysis.aiStatus, 'daily_limit');
    expect(analysis.report.generatedBy, 'deterministic');
  });

  test('analyze surfaces Edge Function errors', () async {
    final service = ResourceOptimizationService(
      invoker: (_) async => {'success': false, 'error': 'RPC failed'},
    );

    expect(
      () => service.analyze(),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'RPC failed',
        ),
      ),
    );
  });
}
