import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/paddle_checkout.dart';
import 'package:my_web_app/ui/features/billing/views/paddle_sandbox_checkout_card.dart';

void main() {
  testWidgets('shows completion and a safe continuation action', (
    tester,
  ) async {
    final gateway = _FakePaddleCheckoutGateway();
    var continued = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PaddleSandboxCheckoutCard(
            config: _validConfig,
            gateway: gateway,
            onContinue: () => continued = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('paddle_sandbox_checkout_button')));
    await tester.pump();
    gateway.emit(const PaddleCheckoutEvent(name: 'checkout.loaded'));
    await tester.pump();
    expect(find.text('Paddle sandbox checkout を表示しています。'), findsOneWidget);

    gateway.emit(const PaddleCheckoutEvent(name: 'checkout.completed'));
    await tester.pump();
    expect(find.textContaining('Sandbox 決済が完了'), findsOneWidget);

    await tester.tap(find.byKey(const Key('paddle_sandbox_continue_button')));
    expect(continued, isTrue);
  });

  testWidgets('shows a retry action after payment failure', (tester) async {
    final gateway = _FakePaddleCheckoutGateway();
    await tester.pumpWidget(_testApp(gateway));

    await tester.tap(find.byKey(const Key('paddle_sandbox_checkout_button')));
    await tester.pump();
    gateway.emit(const PaddleCheckoutEvent(name: 'checkout.payment.failed'));
    await tester.pump();

    expect(find.textContaining('Sandbox 決済に失敗'), findsOneWidget);
    expect(
      find.byKey(const Key('paddle_sandbox_checkout_button')),
      findsOneWidget,
    );
    expect(find.text('もう一度試す'), findsOneWidget);
    final retryButton = tester.widget<FilledButton>(
      find.byKey(const Key('paddle_sandbox_checkout_button')),
    );
    expect(retryButton.onPressed, isNotNull);
  });

  testWidgets('shows a neutral cancellation on a narrow viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = _FakePaddleCheckoutGateway();
    await tester.pumpWidget(_testApp(gateway));

    await tester.tap(find.byKey(const Key('paddle_sandbox_checkout_button')));
    await tester.pump();
    gateway.emit(const PaddleCheckoutEvent(name: 'checkout.closed'));
    await tester.pump();

    expect(find.textContaining('Sandbox checkout を中断'), findsOneWidget);
    expect(find.textContaining('請求は発生していません'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disables checkout when sandbox configuration is incomplete', (
    tester,
  ) async {
    const config = PaddleSandboxConfig(
      enabled: true,
      clientSideToken: '',
      priceId: 'pri_sandbox_price',
      releaseMode: false,
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PaddleSandboxCheckoutCard(config: config)),
      ),
    );

    expect(find.textContaining('client-side token'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('paddle_sandbox_checkout_button')),
    );
    expect(button.onPressed, isNull);
  });
}

Widget _testApp(PaddleCheckoutGateway gateway) {
  return MaterialApp(
    home: Scaffold(
      body: PaddleSandboxCheckoutCard(config: _validConfig, gateway: gateway),
    ),
  );
}

const _validConfig = PaddleSandboxConfig(
  enabled: true,
  clientSideToken: 'test_client_token',
  priceId: 'pri_sandbox_price',
  releaseMode: false,
);

class _FakePaddleCheckoutGateway implements PaddleCheckoutGateway {
  void Function(PaddleCheckoutEvent event)? _onEvent;

  @override
  Future<void> openCheckout({
    required PaddleSandboxConfig config,
    required void Function(PaddleCheckoutEvent event) onEvent,
  }) async {
    _onEvent = onEvent;
  }

  void emit(PaddleCheckoutEvent event) => _onEvent?.call(event);

  @override
  void dispose() {
    _onEvent = null;
  }
}
