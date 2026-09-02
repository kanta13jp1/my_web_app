import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/philosophy_funnel_analytics.dart';

void main() {
  test('philosophy funnel strips identifiers and free text', () {
    const event = PhilosophyFunnelEvent(
      stage: PhilosophyFunnelStage.feedback,
      properties: <String, Object>{
        'path': '/philosophy',
        'feedback_value': 'helpful',
        'unresolved_area': 'priority',
        'email': 'visitor@example.com',
        'user_id': 'private-user',
        'comment': 'free text must not leave the browser',
      },
    );

    expect(event.safeProperties, <String, Object>{
      'stage': 'feedback',
      'path': '/philosophy',
      'feedback_value': 'helpful',
      'unresolved_area': 'priority',
    });
  });

  test('all funnel stages use stable event values', () {
    expect(
      PhilosophyFunnelStage.values.map((stage) => stage.eventValue),
      <String>[
        'page_view',
        'quick_inventory_view',
        'cta_click',
        'first_action_complete',
        'feedback',
      ],
    );
  });
}