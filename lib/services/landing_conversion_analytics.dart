import 'package:flutter/foundation.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

import 'landing_conversion_experiment_service.dart';
import 'posthog_web_initializer_stub.dart'
    if (dart.library.js_interop) 'posthog_web_initializer_web.dart';

abstract interface class LandingConversionAnalytics {
  Future<void> captureExperimentEvent({
    required String eventKey,
    Map<String, Object> properties = const <String, Object>{},
  });
}

/// Privacy-limited, best-effort mirror of the existing Supabase LP funnel.
///
/// Supabase remains the source of truth. This adapter never identifies a user
/// and drops events or properties outside its explicit allowlists.
class PostHogLandingConversionAnalytics implements LandingConversionAnalytics {
  const PostHogLandingConversionAnalytics();

  static const String _projectToken = String.fromEnvironment(
    'POSTHOG_PROJECT_TOKEN',
  );
  static const String _host = String.fromEnvironment(
    'POSTHOG_HOST',
    defaultValue: 'https://us.i.posthog.com',
  );
  static const String _eventName = 'landing_conversion_stage';

  static const Set<String> _allowedProperties = <String>{
    'path',
    'viewport',
    'utm_source',
    'utm_medium',
    'utm_campaign',
    'referral_present',
  };

  static final RegExp _eventParts = RegExp(
    r'^lp_exp_(h(?:0[1-9]|10))_(control|treatment)_(.+)$',
  );
  static Future<void>? _initialization;
  static bool _enabled = false;

  Future<void> _initialize() {
    return _initialization ??= _initializeOnce();
  }

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
      debugPrint('Landing conversion analytics disabled: $error');
    }
  }

  @override
  Future<void> captureExperimentEvent({
    required String eventKey,
    Map<String, Object> properties = const <String, Object>{},
  }) async {
    if (!LandingConversionExperimentService.isExperimentEventKey(eventKey)) {
      debugPrint('Dropped unapproved landing event: $eventKey');
      return;
    }

    final match = _eventParts.firstMatch(eventKey);
    if (match == null) return;

    await _initialize();
    if (!_enabled) return;

    final stage = match.group(3)!;
    if (!LandingConversionExperimentService.supportedStages.contains(stage)) {
      return;
    }
    final safeProperties = <String, Object>{
      'hypothesis_id': match.group(1)!,
      'variant': match.group(2)!,
      'stage': stage,
      for (final entry in properties.entries)
        if (_allowedProperties.contains(entry.key)) entry.key: entry.value,
    };

    try {
      await Posthog().capture(
        eventName: _eventName,
        properties: safeProperties,
      );
    } catch (error) {
      debugPrint('Landing conversion event failed: $error');
    }
  }
}
