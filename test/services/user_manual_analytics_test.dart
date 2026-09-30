import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/user_manual_analytics.dart';

void main() {
  group('UserManualAnalytics', () {
    test('tracks manual view and section navigation', () {
      final events = <Map<String, dynamic>>[];
      final analytics = UserManualAnalytics(
        onTrack: (name, props) {
          events.add(<String, dynamic>{'event': name, ...props});
        },
      );

      analytics.trackManualView(
        initialSection: 'quick_start',
        referralSource: 'settings',
      );
      analytics.trackSectionNavigated(
        sectionId: 'guitar_studio',
        sectionTitle: 'ギター録音スタジオ',
      );

      expect(events.length, 2);
      expect(events[0]['event'], 'user_manual_view');
      expect(events[0]['initial_section'], 'quick_start');
      expect(events[0]['referral_source'], 'settings');

      expect(events[1]['event'], 'user_manual_section_navigated');
      expect(events[1]['section_id'], 'guitar_studio');
      expect(events[1]['section_title'], 'ギター録音スタジオ');
    });

    test('tracks action launched from manual', () {
      final events = <Map<String, dynamic>>[];
      final analytics = UserManualAnalytics(
        onTrack: (name, props) {
          events.add(<String, dynamic>{'event': name, ...props});
        },
      );

      analytics.trackActionLaunched(
        sectionId: 'asset_management',
        targetRoute: '/asset-management',
      );

      expect(events.length, 1);
      expect(events[0]['event'], 'user_manual_action_launched');
      expect(events[0]['section_id'], 'asset_management');
      expect(events[0]['target_route'], '/asset-management');
    });
  });
}
