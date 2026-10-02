import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/growth_acquisition_service.dart';
import 'package:my_web_app/services/growth_mission_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures/growth_weekly_digest_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GrowthMissionService command center fallback', () {
    test(
      'returns cross-functional brief when Supabase is unavailable',
      () async {
        const service = GrowthMissionService();
        final dashboard = GrowthMissionDashboard(
          totalRegisteredUsers: 2,
          todayRegistrations: 0,
          activeUsersToday: 1,
          liveRegisteredUsers: 1,
          liveGuestViewers: 1,
          todayLandingViews: 5,
          monthLandingViews: 18,
          totalLandingViews: 18,
          todayShares: 0,
          referralSnapshot: const ReferralGrowthSnapshot.empty(),
          acquisitionSnapshot: GrowthAcquisitionSnapshot.empty(),
          refreshedAt: DateTime(2026, 3, 23, 10),
        );

        final brief = await service.loadCommandCenterBrief(dashboard);

        expect(brief.stageLabel, 'Pre-PMF');
        expect(brief.focusTags, contains('public-memo-seo'));
        expect(brief.focusTags, contains('registration-bottleneck'));
        expect(brief.departments, hasLength(10));
        expect(
          brief.departments.map((department) => department.id),
          containsAll(<String>[
            'development',
            'product',
            'advertising',
            'pr',
            'sales',
            'marketing',
            'hr',
            'finance',
            'procurement',
            'business-planning',
          ]),
        );
      },
    );

    test('moves to scale-up stage for larger user counts', () async {
      const service = GrowthMissionService();
      final dashboard = GrowthMissionDashboard(
        totalRegisteredUsers: 1200,
        todayRegistrations: 8,
        activeUsersToday: 33,
        liveRegisteredUsers: 15,
        liveGuestViewers: 6,
        todayLandingViews: 80,
        monthLandingViews: 900,
        totalLandingViews: 3000,
        todayShares: 12,
        referralSnapshot: const ReferralGrowthSnapshot.empty(),
        acquisitionSnapshot: GrowthAcquisitionSnapshot.empty(),
        refreshedAt: DateTime(2026, 3, 23, 12),
      );

      final brief = await service.loadCommandCenterBrief(dashboard);

      expect(brief.stageLabel, 'Scale-up');
      expect(brief.stageReason, contains('process'));
    });

    test('buildInviteUrlForCode uses referral route and tracking params', () {
      final inviteUrl = GrowthMissionService.buildInviteUrlForCode('ABCD1234');
      final uri = Uri.parse(inviteUrl);

      expect(uri.path, '/referral');
      expect(uri.queryParameters['ref'], 'ABCD1234');
      expect(uri.queryParameters['utm_source'], 'referral');
      expect(uri.queryParameters['utm_medium'], 'invite');
      expect(uri.queryParameters['utm_campaign'], 'growth_mission');
      expect(uri.queryParameters['v'], 'test2025');
    });

    test('referral snapshot exposes free to Pro conversion rate', () {
      const snapshot = ReferralGrowthSnapshot(
        myReferralCode: null,
        totalReferrals: 5,
        successfulReferrals: 2,
        billingConvertedReferrals: 1,
        billingChannels: <ReferralBillingChannelSnapshot>[
          ReferralBillingChannelSnapshot(
            id: 'referral',
            label: 'Referral',
            totalReferrals: 5,
            proConversions: 1,
          ),
        ],
        pendingReferralCode: null,
      );

      expect(snapshot.freeToProConversionRate, 0.2);
      expect(snapshot.billingChannels.single.freeToProConversionRate, 0.2);
    });

    test('parses edge touchpoint report response shape', () {
      final snapshot = GrowthAcquisitionSnapshot.fromJson(<String, dynamic>{
        'windowDays': 14,
        'startDate': '2026-04-15',
        'endDate': '2026-04-28',
        'touchpoints': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'landing',
            'touchpoint': 'Landing',
            'touches': 12,
            'signups': 3,
          },
        ],
        'importPreviews': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'notion',
            'label': 'Notion previews',
            'previewCount': 5,
          },
        ],
        'importSignupCtaCount': 2,
        'publicMemoSignupCtaCount': 1,
      });

      expect(snapshot.windowDays, 14);
      expect(snapshot.touchpoints.single.label, 'Landing');
      expect(snapshot.touchpoints.single.touchCount, 12);
      expect(snapshot.touchpoints.single.signupSubmitCount, 3);
      expect(snapshot.importPreviews.single.previewCount, 5);
    });

    test('parses the shared weekly digest success fixture', () {
      final envelope = growthWeeklyDigestSuccessFixture();
      final snapshot = WeeklyDigestSnapshot.fromJson(
        Map<String, dynamic>.from(envelope['digest']! as Map),
      );

      expect(snapshot.currentWeekStart, '2026-08-23');
      expect(snapshot.currentWeekEnd, '2026-08-29');
      expect(snapshot.channels, hasLength(2));
      expect(snapshot.channels.first.label, 'ランディングページ');
      expect(snapshot.channels.first.cvr, 5);
      expect(snapshot.signupSubmitTotal, 1);
      expect(snapshot.referralsCompleted, 3);
      expect(snapshot.importCtaClicks, 3);
      expect(snapshot.publicMemoCtaClicks, 2);
      expect(snapshot.decision.owner, isNotEmpty);
      expect(snapshot.decision.id, 'growth-weekly:2026-08-29:profile:cvr-5');
      expect(snapshot.decision.priorityChannelId, 'profile');
      expect(snapshot.decision.targetCvr, 5);
      expect(snapshot.decision.dueDate, '2026-09-05');
      expect(snapshot.previousDecisionOutcome.status, 'met');
      expect(
        snapshot.previousDecisionOutcome.decisionId,
        'growth-weekly:2026-08-22:landing:cvr-5',
      );
      expect(snapshot.previousDecisionOutcome.actualTouches, 20);
    });
  });

  group('Session hygiene', () {
    test('parses active session hygiene status', () {
      final status = SessionHygieneStatus.fromJson(<String, dynamic>{
        'status': 'active',
        'requires_relogin': false,
        'message': 'Session is active.',
        'expires_at': '2026-06-12T10:00:00Z',
      });

      expect(status.state, SessionHygieneState.active);
      expect(status.isActive, isTrue);
      expect(status.requiresRelogin, isFalse);
      expect(status.expiresAt, DateTime.parse('2026-06-12T10:00:00Z'));
    });

    test('parses expired session hygiene status as relogin required', () {
      final status = SessionHygieneStatus.fromJson(<String, dynamic>{
        'status': 'expired',
        'invalidated_at': '2026-06-12T10:05:00Z',
        'reason': 'idle_timeout',
      });

      expect(status.state, SessionHygieneState.expired);
      expect(status.isActive, isFalse);
      expect(status.requiresRelogin, isTrue);
      expect(status.message, SessionHygieneStatus.expiredMessage);
      expect(status.reason, 'idle_timeout');
      expect(status.invalidatedAt, DateTime.parse('2026-06-12T10:05:00Z'));
    });

    test('rotates local presence session after expiry reset', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      const service = GrowthMissionService();
      final firstSessionId = await service.ensureGuestSessionId();

      await service.resetLocalPresenceSession();
      final secondSessionId = await service.ensureGuestSessionId();

      expect(firstSessionId, isNotEmpty);
      expect(secondSessionId, isNotEmpty);
      expect(secondSessionId, isNot(firstSessionId));
    });
  });

  group('GrowthPresenceNavigatorObserver', () {
    test('suppresses duplicate immediate presence syncs for the same route',
        () async {
      final syncCompleter = Completer<void>();
      final service = _FakePresenceService(syncCompleter.future);
      final observer = GrowthPresenceNavigatorObserver(
        service: service,
        acquisitionService: const _NoopGrowthAcquisitionService(),
      );
      addTearDown(observer.dispose);

      final route = MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/asset-management'),
        builder: (_) => const SizedBox.shrink(),
      );

      observer.didPush(route, null);
      observer.didPush(route, null);

      expect(service.syncPresenceCalls, 1);
      expect(service.syncedPagePaths, <String>['/asset-management']);

      syncCompleter.complete();
      await Future<void>.delayed(Duration.zero);
    });

    test('global cooldown suppresses immediate sync across different routes',
        () async {
      final service = _FakePresenceService(Future<void>.value());
      final observer = GrowthPresenceNavigatorObserver(
        service: service,
        acquisitionService: const _NoopGrowthAcquisitionService(),
      );
      addTearDown(observer.dispose);

      observer.didPush(_namedRoute('/a'), null);
      await Future<void>.delayed(Duration.zero);
      // 45秒のグローバル cooldown 内なので、別ページへの遷移でも
      // 即時 sync は走らない (次の heartbeat が正しい path を書く)。
      observer.didPush(_namedRoute('/b'), null);

      expect(service.syncPresenceCalls, 1);
      expect(service.syncedPagePaths, <String>['/a']);
    });

    test(
        'first route "/" (root entry) still records touchpoint and referral '
        'hooks despite matching the initial page path', () async {
      final service = _FakePresenceService(Future<void>.value());
      final acquisition = _RecordingAcquisitionService();
      final observer = GrowthPresenceNavigatorObserver(
        service: service,
        acquisitionService: acquisition,
      );
      addTearDown(observer.dispose);

      // _currentPagePath の初期値 '/' と初回ルート '/' が一致しても、
      // 初回は必ず track する (root 直行流入の獲得計測が沈黙する回帰の防止)。
      observer.didPush(_namedRoute('/'), null);
      await Future<void>.delayed(Duration.zero);

      expect(service.syncPresenceCalls, 1);
      expect(acquisition.recordedPagePaths, <String>['/']);

      // 2回目以降の同一 path は skip される。
      observer.didPush(_namedRoute('/'), null);
      expect(acquisition.recordedPagePaths, <String>['/']);
    });

    test('unnamed routes (dialogs) do not trigger presence writes', () async {
      final service = _FakePresenceService(Future<void>.value());
      final observer = GrowthPresenceNavigatorObserver(
        service: service,
        acquisitionService: const _NoopGrowthAcquisitionService(),
      );
      addTearDown(observer.dispose);

      observer.didPush(_namedRoute('/a'), null);
      await Future<void>.delayed(Duration.zero);
      // ダイアログ等の無名ルートは「直前ページに滞在中」として扱い、
      // presence 書き込みを発生させない。
      observer.didPush(_unnamedRoute(), null);
      observer.didPop(_unnamedRoute(), _namedRoute('/a'));

      expect(service.syncPresenceCalls, 1);
      expect(service.syncedPagePaths, <String>['/a']);
    });
  });
}

MaterialPageRoute<void> _namedRoute(String name) => MaterialPageRoute<void>(
      settings: RouteSettings(name: name),
      builder: (_) => const SizedBox.shrink(),
    );

MaterialPageRoute<void> _unnamedRoute() => MaterialPageRoute<void>(
      builder: (_) => const SizedBox.shrink(),
    );

class _FakePresenceService extends GrowthMissionService {
  _FakePresenceService(this._syncFuture);

  final Future<void> _syncFuture;
  final List<String> syncedPagePaths = <String>[];

  int get syncPresenceCalls => syncedPagePaths.length;

  @override
  bool get isPresenceTrackingAvailable => true;

  @override
  Future<void> syncPresence({required String pagePath}) {
    syncedPagePaths.add(pagePath);
    return _syncFuture;
  }

  @override
  Future<void> capturePendingReferralFromUri({Uri? currentUri}) async {}

  @override
  Future<void> applyPendingReferralIfPossible() async {}
}

class _NoopGrowthAcquisitionService extends GrowthAcquisitionService {
  const _NoopGrowthAcquisitionService();

  @override
  Future<void> recordTouchpointForPagePath(
    String pagePath, {
    Uri? currentUri,
  }) async {}
}

class _RecordingAcquisitionService extends GrowthAcquisitionService {
  final List<String> recordedPagePaths = <String>[];

  @override
  Future<void> recordTouchpointForPagePath(
    String pagePath, {
    Uri? currentUri,
  }) async {
    recordedPagePaths.add(pagePath);
  }
}
