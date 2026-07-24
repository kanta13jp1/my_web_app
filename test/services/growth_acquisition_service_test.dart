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
    expect(GrowthAcquisitionService.signalForPagePath('/unknown'), isNull);
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

  test('does not inherit a prior X campaign when an LP URI is unavailable',
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
  });

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
