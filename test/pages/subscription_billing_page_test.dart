import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/subscription_billing_page.dart';
import 'package:my_web_app/services/activation_revenue_experiment_service.dart';
import 'package:my_web_app/services/activation_revenue_tracker.dart';
import 'package:my_web_app/services/billing_service.dart';
import 'package:my_web_app/services/growth_acquisition_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows the free AI quota, remaining count, and progress', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SubscriptionBillingPage(
          service: _FakeBillingGateway(
            status: const BillingStatus(
              tier: 'free',
              status: 'active',
              aiQueryCount: 12,
              efCallCount: 4,
            ),
          ),
          tracker: const NoopActivationRevenueEventTracker(),
          assignment: _treatment,
          initialUri: Uri.parse('https://example.com/subscription-billing'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AI質問 今月 12/30'), findsOneWidget);
    expect(find.text('残り 18回'), findsOneWidget);
    expect(find.byKey(const Key('billing_ai_usage_progress')), findsOneWidget);
  });

  testWidgets('shows unlimited usage for Pro without a quota progress bar', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SubscriptionBillingPage(
          service: _FakeBillingGateway(
            status: const BillingStatus(
              tier: 'pro',
              status: 'active',
              aiQueryCount: 55,
              efCallCount: 8,
            ),
          ),
          tracker: const NoopActivationRevenueEventTracker(),
          assignment: _treatment,
          initialUri: Uri.parse('https://example.com/subscription-billing'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AI質問: 無制限'), findsOneWidget);
    expect(find.byKey(const Key('billing_ai_usage_progress')), findsNothing);
    expect(find.textContaining('/30'), findsNothing);
  });

  testWidgets('shows success confirmation and refreshes billing status', (
    tester,
  ) async {
    final billing = _FakeBillingGateway();
    final acquisition = _RecordingAcquisitionService();

    await tester.pumpWidget(
      MaterialApp(
        home: SubscriptionBillingPage(
          service: billing,
          acquisitionService: acquisition,
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
    expect(acquisition.billingStages, [
      GrowthAcquisitionService.funnelBillingView,
      GrowthAcquisitionService.funnelCheckoutSuccess,
    ]);
  });

  testWidgets('shows neutral cancel confirmation', (tester) async {
    final billing = _FakeBillingGateway();
    final acquisition = _RecordingAcquisitionService();

    await tester.pumpWidget(
      MaterialApp(
        home: SubscriptionBillingPage(
          service: billing,
          acquisitionService: acquisition,
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
    expect(acquisition.billingStages, [
      GrowthAcquisitionService.funnelBillingView,
      GrowthAcquisitionService.funnelCheckoutCancel,
    ]);
  });

  testWidgets('records upgrade click before opening Stripe checkout', (
    tester,
  ) async {
    final acquisition = _RecordingAcquisitionService();

    await tester.pumpWidget(
      MaterialApp(
        home: SubscriptionBillingPage(
          service: _FakeBillingGateway(),
          acquisitionService: acquisition,
          tracker: const NoopActivationRevenueEventTracker(),
          assignment: _treatment,
          initialUri: Uri.parse('https://example.com/subscription-billing'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final checkoutButton = find.byKey(const Key('billing_pro_checkout_button'));
    await tester.ensureVisible(checkoutButton);
    await tester.tap(checkoutButton);
    await tester.pumpAndSettle();

    expect(acquisition.billingStages, [
      GrowthAcquisitionService.funnelBillingView,
      GrowthAcquisitionService.funnelUpgradeClick,
    ]);
  });

  testWidgets('shows supporter success confirmation', (tester) async {
    final billing = _FakeBillingGateway();
    final acquisition = _RecordingAcquisitionService();

    await tester.pumpWidget(
      MaterialApp(
        home: SubscriptionBillingPage(
          service: billing,
          acquisitionService: acquisition,
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
    expect(acquisition.billingStages, [
      GrowthAcquisitionService.funnelBillingView,
    ]);
  });

  testWidgets('does not expose billing status exception details', (
    tester,
  ) async {
    const secret = 'internal-token=do-not-render';

    await tester.pumpWidget(
      MaterialApp(
        home: SubscriptionBillingPage(
          service: _FakeBillingGateway(
            fetchStatusError: BillingServiceException(
              secret,
              statusCode: 503,
            ),
          ),
          tracker: const NoopActivationRevenueEventTracker(),
          assignment: _treatment,
          initialUri: Uri.parse('https://example.com/subscription-billing'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('プラン情報を読み込めませんでした。時間をおいて再度お試しください。'),
      findsOneWidget,
    );
    expect(find.textContaining(secret), findsNothing);
  });

  testWidgets('does not expose checkout exception details', (tester) async {
    const secret = 'stripe-secret=do-not-render';

    await tester.pumpWidget(
      MaterialApp(
        home: SubscriptionBillingPage(
          service: _FakeBillingGateway(
            checkoutError: BillingServiceException(
              secret,
              statusCode: 500,
            ),
          ),
          acquisitionService: _RecordingAcquisitionService(),
          tracker: const NoopActivationRevenueEventTracker(),
          assignment: _treatment,
          initialUri: Uri.parse('https://example.com/subscription-billing'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final checkoutButton = find.byKey(const Key('billing_pro_checkout_button'));
    await tester.ensureVisible(checkoutButton);
    await tester.tap(checkoutButton);
    await tester.pumpAndSettle();

    expect(
      find.text('決済画面を準備できませんでした。時間をおいて再度お試しください。'),
      findsOneWidget,
    );
    expect(find.textContaining(secret), findsNothing);
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

  testWidgets('carries the original X variant into the supporter checkout', (
    tester,
  ) async {
    final billing = _FakeBillingGateway();
    final acquisition = _RecordingAcquisitionService();

    await tester.pumpWidget(
      MaterialApp(
        home: SubscriptionBillingPage(
          service: billing,
          acquisitionService: acquisition,
          tracker: const NoopActivationRevenueEventTracker(),
          assignment: _treatment,
          initialUri: Uri.parse(
            'https://example.com/subscription-billing?entry=onboarding',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(acquisition.stages, contains('billing_view'));
    final checkoutButton = find.byKey(
      const Key('billing_supporter_checkout_button'),
    );
    await tester.ensureVisible(checkoutButton);
    await tester.tap(checkoutButton);
    await tester.pumpAndSettle();

    expect(acquisition.stages, contains('supporter_checkout'));
    expect(
      billing.supporterAttribution?.toJson(),
      containsPair('utm_content', 'outcome_first_a'),
    );
  });
}

final _treatment = ActivationRevenueAssignment(
  hypothesis: ActivationRevenueExperimentService.hypotheses[9],
  variant: ActivationRevenueVariant.treatment,
);

class _FakeBillingGateway implements BillingGateway {
  _FakeBillingGateway({
    this.status = const BillingStatus(
      tier: 'free',
      status: 'active',
      aiQueryCount: 0,
      efCallCount: 0,
    ),
    this.fetchStatusError,
    this.checkoutError,
  });

  final BillingStatus status;
  final Exception? fetchStatusError;
  final Exception? checkoutError;
  int fetchStatusCount = 0;
  BillingSupporterAttribution? supporterAttribution;

  @override
  Future<BillingStatus> fetchStatus() async {
    fetchStatusCount += 1;
    final error = fetchStatusError;
    if (error != null) throw error;
    return status;
  }

  @override
  Future<BillingCheckoutSession> createCheckoutSession({
    required String tier,
    required String returnUrl,
    BillingCheckoutAttribution attribution = const BillingCheckoutAttribution(),
  }) async {
    final error = checkoutError;
    if (error != null) throw error;
    return const BillingCheckoutSession(url: 'https://stripe.example.test');
  }

  @override
  Future<BillingCheckoutSession> createSupporterCheckoutSession({
    required String returnUrl,
    BillingSupporterAttribution attribution =
        const BillingSupporterAttribution(),
  }) async {
    supporterAttribution = attribution;
    return const BillingCheckoutSession(url: 'https://stripe.example.test');
  }

  @override
  Future<BillingPortalSession> createPortalSession({
    required String returnUrl,
  }) async {
    return const BillingPortalSession(url: 'https://stripe.example.test');
  }
}

class _RecordingAcquisitionService extends GrowthAcquisitionService {
  _RecordingAcquisitionService();

  final List<String> stages = <String>[];
  final List<String> billingStages = <String>[];

  @override
  Future<void> recordBillingFunnelStage({required String stage}) async {
    billingStages.add(stage);
  }

  @override
  Future<bool> recordFirstUserFunnelStage({
    required String stage,
    String? visitorId,
    Uri? currentUri,
    SharedPreferences? preferences,
    DateTime? now,
  }) async {
    stages.add(stage);
    return true;
  }

  @override
  Future<String?> loadLatestTouchpoint() async {
    return GrowthAcquisitionService.touchXFirstUserGrowth;
  }

  @override
  Future<FirstUserGrowthAttribution?> loadFirstUserAttribution({
    SharedPreferences? preferences,
    DateTime? now,
  }) async {
    return FirstUserGrowthAttribution(
      visitorId: '00000000-0000-4000-8000-000000000001',
      utmSource: 'x',
      utmMedium: 'organic',
      utmCampaign: 'first_user_growth',
      utmContent: 'outcome_first_a',
      capturedAt: DateTime.utc(2026, 7, 24),
    );
  }
}
