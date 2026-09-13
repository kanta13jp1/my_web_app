import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_pain_metric_analytics.dart';

void main() {
  group('AssetPainMetricAnalytics', () {
    test('tracks privacy-safe rounded pain metric view event', () {
      final events = <Map<String, dynamic>>[];
      final analytics = AssetPainMetricAnalytics(
        onTrack: (name, props) {
          events.add(<String, dynamic>{'event': name, ...props});
        },
      );

      analytics.trackPainMetricView(
        dailyBleed: 3180,
        lostLaborHours: 1.272,
        stolenFuture: 572400,
      );

      expect(events.length, 1);
      final ev = events.first;
      expect(ev['event'], 'asset_pain_metric_view');
      expect(ev['daily_bleed_bucket'], 3200);
      expect(ev['lost_labor_hours_bucket'], 1.3);
      expect(ev['stolen_future_bucket'], 572000);
      expect(ev['has_bleed'], true);
    });

    test('tracks action start and action complete events', () {
      final events = <Map<String, dynamic>>[];
      final analytics = AssetPainMetricAnalytics(
        onTrack: (name, props) {
          events.add(<String, dynamic>{'event': name, ...props});
        },
      );

      analytics.trackActionStart(
        actionType: 'debt_repayment',
        targetAccountId: 'mobit',
      );
      analytics.trackActionComplete(
        actionType: 'debt_repayment',
        targetAccountId: 'mobit',
        reducedBleedAmount: 520,
      );

      expect(events.length, 2);
      expect(events[0]['event'], 'asset_pain_action_start');
      expect(events[0]['action_type'], 'debt_repayment');
      expect(events[1]['event'], 'asset_pain_action_complete');
      expect(events[1]['reduced_bleed_bucket'], 500);
    });
  });
}
