import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/billing_service.dart';
import 'package:my_web_app/widgets/home_billing_nudge.dart';

void main() {
  testWidgets('free usage shows N/30, remaining count, and upgrade action', (
    tester,
  ) async {
    var openedBilling = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeBillingNudge(
            status: const BillingStatus(
              tier: 'free',
              status: 'active',
              aiQueryCount: 12,
              efCallCount: 4,
            ),
            isLoading: false,
            onOpenBilling: () => openedBilling = true,
          ),
        ),
      ),
    );

    expect(find.text('今月 12/30'), findsOneWidget);
    expect(find.text('残り 18回'), findsOneWidget);
    expect(find.text('アップグレード'), findsOneWidget);
    expect(find.byKey(const Key('home_ai_usage_progress')), findsOneWidget);

    await tester.tap(find.byKey(const Key('home_billing_upgrade_chip')));
    await tester.pump();
    expect(openedBilling, isTrue);
  });

  testWidgets('Pro usage is unlimited and responsive on a narrow viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeBillingNudge(
            status: const BillingStatus(
              tier: 'pro',
              status: 'active',
              aiQueryCount: 55,
              efCallCount: 8,
            ),
            isLoading: false,
            onOpenBilling: () {},
          ),
        ),
      ),
    );

    expect(find.text('今月 無制限'), findsOneWidget);
    expect(find.text('プラン管理'), findsOneWidget);
    expect(find.byKey(const Key('home_ai_usage_progress')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('upgrade chip remains visible when usage cannot load', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeBillingNudge(
            status: null,
            isLoading: false,
            onOpenBilling: () {},
          ),
        ),
      ),
    );

    expect(find.text('使用量を取得できませんでした'), findsOneWidget);
    expect(find.text('アップグレード'), findsOneWidget);
  });
}
