import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/paddle_checkout.dart';
import 'package:my_web_app/ui/features/billing/view_models/paddle_sandbox_checkout_controller.dart';

void main() {
  group('PaddleSandboxConfig', () {
    test('accepts only enabled non-release sandbox credentials', () {
      const config = PaddleSandboxConfig(
        enabled: true,
        clientSideToken: 'test_client_token',
        priceId: 'pri_sandbox_price',
        releaseMode: false,
      );

      expect(config.shouldExpose, isTrue);
      expect(config.canOpen, isTrue);
      expect(config.validationMessage, isNull);
    });

    test('never exposes the sandbox checkout in release mode', () {
      const config = PaddleSandboxConfig(
        enabled: true,
        clientSideToken: 'test_client_token',
        priceId: 'pri_sandbox_price',
        releaseMode: true,
      );

      expect(config.shouldExpose, isFalse);
      expect(config.canOpen, isFalse);
      expect(config.validationMessage, contains('本番ビルド'));
    });

    test('rejects a live token', () {
      const config = PaddleSandboxConfig(
        enabled: true,
        clientSideToken: 'live_client_token',
        priceId: 'pri_sandbox_price',
        releaseMode: false,
      );

      expect(config.canOpen, isFalse);
      expect(config.validationMessage, contains('client-side token'));
    });
  });

  group('PaddleSandboxCheckoutController', () {
    test(
      'maps loaded and completed events to a successful terminal state',
      () async {
        final gateway = _FakePaddleCheckoutGateway();
        final controller = PaddleSandboxCheckoutController(
          config: _validConfig,
          gateway: gateway,
        );
        addTearDown(controller.dispose);

        await controller.openCheckout();
        expect(controller.state.phase, PaddleCheckoutPhase.opening);

        gateway.emit(
          const PaddleCheckoutEvent(
            name: 'checkout.loaded',
            checkoutId: 'che_test',
          ),
        );
        expect(controller.state.phase, PaddleCheckoutPhase.opened);

        gateway.emit(
          const PaddleCheckoutEvent(
            name: 'checkout.completed',
            checkoutId: 'che_test',
            transactionId: 'txn_test',
          ),
        );
        expect(controller.state.phase, PaddleCheckoutPhase.completed);
        expect(controller.state.transactionId, 'txn_test');

        gateway.emit(const PaddleCheckoutEvent(name: 'checkout.closed'));
        expect(controller.state.phase, PaddleCheckoutPhase.completed);
      },
    );

    test('maps payment failures to a retryable failure state', () async {
      final gateway = _FakePaddleCheckoutGateway();
      final controller = PaddleSandboxCheckoutController(
        config: _validConfig,
        gateway: gateway,
      );
      addTearDown(controller.dispose);

      await controller.openCheckout();
      gateway.emit(const PaddleCheckoutEvent(name: 'checkout.payment.failed'));

      expect(controller.state.phase, PaddleCheckoutPhase.failed);
      expect(controller.state.message, contains('再試行'));

      gateway.emit(const PaddleCheckoutEvent(name: 'checkout.closed'));
      expect(controller.state.phase, PaddleCheckoutPhase.failed);
    });

    test('maps close-before-completion to a canceled state', () async {
      final gateway = _FakePaddleCheckoutGateway();
      final controller = PaddleSandboxCheckoutController(
        config: _validConfig,
        gateway: gateway,
      );
      addTearDown(controller.dispose);

      await controller.openCheckout();
      gateway.emit(const PaddleCheckoutEvent(name: 'checkout.closed'));

      expect(controller.state.phase, PaddleCheckoutPhase.canceled);
      expect(controller.state.message, contains('請求は発生していません'));
    });

    test('uses a public error when the bridge cannot open', () async {
      final controller = PaddleSandboxCheckoutController(
        config: _validConfig,
        gateway: _FakePaddleCheckoutGateway(
          openError: const PaddleCheckoutException(
            'test_secret_should_not_be_rendered',
          ),
        ),
      );
      addTearDown(controller.dispose);

      await controller.openCheckout();

      expect(controller.state.phase, PaddleCheckoutPhase.failed);
      expect(controller.state.message, isNot(contains('test_secret')));
    });
  });
}

const _validConfig = PaddleSandboxConfig(
  enabled: true,
  clientSideToken: 'test_client_token',
  priceId: 'pri_sandbox_price',
  releaseMode: false,
);

class _FakePaddleCheckoutGateway implements PaddleCheckoutGateway {
  _FakePaddleCheckoutGateway({this.openError});

  final Exception? openError;
  void Function(PaddleCheckoutEvent event)? _onEvent;

  @override
  Future<void> openCheckout({
    required PaddleSandboxConfig config,
    required void Function(PaddleCheckoutEvent event) onEvent,
  }) async {
    final error = openError;
    if (error != null) throw error;
    _onEvent = onEvent;
  }

  void emit(PaddleCheckoutEvent event) => _onEvent?.call(event);

  @override
  void dispose() {
    _onEvent = null;
  }
}
