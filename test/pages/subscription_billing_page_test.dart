import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/subscription_billing_page.dart';
import 'package:my_web_app/services/activation_revenue_experiment_service.dart';
import 'package:my_web_app/services/activation_revenue_tracker.dart';
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
          tracker: const NoopActivationRevenueEventTracker(),
          assignment: _treatment,
          initialUri: Uri.parse(
            'https://example.com/subscription-billing?billing=success',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('プランの決済を受け付けました'), findsOneWidget);
    expect(find.textContaining('最新のプラン状態'), findsOneWidget);
    expect(billing.fetchStatusCount, 1);
  });

  testWidgets('shows neutral cancel confirmation', (tester) async {
    final billing = _FakeBillingGateway();

    await tester.pumpWidget(
      MaterialApp(
        home: SubscriptionBillingPage(
          service: billing,
          tracker: const NoopActivationRevenueEventTracker(),
          assignment: _treatment,
          initialUri: Uri.parse(
            'https://example.com/subscription-billing?billing=cancel',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('プランの決済をキャンセルしました'), findsOneWidget);
    expect(find.textContaining('請求は発生していません'), findsOneWidget);
    expect(billing.fetchStatusCount, 1);
  });

  testWidgets('shows supporter success confirmation', (tester) async {
    final billing = _FakeBillingGateway();

    await tester.pumpWidget(
      MaterialApp(
        home: SubscriptionBillingPage(
          service: billing,
          tracker: const NoopActivationRevenueEventTracker(),
          assignment: _treatment,
          initialUri: Uri.parse(
            'https://example.com/subscription-billing?billing=supporter_success',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('100円の応援を受け付けました'), findsOneWidget);
    expect(find.textContaining('ありがとうございます'), findsOneWidget);
    expect(billing.fetchStatusCount, 1);
  });

  testWidgets('shows value framing after onboarding on a narrow viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: SubscriptionBillingPage(
          service: _FakeBillingGateway(),
          tracker: const NoopActivationRevenueEventTracker(),
          assignment: _treatment,
          initialUri: Uri.parse(
            'https://example.com/subscription-billing?entry=onboarding',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('billing_onboarding_value_banner')),
      findsOneWidget,
    );
    expect(find.text('役に立ったら、続け方を選べます'), findsOneWidget);
    expect(find.textContaining('自動更新なし'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

final _treatment = ActivationRevenueAssignment(
  hypothesis: ActivationRevenueExperimentService.hypotheses[9],
  variant: ActivationRevenueVariant.treatment,
);

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
