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
          'roi': {
            'currency': 'USD',
            'overall': {
              'request_count': 3,
              'success_count': 2,
              'api_cost_usd': 0.12,
              'direct_cost_reduction_usd': 4,
              'avoided_loss_usd': 1,
              'value_created_usd': 2,
              'total_benefit_usd': 7,
              'net_benefit_usd': 6.88,
              'roi_pct': 5733.33,
            },
            'features': [
              {
                'feature_key': 'summary',
                'request_count': 3,
                'success_count': 2,
                'api_cost_usd': 0.12,
                'direct_cost_reduction_usd': 4,
                'avoided_loss_usd': 1,
                'value_created_usd': 2,
                'total_benefit_usd': 7,
                'net_benefit_usd': 6.88,
                'roi_pct': 5733.33,
                'parameters': {
                  'feature_key': 'summary',
                  'minutes_saved_per_success': 30,
                  'hourly_value_usd': 4,
                  'direct_cost_saving_usd_per_success': 1,
                  'avoided_loss_usd_per_success': 0.5,
                  'value_created_usd_per_success': 1,
                },
              },
            ],
            'daily_trend': [
              {
                'usage_date': '2026-07-07',
                'request_count': 3,
                'success_count': 2,
                'api_cost_usd': 0.12,
                'direct_cost_reduction_usd': 4,
                'avoided_loss_usd': 1,
                'value_created_usd': 2,
                'total_benefit_usd': 7,
                'net_benefit_usd': 6.88,
                'roi_pct': 5733.33,
              },
            ],
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
    expect(dashboard.roi.overall.roiPct, 5733.33);
    expect(dashboard.roi.features.single.featureKey, 'summary');
    expect(dashboard.roi.features.single.parameters.hourlyValueUsd, 4);
    expect(dashboard.roi.dailyTrend.single.usageDate, '2026-07-07');
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

  test('missing ROI payload remains backward compatible', () async {
    final service = AiRouterCostDashboardService(
      invoker: (_) async => {
        'success': true,
        'overall': <String, dynamic>{},
        'quota': <String, dynamic>{},
        'tasks': <dynamic>[],
      },
    );

    final dashboard = await service.loadDashboard();

    expect(dashboard.roi.currency, 'USD');
    expect(dashboard.roi.overall.roiPct, isNull);
    expect(dashboard.roi.features, isEmpty);
  });

  test('saveRoiParameters sends user estimates', () async {
    final service = AiRouterCostDashboardService(
      invoker: (body) async {
        expect(body['action'], 'ai_roi.parameter.set');
        expect(body['feature_key'], 'summary');
        expect(body['minutes_saved_per_success'], 30);
        expect(body['hourly_value_usd'], 60);
        expect(body['direct_cost_saving_usd_per_success'], 5);
        expect(body['avoided_loss_usd_per_success'], 2);
        expect(body['value_created_usd_per_success'], 3);
        return {
          'success': true,
          'parameters': {
            'feature_key': 'summary',
            'minutes_saved_per_success': 30,
            'hourly_value_usd': 60,
            'direct_cost_saving_usd_per_success': 5,
            'avoided_loss_usd_per_success': 2,
            'value_created_usd_per_success': 3,
          },
        };
      },
    );

    final parameters = await service.saveRoiParameters(
      featureKey: 'summary',
      minutesSavedPerSuccess: 30,
      hourlyValueUsd: 60,
      directCostSavingUsdPerSuccess: 5,
      avoidedLossUsdPerSuccess: 2,
      valueCreatedUsdPerSuccess: 3,
    );

    expect(parameters.featureKey, 'summary');
    expect(parameters.valueCreatedUsdPerSuccess, 3);
  });
}
