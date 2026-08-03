import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/ai_router_cost_dashboard_service.dart';

void main() {
  test('loadDashboard parses task recommendations and preferences', () async {
    final service = AiRouterCostDashboardService(
      invoker: (body) async {
        expect(body['action'], 'ai_router.cost_dashboard');
        expect(body['days'], 30);
        return {
          'success': true,
          'generated_at': '2026-07-07T00:00:00Z',
          'overall': {
            'total_requests': 3,
            'total_cost_usd': 0.12,
            'candidate_count': 2,
          },
          'quota': {
            'alert_tools': ['anthropic'],
          },
          'tasks': [
            {
              'task': 'summary',
              'label': 'Summary',
              'total_requests': 3,
              'preference': {
                'task': 'summary',
                'provider': 'openai',
                'model': 'gpt-4o-mini',
                'is_enabled': true,
              },
              'recommendation': {
                'task': 'summary',
                'provider': 'openai',
                'model': 'gpt-4o-mini',
                'request_count': 2,
                'success_rate_pct': 100,
                'total_cost_usd': 0.1,
                'avg_cost_usd': 0.05,
                'score': 96.5,
              },
              'candidates': [
                {
                  'task': 'summary',
                  'provider': 'openai',
                  'model': 'gpt-4o-mini',
                  'request_count': 2,
                  'success_rate_pct': 100,
                  'total_cost_usd': 0.1,
                  'avg_cost_usd': 0.05,
                  'score': 96.5,
                },
              ],
            },
          ],
        };
      },
    );

    final dashboard = await service.loadDashboard();

    expect(dashboard.totalRequests, 3);
    expect(dashboard.totalCostUsd, 0.12);
    expect(dashboard.tasks.single.task, 'summary');
    expect(
      dashboard.tasks.single.preference?.displayModel,
      'openai / gpt-4o-mini',
    );
    expect(dashboard.tasks.single.recommendation?.score, 96.5);
  });

  test('savePreference sends the selected provider and model', () async {
    final service = AiRouterCostDashboardService(
      invoker: (body) async {
        expect(body['action'], 'ai_router.preference.set');
        expect(body['task'], 'coding');
        expect(body['provider'], 'groq');
        expect(body['model'], 'llama-3');
        expect(body['is_enabled'], true);
        return {
          'success': true,
          'preference': {
            'task': 'coding',
            'provider': 'groq',
            'model': 'llama-3',
            'is_enabled': true,
          },
        };
      },
    );

    final preference = await service.savePreference(
      task: 'coding',
      provider: 'groq',
      model: 'llama-3',
    );

    expect(preference.task, 'coding');
    expect(preference.displayModel, 'groq / llama-3');
  });
}
