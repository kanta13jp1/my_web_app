import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/billing_service.dart';

void main() {
  group('BillingStatus', () {
    test('parses paid status and usage counters', () {
      final status = BillingStatus.fromJson({
        'billing': {
          'tier': 'pro',
          'status': 'active',
          'current_period_end': '2026-07-01T00:00:00Z',
          'cancel_at_period_end': true,
        },
        'usage': {
          'ai_query_count': '12',
          'ef_call_count': 7.2,
        },
      });

      expect(status.tier, 'pro');
      expect(status.status, 'active');
      expect(status.isPro, isTrue);
      expect(status.aiQueryCount, 12);
      expect(status.efCallCount, 7);
      expect(status.currentPeriodEnd, DateTime.parse('2026-07-01T00:00:00Z'));
      expect(status.cancelAtPeriodEnd, isTrue);
    });

    test('defaults missing billing and usage to free status', () {
      final status = BillingStatus.fromJson({});

      expect(status.tier, 'free');
      expect(status.status, 'active');
      expect(status.isPro, isFalse);
      expect(status.aiQueryCount, 0);
      expect(status.efCallCount, 0);
      expect(status.currentPeriodEnd, isNull);
      expect(status.cancelAtPeriodEnd, isFalse);
    });

    test('treats team tier as paid entitlement', () {
      final status = BillingStatus.fromJson({
        'billing': {'tier': 'team'},
      });

      expect(status.isPro, isTrue);
    });
  });

  group('BillingCheckoutSession', () {
    test('parses checkout URL and id', () {
      final session = BillingCheckoutSession.fromJson({
        'checkout_url': 'https://checkout.stripe.com/c/pay/cs_live_123',
        'id': 'cs_live_123',
      });

      expect(session.url, 'https://checkout.stripe.com/c/pay/cs_live_123');
      expect(session.id, 'cs_live_123');
    });

    test('throws when checkout URL is missing', () {
      expect(
        () => BillingCheckoutSession.fromJson({}),
        throwsA(isA<BillingServiceException>()),
      );
    });
  });

  group('BillingPortalSession', () {
    test('throws when portal URL is missing', () {
      expect(
        () => BillingPortalSession.fromJson({}),
        throwsA(isA<BillingServiceException>()),
      );
    });
  });
}
