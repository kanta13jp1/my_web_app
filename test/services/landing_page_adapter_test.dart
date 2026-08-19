import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/landing_oauth_callback_failure.dart';
import 'package:my_web_app/services/landing_page_adapter.dart';
import 'package:my_web_app/services/landing_share_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('classifies Magic Link failures without retaining provider text', () {
    final cases = <Object, LandingMagicLinkFailureCategory>{
      const AuthException('Invalid email', code: 'email_address_invalid'):
          LandingMagicLinkFailureCategory.invalidEmail,
      const AuthException('Too many requests', statusCode: '429'):
          LandingMagicLinkFailureCategory.rateLimit,
      const AuthException(
        'Email address not authorized',
        code: 'email_provider_disabled',
      ): LandingMagicLinkFailureCategory.deliveryConfiguration,
      const AuthException('Redirect URL rejected', code: 'validation_failed'):
          LandingMagicLinkFailureCategory.redirectConfiguration,
      Exception('Socket connection timed out'):
          LandingMagicLinkFailureCategory.network,
      Exception('Unexpected response'): LandingMagicLinkFailureCategory.unknown,
    };

    for (final entry in cases.entries) {
      expect(classifyLandingMagicLinkFailure(entry.key), entry.value);
    }
  });

  test('maps every failure category to an allowlisted aggregate key', () {
    expect(
      LandingMagicLinkFailureCategory.values.map(
        landingMagicLinkFailureEventKey,
      ),
      <String>[
        LandingShareService.funnelMagicLinkFailInvalidEmail,
        LandingShareService.funnelMagicLinkFailRateLimit,
        LandingShareService.funnelMagicLinkFailDeliveryConfig,
        LandingShareService.funnelMagicLinkFailRedirect,
        LandingShareService.funnelMagicLinkFailNetwork,
        LandingShareService.funnelMagicLinkFailUnknown,
      ],
    );
  });

  test('maps every Google callback category to an allowlisted aggregate key',
      () {
    expect(
      LandingOAuthCallbackFailureCategory.values.map(
        landingGoogleOAuthFailureEventKey,
      ),
      <String>[
        LandingShareService.funnelGoogleOAuthFailCancelled,
        LandingShareService.funnelGoogleOAuthFailRateLimit,
        LandingShareService.funnelGoogleOAuthFailProviderConfig,
        LandingShareService.funnelGoogleOAuthFailRedirect,
        LandingShareService.funnelGoogleOAuthFailCallbackExchange,
        LandingShareService.funnelGoogleOAuthFailUnknown,
      ],
    );
  });
}
