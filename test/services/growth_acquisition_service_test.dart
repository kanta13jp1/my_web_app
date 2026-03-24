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
}
