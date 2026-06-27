import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/billing_service.dart';

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
}
