import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/billing_service.dart';
import 'package:my_web_app/services/growth_acquisition_service.dart';

void main() {
  test('free billing status derives the 30-query quota safely', () {
    const status = BillingStatus(
      tier: 'free',
      status: 'active',
      aiQueryCount: 12,
      efCallCount: 4,
    );

    expect(status.remainingAiQueries, 18);
    expect(status.aiQueryUsageRatio, 0.4);
  });

  test('free billing status clamps exhausted quota values', () {
    const status = BillingStatus(
      tier: 'free',
      status: 'active',
      aiQueryCount: 42,
      efCallCount: 4,
    );

    expect(status.remainingAiQueries, 0);
    expect(status.aiQueryUsageRatio, 1);
  });

  test(
    'checkout attribution tags referral touchpoints for billing metadata',
    () {
      final attribution = BillingCheckoutAttribution.fromLatestTouchpoint(
        GrowthAcquisitionService.touchReferral,
      );

      expect(
        attribution.latestTouchpoint,
        GrowthAcquisitionService.touchReferral,
      );
      expect(
        attribution.signupSignal,
        GrowthAcquisitionService.signupSubmitReferral,
      );
      expect(attribution.referralChannel, 'referral');
      expect(attribution.toJson(), <String, dynamic>{
        'latest_touchpoint': GrowthAcquisitionService.touchReferral,
        'signup_signal': GrowthAcquisitionService.signupSubmitReferral,
        'referral_channel': 'referral',
      });
    },
  );

  test('checkout attribution leaves non-referral channels untagged', () {
    final attribution = BillingCheckoutAttribution.fromLatestTouchpoint(
      GrowthAcquisitionService.touchImport,
    );

    expect(attribution.latestTouchpoint, GrowthAcquisitionService.touchImport);
    expect(
      attribution.signupSignal,
      GrowthAcquisitionService.signupSubmitImport,
    );
    expect(attribution.referralChannel, isNull);
  });
}
