import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/billing_service.dart';
import 'package:my_web_app/services/growth_acquisition_service.dart';

void main() {
  test('builds supporter attribution from X share URL parameters', () {
    final attribution = BillingSupporterAttribution.fromUri(
      Uri.parse(
        'https://example.com/subscription-billing'
        '?utm_source=x'
        '&utm_medium=ai_share'
        '&utm_campaign=first_user_growth'
        '&utm_content=daily_briefing'
        '&source_log_id=abc123',
      ),
    );

    expect(attribution.toJson(), {
      'utm_source': 'x',
      'utm_medium': 'ai_share',
      'utm_campaign': 'first_user_growth',
      'utm_content': 'daily_briefing',
      'experiment_key': 'first_user_growth',
      'variant': 'daily_briefing',
      'source_log_id': 'abc123',
      'landing_touchpoint': 'subscription_billing',
    });
  });

  test('drops blank supporter attribution values', () {
    const attribution = BillingSupporterAttribution(
      utmSource: ' ',
      variant: 'question_post',
    );

    expect(attribution.toJson(), {'variant': 'question_post'});
  });

  test(
    'keeps first-user X attribution after signup removed URL parameters',
    () {
      final attribution = BillingSupporterAttribution.fromUri(
        Uri.parse('https://example.com/subscription-billing?entry=onboarding'),
        fallbackTouchpoint: GrowthAcquisitionService.touchXFirstUserGrowth,
      );

      expect(attribution.toJson(), {
        'utm_source': 'x',
        'utm_medium': 'organic',
        'utm_campaign': 'first_user_growth',
        'utm_content': 'activation_to_paid',
        'experiment_key': 'first_user_growth',
        'variant': 'activation_to_paid',
        'landing_touchpoint': 'touch_x_first_user_growth',
      });
    },
  );
}
