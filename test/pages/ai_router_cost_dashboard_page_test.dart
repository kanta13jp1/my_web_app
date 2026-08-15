import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/ai_router_cost_dashboard_page.dart';
import 'package:my_web_app/services/ai_router_cost_dashboard_service.dart';

void main() {
  testWidgets('renders recommendation and saves selected provider', (
    tester,
  ) async {
    var saved = false;
    final service = AiRouterCostDashboardService(
      invoker: (body) async {
        if (body['action'] == 'ai_router.preference.set') {
          saved = true;
          expect(body['task'], 'summary');
          expect(body['provider'], 'openai');
          expect(body['model'], 'gpt-4o-mini');
          return {
            'success': true,
            'preference': {
              'task': 'summary',
              'provider': 'openai',
              'model': 'gpt-4o-mini',
              'is_enabled': true,
            },
          };
        }
        return {
          'success': true,
          'generated_at': '2026-07-07T00:00:00Z',
          'overall': {
            'total_requests': 2,
            'total_cost_usd': 0.08,
            'candidate_count': 1,
          },
          'quota': {'alert_tools': []},
          'tasks': [
            {
              'task': 'summary',
              'label': 'Summary',
              'total_requests': 2,
              'recommendation': {
                'task': 'summary',
                'provider': 'openai',
                'model': 'gpt-4o-mini',
                'request_count': 2,
                'success_rate_pct': 100,
                'total_cost_usd': 0.08,
                'avg_cost_usd': 0.04,
                'score': 98,
              },
              'candidates': [
                {
                  'task': 'summary',
                  'provider': 'openai',
                  'model': 'gpt-4o-mini',
                  'request_count': 2,
                  'success_rate_pct': 100,
                  'total_cost_usd': 0.08,
                  'avg_cost_usd': 0.04,
                  'score': 98,
                },
              ],
            },
          ],
        };
      },
    );

    await tester.pumpWidget(
      MaterialApp(home: AiRouterCostDashboardPage(service: service)),
    );
    await tester.pumpAndSettle();

    expect(find.text('AI Router Cost'), findsOneWidget);
    expect(find.textContaining('openai / gpt-4o-mini'), findsWidgets);

    await tester.tap(find.byTooltip('Apply').first);
    await tester.pumpAndSettle();

    expect(saved, isTrue);
  });
}
