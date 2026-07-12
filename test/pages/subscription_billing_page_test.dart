import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/subscription_billing_page.dart';
import 'package:my_web_app/services/billing_service.dart';

void main() {
  testWidgets('shows success confirmation and refreshes billing status', (
    tester,
  ) async {
    final billing = _FakeBillingGateway();

    await tester.pumpWidget(
      MaterialApp(
        home: SubscriptionBillingPage(
          service: billing,
          initialUri: Uri.parse(
            'https://example.com/subscription-billing?billing=success',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Checkout completed'), findsOneWidget);
    expect(find.textContaining('latest billing status'), findsOneWidget);
    expect(billing.fetchStatusCount, 1);
  });

  testWidgets('shows neutral cancel confirmation', (tester) async {
    final billing = _FakeBillingGateway();

    await tester.pumpWidget(
      MaterialApp(
        home: SubscriptionBillingPage(
          service: billing,
          initialUri: Uri.parse(
            'https://example.com/subscription-billing?billing=cancel',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Checkout canceled'), findsOneWidget);
    expect(find.textContaining('No subscription payment'), findsOneWidget);
    expect(billing.fetchStatusCount, 1);
  });

  testWidgets('shows supporter success confirmation', (tester) async {
    final billing = _FakeBillingGateway();

    await tester.pumpWidget(
      MaterialApp(
        home: SubscriptionBillingPage(
          service: billing,
          initialUri: Uri.parse(
            'https://example.com/subscription-billing?billing=supporter_success',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Support received'), findsOneWidget);
    expect(find.textContaining('first revenue evidence'), findsOneWidget);
    expect(billing.fetchStatusCount, 1);
  });
}

class _FakeBillingGateway implements BillingGateway {
  int fetchStatusCount = 0;

  @override
  Future<BillingStatus> fetchStatus() async {
    fetchStatusCount += 1;
    return const BillingStatus(
      tier: 'free',
      status: 'active',
      aiQueryCount: 0,
      efCallCount: 0,
    );
  }

  @override
  Future<BillingCheckoutSession> createCheckoutSession({
    required String tier,
    required String returnUrl,
    BillingCheckoutAttribution attribution = const BillingCheckoutAttribution(),
  }) async {
    return const BillingCheckoutSession(url: 'https://stripe.example.test');
  }

  @override
  Future<BillingCheckoutSession> createSupporterCheckoutSession({
    required String returnUrl,
    BillingSupporterAttribution attribution =
        const BillingSupporterAttribution(),
  }) async {
    return const BillingCheckoutSession(url: 'https://stripe.example.test');
  }

  @override
  Future<BillingPortalSession> createPortalSession({
    required String returnUrl,
  }) async {
    return const BillingPortalSession(url: 'https://stripe.example.test');
  }
}
