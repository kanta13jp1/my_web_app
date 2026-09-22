import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/growth_acquisition_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('maps page paths to acquisition touch signals', () {
    expect(
      GrowthAcquisitionService.signalForPagePath('/'),
      GrowthAcquisitionService.touchLanding,
    );
    expect(
      GrowthAcquisitionService.signalForPagePath('/import'),
      GrowthAcquisitionService.touchImport,
    );
    expect(
      GrowthAcquisitionService.signalForPagePath('/public-memo'),
      GrowthAcquisitionService.touchPublicMemo,
    );
    expect(
      GrowthAcquisitionService.signalForPagePath('/referral'),
      GrowthAcquisitionService.touchReferral,
    );
    // R24: サイト流入の 94% を占める公開トラッカーは、UTM 無しの生 URL で
    // 共有されてきたためルートパスからも計上する。
    expect(
      GrowthAcquisitionService.signalForPagePath('/public/local-election-700'),
      GrowthAcquisitionService.touchPublicTracker,
    );
    expect(GrowthAcquisitionService.signalForPagePath('/unknown'), isNull);
  });

  test('public tracker touchpoint resolves its own signup submit signal', () {
    expect(
      GrowthAcquisitionService.resolveSignupSubmitSignal(
        GrowthAcquisitionService.touchPublicTracker,
      ),
      GrowthAcquisitionService.signupSubmitPublicTracker,
    );
  });

  test('billing funnel stages are explicitly allowlisted', () async {
    const service = GrowthAcquisitionService();

    for (final stage in GrowthAcquisitionService.billingFunnelStages) {
      await expectLater(
        service.recordBillingFunnelStage(stage: stage),
        completes,
      );
    }
    await expectLater(
      service.recordBillingFunnelStage(stage: 'funnel_checkout_unknown'),
      throwsArgumentError,
    );
  });

  test('maps preview source types to import preview signals', () {
    expect(
      GrowthAcquisitionService.previewSignalForSourceType('notion'),
      GrowthAcquisitionService.importPreviewNotion,
    );
    expect(
      GrowthAcquisitionService.previewSignalForSourceType('evernote'),
      GrowthAcquisitionService.importPreviewEvernote,
    );
    expect(
      GrowthAcquisitionService.previewSignalForSourceType('markdown'),
      GrowthAcquisitionService.importPreviewMarkdown,
    );
    expect(
      GrowthAcquisitionService.previewSignalForSourceType('unknown'),
      isNull,
    );
  });

  test('maps first-user X UTMs to durable campaign touch signals', () {
    final profileUri = Uri.parse(
      'https://my-web-app-b67f4.web.app/'
      '?utm_source=x&utm_medium=profile&utm_campaign=first_user_growth'
      '&utm_content=profile_bio',
    );
    final shareUri = Uri.parse(
      'https://my-web-app-b67f4.web.app/'
      '?utm_source=x&utm_medium=ai_share&utm_campaign=first_user_growth',
    );

    expect(
      GrowthAcquisitionService.signalForIncomingUri(profileUri),
      GrowthAcquisitionService.touchProfile,
    );
    expect(
      GrowthAcquisitionService.signalForIncomingUri(shareUri),
      GrowthAcquisitionService.touchXFirstUserGrowth,
    );
  });

  test('maps first-user Zenn UTMs to a distinct campaign touch signal', () {
    final uri = Uri.parse(
      'https://my-web-app-b67f4.web.app/'
      '?utm_source=zenn&utm_medium=organic&utm_campaign=first_user_growth'
      '&utm_content=oauth_case_study_a',
    );

    expect(GrowthAcquisitionService.isFirstUserGrowthUri(uri), isTrue);
    expect(
      GrowthAcquisitionService.signalForIncomingUri(uri),
      GrowthAcquisitionService.touchZennFirstUserGrowth,
    );
    expect(
      GrowthAcquisitionService.resolveSignupSubmitSignal(
        GrowthAcquisitionService.touchZennFirstUserGrowth,
      ),
      GrowthAcquisitionService.signupSubmitZennFirstUserGrowth,
    );
  });

  test('maps Product Hunt and Hacker News launch UTMs distinctly', () {
    final cases = <({String source, String touchpoint, String signupSignal})>[
      (
        source: 'producthunt',
        touchpoint: GrowthAcquisitionService.touchProductHuntFirstUserGrowth,
        signupSignal:
            GrowthAcquisitionService.signupSubmitProductHuntFirstUserGrowth,
      ),
      (
        source: 'hackernews',
        touchpoint: GrowthAcquisitionService.touchHackerNewsFirstUserGrowth,
        signupSignal:
            GrowthAcquisitionService.signupSubmitHackerNewsFirstUserGrowth,
      ),
    ];

    for (final item in cases) {
      final uri = Uri.parse(
        'https://my-web-app-b67f4.web.app/'
        '?utm_source=${item.source}&utm_medium=launch'
        '&utm_campaign=first_user_growth&utm_content=launch_v1',
      );

      expect(GrowthAcquisitionService.isFirstUserGrowthUri(uri), isTrue);
      expect(
        GrowthAcquisitionService.signalForIncomingUri(uri),
        item.touchpoint,
      );
      expect(
        GrowthAcquisitionService.resolveSignupSubmitSignal(item.touchpoint),
        item.signupSignal,
      );
    }
  });

  test('maps first-user Reddit UTMs to a distinct campaign touch signal', () {
    final uri = Uri.parse(
      'https://my-web-app-b67f4.web.app/'
      '?utm_source=reddit&utm_medium=community&utm_campaign=first_user_growth'
      '&utm_content=sideproject_launch_a',
    );

    expect(GrowthAcquisitionService.isFirstUserGrowthUri(uri), isTrue);
    expect(
      GrowthAcquisitionService.signalForIncomingUri(uri),
      GrowthAcquisitionService.touchRedditFirstUserGrowth,
    );
    expect(
      GrowthAcquisitionService.resolveSignupSubmitSignal(
        GrowthAcquisitionService.touchRedditFirstUserGrowth,
      ),
      GrowthAcquisitionService.signupSubmitRedditFirstUserGrowth,
    );
  });

  test('resolves signup submit signal from latest touchpoint', () {
    expect(
      GrowthAcquisitionService.resolveSignupSubmitSignal(
        GrowthAcquisitionService.touchProfile,
      ),
      GrowthAcquisitionService.signupSubmitProfile,
    );
    expect(
      GrowthAcquisitionService.resolveSignupSubmitSignal(
        GrowthAcquisitionService.touchImport,
      ),
      GrowthAcquisitionService.signupSubmitImport,
    );
    expect(
      GrowthAcquisitionService.resolveSignupSubmitSignal(
        GrowthAcquisitionService.touchXFirstUserGrowth,
      ),
      GrowthAcquisitionService.signupSubmitXFirstUserGrowth,
    );
    expect(
      GrowthAcquisitionService.resolveSignupSubmitSignal(
        GrowthAcquisitionService.touchPublicMemo,
      ),
      GrowthAcquisitionService.signupSubmitPublicMemo,
    );
    expect(
      GrowthAcquisitionService.resolveSignupSubmitSignal(
        GrowthAcquisitionService.touchReferral,
      ),
      GrowthAcquisitionService.signupSubmitReferral,
    );
    expect(
      GrowthAcquisitionService.resolveSignupSubmitSignal(null),
      GrowthAcquisitionService.signupSubmitLanding,
    );
  });

  test('persists privacy-minimized first-user UTM attribution', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    const visitorId = '00000000-0000-4000-8000-000000000001';
    final now = DateTime.utc(2026, 7, 24, 1);
    const service = GrowthAcquisitionService();
    final uri = Uri.parse(
      'https://my-web-app-b67f4.web.app/'
      '?utm_source=x&utm_medium=organic&utm_campaign=first_user_growth'
      '&utm_content=outcome_first_a',
    );

    expect(
      await service.recordFirstUserFunnelStage(
        stage: 'view',
        visitorId: visitorId,
        currentUri: uri,
        now: now,
      ),
      isFalse,
    );

    final attribution = await service.loadFirstUserAttribution(
      now: now.add(const Duration(hours: 1)),
    );
    expect(attribution?.visitorId, visitorId);
    expect(attribution?.utmSource, 'x');
    expect(attribution?.utmCampaign, 'first_user_growth');
    expect(attribution?.utmContent, 'outcome_first_a');
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(
      GrowthAcquisitionService.firstUserAttributionStorageKey,
    );
    expect(encoded, isNotNull);
    expect(encoded, isNot(contains('@')));
    expect(encoded, isNot(contains('prompt')));
  });

  test('persists Zenn attribution through the post-auth funnel', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    const visitorId = '00000000-0000-4000-8000-000000000002';
    final now = DateTime.utc(2026, 8, 19, 17, 46);
    const service = GrowthAcquisitionService();
    final uri = Uri.parse(
      'https://my-web-app-b67f4.web.app/'
      '?utm_source=zenn&utm_medium=organic&utm_campaign=first_user_growth'
      '&utm_content=oauth_case_study_a',
    );

    expect(
      await service.recordFirstUserFunnelStage(
        stage: 'view',
        visitorId: visitorId,
        currentUri: uri,
        now: now,
      ),
      isFalse,
    );

    final attribution = await service.loadFirstUserAttribution(
      now: now.add(const Duration(hours: 1)),
    );
    expect(attribution?.visitorId, visitorId);
    expect(attribution?.utmSource, 'zenn');
    expect(attribution?.utmMedium, 'organic');
    expect(attribution?.utmCampaign, 'first_user_growth');
    expect(attribution?.utmContent, 'oauth_case_study_a');
  });

  test('persists Product Hunt attribution through the post-auth funnel',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    const visitorId = '00000000-0000-4000-8000-000000000003';
    final now = DateTime.utc(2026, 9, 3, 5);
    const service = GrowthAcquisitionService();
    final uri = Uri.parse(
      'https://my-web-app-b67f4.web.app/'
      '?utm_source=producthunt&utm_medium=launch'
      '&utm_campaign=first_user_growth&utm_content=ph_launch_v1',
    );

    expect(
      await service.recordFirstUserFunnelStage(
        stage: 'view',
        visitorId: visitorId,
        currentUri: uri,
        now: now,
      ),
      isFalse,
    );

    final attribution = await service.loadFirstUserAttribution(
      now: now.add(const Duration(hours: 1)),
    );
    expect(attribution?.utmSource, 'producthunt');
    expect(attribution?.utmMedium, 'launch');
    expect(attribution?.utmContent, 'ph_launch_v1');
  });

  test('persists Reddit attribution through the post-auth funnel', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    const visitorId = '00000000-0000-4000-8000-000000000003';
    final now = DateTime.utc(2026, 9, 3, 8, 10);
    const service = GrowthAcquisitionService();
    final uri = Uri.parse(
      'https://my-web-app-b67f4.web.app/'
      '?utm_source=reddit&utm_medium=community&utm_campaign=first_user_growth'
      '&utm_content=sideproject_launch_a',
    );

    expect(
      await service.recordFirstUserFunnelStage(
        stage: 'view',
        visitorId: visitorId,
        currentUri: uri,
        now: now,
      ),
      isFalse,
    );

    final attribution = await service.loadFirstUserAttribution(
      now: now.add(const Duration(hours: 1)),
    );
    expect(attribution?.visitorId, visitorId);
    expect(attribution?.utmSource, 'reddit');
    expect(attribution?.utmMedium, 'community');
    expect(attribution?.utmCampaign, 'first_user_growth');
    expect(attribution?.utmContent, 'sideproject_launch_a');
  });

  test('does not inherit a prior X campaign on a direct LP view', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    const visitorId = '00000000-0000-4000-8000-000000000001';
    final now = DateTime.utc(2026, 7, 24, 1);
    const service = GrowthAcquisitionService();
    await service.recordFirstUserFunnelStage(
      stage: 'view',
      visitorId: visitorId,
      currentUri: Uri.parse(
        'https://my-web-app-b67f4.web.app/'
        '?utm_source=x&utm_medium=organic&utm_campaign=first_user_growth'
        '&utm_content=outcome_first_a',
      ),
      now: now,
    );

    expect(
      await service.recordFirstUserFunnelStage(
        stage: 'view',
        visitorId: visitorId,
        currentUri: Uri.parse('https://my-web-app-b67f4.web.app/'),
        now: now.add(const Duration(hours: 1)),
      ),
      isFalse,
    );
  });

  test(
    'does not inherit a prior X campaign when an LP URI is unavailable',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      const visitorId = '00000000-0000-4000-8000-000000000001';
      final now = DateTime.utc(2026, 7, 24, 1);
      const service = GrowthAcquisitionService();
      await service.recordFirstUserFunnelStage(
        stage: 'view',
        visitorId: visitorId,
        currentUri: Uri.parse(
          'https://my-web-app-b67f4.web.app/'
          '?utm_source=x&utm_medium=organic&utm_campaign=first_user_growth'
          '&utm_content=outcome_first_a',
        ),
        now: now,
      );

      expect(
        await service.recordFirstUserFunnelStage(
          stage: 'trial',
          visitorId: visitorId,
          now: now.add(const Duration(hours: 1)),
        ),
        isFalse,
      );
    },
  );

  test('expires first-user attribution after seven days', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    const visitorId = '00000000-0000-4000-8000-000000000001';
    final now = DateTime.utc(2026, 7, 24, 1);
    const service = GrowthAcquisitionService();
    await service.recordFirstUserFunnelStage(
      stage: 'view',
      visitorId: visitorId,
      currentUri: Uri.parse(
        'https://my-web-app-b67f4.web.app/'
        '?utm_source=x&utm_campaign=first_user_growth'
        '&utm_content=outcome_first_a',
      ),
      now: now,
    );

    expect(
      await service.loadFirstUserAttribution(
        now: now.add(const Duration(days: 7)),
      ),
      isNull,
    );
  });
}
