import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/landing_oauth_callback_failure.dart';

void main() {
  test('returns null for a normal landing URL', () {
    expect(
      LandingOAuthCallbackFailure.fromUri(
        Uri.parse('https://example.com/?utm_source=x'),
      ),
      isNull,
    );
  });

  test('classifies a cancelled Google callback without retaining details', () {
    final failure = LandingOAuthCallbackFailure.fromUri(
      Uri.parse(
        'https://example.com/#error=access_denied'
        '&error_code=user_cancelled_authorization'
        '&error_description=private%40example.com+cancelled',
      ),
    );

    expect(
      failure?.category,
      LandingOAuthCallbackFailureCategory.cancelled,
    );
    expect(failure?.userMessage, isNot(contains('private@example.com')));
  });

  test('classifies callback configuration and exchange failures', () {
    expect(
      LandingOAuthCallbackFailure.fromUri(
        Uri.parse(
          'https://example.com/?error=server_error'
          '&error_description=redirect+URI+mismatch',
        ),
      )?.category,
      LandingOAuthCallbackFailureCategory.redirectConfiguration,
    );
    expect(
      LandingOAuthCallbackFailure.fromUri(
        Uri.parse(
          'https://example.com/#error=server_error'
          '&error_code=flow_state_not_found',
        ),
      )?.category,
      LandingOAuthCallbackFailureCategory.callbackExchange,
    );
    expect(
      LandingOAuthCallbackFailure.fromUri(
        Uri.parse(
          'https://example.com/#error=server_error'
          '&error_description=Unable+to+exchange+external+code',
        ),
      )?.category,
      LandingOAuthCallbackFailureCategory.callbackExchange,
    );
  });

  test('accepts the browser-sanitized callback category', () {
    final failure = LandingOAuthCallbackFailure.fromUri(
      Uri.parse(
        'https://example.com/?oauth_callback_failure=callback_exchange',
      ),
    );

    expect(
      failure?.category,
      LandingOAuthCallbackFailureCategory.callbackExchange,
    );
    expect(failure?.userMessage, isNot(contains('oauth')));
  });

  test('classifies rate limits and provider configuration failures', () {
    expect(
      LandingOAuthCallbackFailure.fromUri(
        Uri.parse(
          'https://example.com/#error=temporarily_unavailable'
          '&error_code=over_request_rate_limit',
        ),
      )?.category,
      LandingOAuthCallbackFailureCategory.rateLimited,
    );
    expect(
      LandingOAuthCallbackFailure.fromUri(
        Uri.parse(
          'https://example.com/#error=server_error'
          '&error_code=provider_disabled',
        ),
      )?.category,
      LandingOAuthCallbackFailureCategory.providerConfiguration,
    );
  });
}
