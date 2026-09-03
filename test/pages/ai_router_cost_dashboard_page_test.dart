import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/ai_router_cost_dashboard_page.dart';
import 'package:my_web_app/services/ai_router_cost_dashboard_service.dart';

void main() {
  testWidgets('renders recommendation and saves selected provider', (
    tester,
  ) async {
    var saved = false;
    var savedRoi = false;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
        if (body['action'] == 'ai_roi.parameter.set') {
          savedRoi = true;
          expect(body['feature_key'], 'summary');
          expect(body['minutes_saved_per_success'], 45);
          return {
            'success': true,
            'parameters': {
              'feature_key': 'summary',
              'minutes_saved_per_success': 45,
              'hourly_value_usd': 60,
              'direct_cost_saving_usd_per_success': 0,
              'avoided_loss_usd_per_success': 0,
              'value_created_usd_per_success': 0,
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
          'roi': {
            'currency': 'USD',
            'overall': {
              'request_count': 2,
              'success_count': 2,
              'api_cost_usd': 0.08,
              'direct_cost_reduction_usd': 60,
              'avoided_loss_usd': 0,
              'value_created_usd': 0,
              'total_benefit_usd': 60,
              'net_benefit_usd': 59.92,
              'roi_pct': 74900,
            },
            'features': [
              {
                'feature_key': 'summary',
                'request_count': 2,
                'success_count': 2,
                'api_cost_usd': 0.08,
                'direct_cost_reduction_usd': 60,
                'avoided_loss_usd': 0,
                'value_created_usd': 0,
                'total_benefit_usd': 60,
                'net_benefit_usd': 59.92,
                'roi_pct': 74900,
                'parameters': {
                  'feature_key': 'summary',
                  'minutes_saved_per_success': 30,
                  'hourly_value_usd': 60,
                  'direct_cost_saving_usd_per_success': 0,
                  'avoided_loss_usd_per_success': 0,
                  'value_created_usd_per_success': 0,
                },
              },
            ],
            'daily_trend': [
              {
                'usage_date': '2026-07-07',
                'request_count': 2,
                'success_count': 2,
                'api_cost_usd': 0.08,
                'direct_cost_reduction_usd': 60,
                'avoided_loss_usd': 0,
                'value_created_usd': 0,
                'total_benefit_usd': 60,
                'net_benefit_usd': 59.92,
                'roi_pct': 74900,
              },
            ],
          },
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
    expect(find.text('AI feature ROI'), findsOneWidget);

    await tester.scrollUntilVisible(find.byTooltip('Apply').first, 250);
    expect(find.textContaining('openai / gpt-4o-mini'), findsWidgets);
    await tester.tap(find.byTooltip('Apply').first);
    await tester.pumpAndSettle();

    expect(saved, isTrue);

    await tester.scrollUntilVisible(
      find.byTooltip('Edit ROI assumptions for summary'),
      250,
    );
    await tester.tap(find.byTooltip('Edit ROI assumptions for summary'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Minutes saved per successful use'),
      '45',
    );
    await tester.tap(find.text('Save assumptions'));
    await tester.pumpAndSettle();

    expect(savedRoi, isTrue);
    expect(tester.takeException(), isNull);
  });
}
