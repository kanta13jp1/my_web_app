import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/growth_acquisition_service.dart';

void main() {
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
    expect(
      GrowthAcquisitionService.signalForPagePath('/unknown'),
      isNull,
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

  test('resolves signup submit signal from latest touchpoint', () {
    expect(
      GrowthAcquisitionService.resolveSignupSubmitSignal(
        GrowthAcquisitionService.touchImport,
      ),
      GrowthAcquisitionService.signupSubmitImport,
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

  test('detects X first-user growth campaign URLs', () {
    expect(
      GrowthAcquisitionService.isFirstUserGrowthUri(
        Uri.parse(
          'https://my-web-app-b67f4.web.app/?utm_source=x&utm_medium=ai_share&utm_campaign=first_user_growth',
        ),
      ),
      isTrue,
    );
    expect(
      GrowthAcquisitionService.isFirstUserGrowthUri(
        Uri.parse(
          'https://my-web-app-b67f4.web.app/?utm_source=x&utm_campaign=other',
        ),
      ),
      isFalse,
    );
  });

  test('maps X first-user feedback choices to acquisition signals', () {
    expect(
      GrowthAcquisitionService.xFirstUserFeedbackSignalForChoice('summary'),
      GrowthAcquisitionService.xFirstUserFeedbackSummary,
    );
    expect(
      GrowthAcquisitionService.xFirstUserFeedbackSignalForChoice('memo'),
      GrowthAcquisitionService.xFirstUserFeedbackMemo,
    );
    expect(
      GrowthAcquisitionService.xFirstUserFeedbackSignalForChoice('search'),
      GrowthAcquisitionService.xFirstUserFeedbackSearch,
    );
    expect(
      GrowthAcquisitionService.xFirstUserFeedbackSignalForChoice('unknown'),
      isNull,
    );
  });
}
