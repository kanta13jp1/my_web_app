import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/landing_conversion_analytics.dart';
import 'package:my_web_app/services/philosophy_funnel_analytics.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'renamed flag option preserves disabled serialized SDK configuration',
    () {
      final config = PostHogConfig('offline-fixture')
        ..sendFeatureFlagEvent = false
        ..captureApplicationLifecycleEvents = false
        ..capturePushNotificationOpened = false
        ..capturePushNotificationSubscriptions = false
        ..personProfiles = PostHogPersonProfiles.never
        ..sessionReplay = false
        ..surveys = false;
      final values = config.toMap();
      expect(values['sendFeatureFlagEvents'], isFalse);
      expect(values['captureApplicationLifecycleEvents'], isFalse);
      expect(values['capturePushNotificationOpened'], isFalse);
      expect(values['capturePushNotificationSubscriptions'], isFalse);
      expect(values['personProfiles'], 'never');
      expect(values['sessionReplay'], isFalse);
      expect(values['surveys'], isFalse);
    },
  );

  test(
    'unconfigured adapters never initialize or capture through the plugin',
    () async {
      expect(const String.fromEnvironment('POSTHOG_PROJECT_TOKEN'), isEmpty);
      var calls = 0;
      const channel = MethodChannel('posthog_flutter');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        calls++;
        return null;
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      await const PostHogLandingConversionAnalytics().captureExperimentEvent(
        eventKey: 'lp_exp_h01_control_page_view',
      );
      await const PostHogPhilosophyFunnelAnalytics().capture(
        const PhilosophyFunnelEvent(stage: PhilosophyFunnelStage.pageView),
      );
      expect(calls, 0);
    },
  );
}
