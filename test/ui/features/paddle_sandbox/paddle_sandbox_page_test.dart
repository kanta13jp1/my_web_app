import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/ui/features/paddle_sandbox/paddle_sandbox_gateway.dart';
import 'package:my_web_app/ui/features/paddle_sandbox/paddle_sandbox_models.dart';
import 'package:my_web_app/ui/features/paddle_sandbox/paddle_sandbox_page.dart';
import 'package:my_web_app/ui/features/paddle_sandbox/paddle_sandbox_view_model.dart';

const _validToken = 'test_123456789012345678901234567';

void main() {
  testWidgets(
    'opens checkout and renders all three outcomes on a narrow screen',
    (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final gateway = _FakePaddleSandboxGateway();
      final viewModel = PaddleSandboxViewModel(
        config: const PaddleSandboxConfig(
          enabled: true,
          clientSideToken: _validToken,
          priceId: 'pri_01sandboxprice',
        ),
        gateway: gateway,
        currentUri: Uri.parse('http://localhost:7357/paddle-sandbox'),
      );

      await tester.pumpWidget(
        MaterialApp(home: PaddleSandboxPage(viewModel: viewModel)),
      );

      expect(find.text('検証専用・実課金なし'), findsOneWidget);
      expect(find.text('Sandbox checkout を開始できます'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('paddle_sandbox_checkout_button')));
      await tester.pumpAndSettle();
      expect(gateway.openCalls, 1);
      expect(find.text('Sandbox checkout を開きました'), findsOneWidget);

      gateway.emit(const PaddleSandboxEvent(name: 'checkout.payment.failed'));
      await tester.pump();
      expect(find.text('Sandbox 決済が拒否されました'), findsOneWidget);

      gateway.emit(const PaddleSandboxEvent(name: 'checkout.closed'));
      await tester.pump();
      expect(find.text('チェックアウトを閉じました'), findsOneWidget);

      gateway.emit(
        const PaddleSandboxEvent(
          name: 'checkout.completed',
          transactionId: 'txn_widget_success',
        ),
      );
      await tester.pump();
      expect(find.text('Sandbox 決済が完了しました'), findsOneWidget);
      expect(find.text('transaction: txn_widget_success'), findsOneWidget);
      expect(
        find.bySemanticsLabel('transaction: txn_widget_success'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      semanticsHandle.dispose();
    },
  );

  testWidgets('keeps launch disabled when sandbox flag is off', (tester) async {
    final viewModel = PaddleSandboxViewModel(
      config: const PaddleSandboxConfig(
        enabled: false,
        clientSideToken: '',
        priceId: '',
      ),
      gateway: _FakePaddleSandboxGateway(),
      currentUri: Uri.parse('https://example.com/paddle-sandbox'),
    );

    await tester.pumpWidget(
      MaterialApp(home: PaddleSandboxPage(viewModel: viewModel)),
    );

    final button = tester.widget<FilledButton>(
      find.byKey(const Key('paddle_sandbox_checkout_button')),
    );
    expect(button.onPressed, isNull);
    expect(find.text('Paddle sandbox は無効です'), findsOneWidget);
  });
}

class _FakePaddleSandboxGateway implements PaddleSandboxGateway {
  void Function(PaddleSandboxEvent event)? _onEvent;
  int openCalls = 0;

  @override
  bool get isSupported => true;

  @override
  Future<void> initialize({
    required String clientSideToken,
    required void Function(PaddleSandboxEvent event) onEvent,
  }) async {
    _onEvent = onEvent;
  }

  @override
  Future<void> openCheckout({
    required String priceId,
    required String successUrl,
  }) async {
    openCalls += 1;
  }

  void emit(PaddleSandboxEvent event) {
    _onEvent?.call(event);
  }
}
