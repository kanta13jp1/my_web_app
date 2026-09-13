import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/home_funnel_analytics.dart';

void main() {
  group('HomeFunnelAnalytics', () {
    test('tracks home section view and hero action clicked', () {
      final events = <Map<String, dynamic>>[];
      final analytics = HomeFunnelAnalytics(
        onTrack: (name, props) {
          events.add(<String, dynamic>{'event': name, ...props});
        },
      );

      analytics.trackSectionView(sectionId: 'todays_action', isExpanded: true);
      analytics.trackHeroActionClicked(
        actionId: 'open_asset_management',
        destinationRoute: '/asset-management',
      );

      expect(events.length, 2);
      expect(events[0]['event'], 'home_section_view');
      expect(events[0]['section_id'], 'todays_action');
      expect(events[0]['is_expanded'], true);

      expect(events[1]['event'], 'home_hero_action_clicked');
      expect(events[1]['action_id'], 'open_asset_management');
      expect(events[1]['destination_route'], '/asset-management');
    });

    test('tracks feature request funnel events', () {
      final events = <Map<String, dynamic>>[];
      final analytics = HomeFunnelAnalytics(
        onTrack: (name, props) {
          events.add(<String, dynamic>{'event': name, ...props});
        },
      );

      analytics.trackFeatureRequestStart(sourceSection: 'home_bottom_bar');
      analytics.trackFeatureRequestComplete(
        hasAttachment: true,
        textLengthBucket: 100,
      );

      expect(events.length, 2);
      expect(events[0]['event'], 'home_feature_request_start');
      expect(events[0]['source_section'], 'home_bottom_bar');

      expect(events[1]['event'], 'home_feature_request_complete');
      expect(events[1]['has_attachment'], true);
      expect(events[1]['text_length_bucket'], 100);
    });
  });
}
