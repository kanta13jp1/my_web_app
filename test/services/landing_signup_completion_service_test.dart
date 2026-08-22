import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/growth_acquisition_service.dart';
import 'package:my_web_app/services/landing_conversion_analytics.dart';
import 'package:my_web_app/services/landing_page_adapter.dart';
import 'package:my_web_app/services/landing_signup_completion_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingLandingAdapter extends Fake implements LandingPageAdapter {
  final List<String> eventKeys = <String>[];
  final List<String> visitorIds = <String>[];
  Completer<void>? release;

  @override
  Future<void> recordConversionEvent({
    required String eventKey,
    required String visitorId,
  }) async {
    eventKeys.add(eventKey);
    visitorIds.add(visitorId);
    await release?.future;
  }
}

class _RecordingAcquisitionService extends GrowthAcquisitionService {
  _RecordingAcquisitionService();

  final List<String> notifiedUserIds = <String>[];
  final List<String> funnelStages = <String>[];

  @override
  Future<bool> recordFirstUserFunnelStage({
    required String stage,
    String? visitorId,
    Uri? currentUri,
    SharedPreferences? preferences,
    DateTime? now,
  }) async {
    funnelStages.add('$stage:$visitorId');
    return true;
  }

  @override
  Future<void> notifySignupSuccess({required String? signupUserId}) async {
    if (signupUserId != null) notifiedUserIds.add(signupUserId);
  }
}

class _RecordingConversionAnalytics implements LandingConversionAnalytics {
  final List<String> eventKeys = <String>[];

  @override
  Future<void> captureExperimentEvent({
    required String eventKey,
    Map<String, Object> properties = const <String, Object>{},
  }) async {
    eventKeys.add(eventKey);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const eventKey = 'lp_exp_h04_treatment_signup_complete';
  const visitorId = '00000000-0000-4000-8000-000000000001';
  late _RecordingLandingAdapter adapter;
  late _RecordingAcquisitionService acquisitionService;
  late _RecordingConversionAnalytics conversionAnalytics;
  late DateTime now;
  late LandingSignupCompletionService service;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    adapter = _RecordingLandingAdapter();
    acquisitionService = _RecordingAcquisitionService();
    conversionAnalytics = _RecordingConversionAnalytics();
    now = DateTime.utc(2026, 7, 23, 1);
    service = LandingSignupCompletionService(
      landingPageAdapter: adapter,
      conversionAnalytics: conversionAnalytics,
      acquisitionService: acquisitionService,
      clock: () => now,
    );
  });

  test(
    'completes a matching pending signup and consumes attribution',
    () async {
      await service.markPending(
        email: ' First.User@Example.com ',
        eventKey: eventKey,
        visitorId: visitorId,
      );

      expect(
        await service.completeIfPending(
          signupUserId: 'user-1',
          signupEmail: 'first.user@example.com',
          accountCreatedAt: now.add(const Duration(seconds: 2)),
        ),
        isTrue,
      );

      expect(adapter.eventKeys, <String>[eventKey]);
      expect(adapter.visitorIds, <String>[visitorId]);
      expect(conversionAnalytics.eventKeys, <String>[eventKey]);
      expect(acquisitionService.funnelStages, <String>[
        'signup_complete:$visitorId',
      ]);
      expect(acquisitionService.notifiedUserIds, <String>['user-1']);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.containsKey(LandingSignupCompletionService.storageKey),
        isFalse,
      );
    },
  );

  test('does not consume a pending signup for another email', () async {
    await service.markPending(
      email: 'owner@example.com',
      eventKey: eventKey,
      visitorId: visitorId,
    );

    expect(
      await service.completeIfPending(
        signupUserId: 'user-2',
        signupEmail: 'other@example.com',
      ),
      isFalse,
    );
    expect(adapter.eventKeys, isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.containsKey(LandingSignupCompletionService.storageKey),
      isTrue,
    );
  });

  test('does not count an existing account as a new signup', () async {
    await service.markPending(
      email: 'existing@example.com',
      eventKey: eventKey,
      visitorId: visitorId,
    );

    expect(
      await service.completeIfPending(
        signupUserId: 'existing-user',
        signupEmail: 'existing@example.com',
        accountCreatedAt: now.subtract(const Duration(days: 30)),
      ),
      isFalse,
    );
    expect(adapter.eventKeys, isEmpty);
    expect(acquisitionService.notifiedUserIds, isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.containsKey(LandingSignupCompletionService.storageKey),
      isFalse,
    );
  });

  test('expires stale signup intent without recording a conversion', () async {
    await service.markPending(
      email: 'first@example.com',
      eventKey: eventKey,
      visitorId: visitorId,
    );
    now = now.add(const Duration(hours: 48));

    expect(
      await service.completeIfPending(
        signupUserId: 'user-3',
        signupEmail: 'first@example.com',
      ),
      isFalse,
    );
    expect(adapter.eventKeys, isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.containsKey(LandingSignupCompletionService.storageKey),
      isFalse,
    );
  });

  test(
    'coalesces concurrent LP listener and authenticated-route completion',
    () async {
      await service.markPending(
        email: 'first@example.com',
        eventKey: eventKey,
        visitorId: visitorId,
      );
      adapter.release = Completer<void>();

      final first = service.completeIfPending(
        signupUserId: 'user-4',
        signupEmail: 'first@example.com',
      );
      await Future<void>.delayed(Duration.zero);
      final second = service.completeIfPending(
        signupUserId: 'user-4',
        signupEmail: 'first@example.com',
      );
      adapter.release!.complete();

      expect(await Future.wait(<Future<bool>>[first, second]), <bool>[
        true,
        true,
      ]);
      expect(adapter.eventKeys, hasLength(1));
      expect(acquisitionService.funnelStages, <String>[
        'signup_complete:$visitorId',
      ]);
      expect(acquisitionService.notifiedUserIds, <String>['user-4']);
    },
  );

  test('cancels only the matching failed signup intent', () async {
    await service.markPending(
      email: 'first@example.com',
      eventKey: eventKey,
      visitorId: visitorId,
    );

    expect(await service.cancelPending(email: 'other@example.com'), isFalse);
    expect(await service.cancelPending(email: 'first@example.com'), isTrue);
  });
}
