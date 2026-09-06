import 'package:flutter/foundation.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

import 'posthog_web_initializer_stub.dart'
    if (dart.library.js_interop) 'posthog_web_initializer_web.dart';

enum PhilosophyFunnelStage {
  pageView,
  quickInventoryView,
  ctaClick,
  firstActionComplete,
  feedback,
}

extension PhilosophyFunnelStageValue on PhilosophyFunnelStage {
  String get eventValue => switch (this) {
        PhilosophyFunnelStage.pageView => 'page_view',
        PhilosophyFunnelStage.quickInventoryView => 'quick_inventory_view',
        PhilosophyFunnelStage.ctaClick => 'cta_click',
        PhilosophyFunnelStage.firstActionComplete => 'first_action_complete',
        PhilosophyFunnelStage.feedback => 'feedback',
      };
}

const Set<String> philosophyFunnelAllowedPropertyKeys = <String>{
  'path',
  'entry_mode',
  'destination',
  'department_id',
  'action_id',
  'feedback_value',
  'unresolved_area',
};

/// One privacy-limited event in the philosophy first-action funnel.
///
/// Free text, account identifiers, and form contents are deliberately not
/// accepted by the default PostHog adapter. Only coarse allowlisted choices
/// can leave the browser.
class PhilosophyFunnelEvent {
  const PhilosophyFunnelEvent({
    required this.stage,
    this.properties = const <String, Object>{},
  });

  final PhilosophyFunnelStage stage;
  final Map<String, Object> properties;

  Map<String, Object> get safeProperties => <String, Object>{
        'stage': stage.eventValue,
        for (final entry in properties.entries)
          if (philosophyFunnelAllowedPropertyKeys.contains(entry.key))
            entry.key: entry.value,
      };
}

abstract interface class PhilosophyFunnelAnalytics {
  Future<void> capture(PhilosophyFunnelEvent event);
}

/// Anonymous, best-effort PostHog adapter for the public philosophy page.
///
/// Person profiles, lifecycle capture, surveys, and session replay remain off.
/// The feature continues to work when PostHog is unavailable or unconfigured.
class PostHogPhilosophyFunnelAnalytics implements PhilosophyFunnelAnalytics {
  const PostHogPhilosophyFunnelAnalytics();

  static const String _projectToken = String.fromEnvironment(
    'POSTHOG_PROJECT_TOKEN',
  );
  static const String _host = String.fromEnvironment(
    'POSTHOG_HOST',
    defaultValue: 'https://us.i.posthog.com',
  );
  static const String _eventName = 'philosophy_funnel_stage';

  static Future<void>? _initialization;
  static bool _enabled = false;

  Future<void> _initialize() => _initialization ??= _initializeOnce();

  Future<void> _initializeOnce() async {
    if (_projectToken.isEmpty) return;

    try {
      await initializePostHogWeb(projectToken: _projectToken, host: _host);
      final config = PostHogConfig(_projectToken)
        ..host = _host
        ..captureApplicationLifecycleEvents = false
        ..capturePushNotificationOpened = false
        ..capturePushNotificationSubscriptions = false
        ..personProfiles = PostHogPersonProfiles.never
        ..sendFeatureFlagEvents = false
        ..sessionReplay = false
        ..surveys = false;
      await Posthog().setup(config);
      _enabled = true;
    } catch (error) {
      _enabled = false;
      debugPrint('Philosophy analytics disabled: $error');
    }
  }

  @override
  Future<void> capture(PhilosophyFunnelEvent event) async {
    await _initialize();
    if (!_enabled) return;

    try {
      await Posthog().capture(
        eventName: _eventName,
        properties: event.safeProperties,
      );
    } catch (error) {
      debugPrint('Philosophy funnel event failed: $error');
    }
  }
}
