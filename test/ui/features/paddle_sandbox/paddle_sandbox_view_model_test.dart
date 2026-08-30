import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/ui/features/paddle_sandbox/paddle_sandbox_gateway.dart';
import 'package:my_web_app/ui/features/paddle_sandbox/paddle_sandbox_models.dart';
import 'package:my_web_app/ui/features/paddle_sandbox/paddle_sandbox_view_model.dart';

const _validToken = 'test_123456789012345678901234567';
const _validPriceId = 'pri_01sandboxprice';

void main() {
  group('PaddleSandboxConfig', () {
    test('accepts sandbox-only identifiers', () {
      const config = PaddleSandboxConfig(
        enabled: true,
        clientSideToken: _validToken,
        priceId: _validPriceId,
      );

      expect(config.validationError, isNull);
      expect(
        config.successUrl(Uri.parse('https://example.com/old?x=1#fragment')),
        'https://example.com/paddle-sandbox?paddle=completed',
      );
    });

    test('rejects disabled, live-token, and invalid-price configurations', () {
      const disabled = PaddleSandboxConfig(
        enabled: false,
        clientSideToken: _validToken,
        priceId: _validPriceId,
      );
      const live = PaddleSandboxConfig(
        enabled: true,
        clientSideToken: 'live_123456789012345678901234567',
        priceId: _validPriceId,
      );
      const invalidPrice = PaddleSandboxConfig(
        enabled: true,
        clientSideToken: _validToken,
        priceId: 'pro_123',
      );

      expect(disabled.validationError, contains('無効'));
      expect(live.validationError, contains('test_'));
      expect(invalidPrice.validationError, contains('pri_'));
    });
  });

  group('PaddleSandboxViewModel', () {
    test(
      'opens checkout and handles success without overriding it on close',
      () async {
        final gateway = _FakePaddleSandboxGateway();
        final viewModel = _viewModel(gateway);

        expect(viewModel.snapshot.phase, PaddleSandboxPhase.ready);

        await viewModel.startCheckout();

        expect(gateway.initializeCalls, 1);
        expect(gateway.openCalls, 1);
        expect(viewModel.snapshot.phase, PaddleSandboxPhase.checkoutOpen);

        gateway.emit(
          const PaddleSandboxEvent(
            name: 'checkout.completed',
            transactionId: 'txn_sandbox_success',
          ),
        );
        expect(viewModel.snapshot.phase, PaddleSandboxPhase.completed);
        expect(viewModel.snapshot.transactionId, 'txn_sandbox_success');

        gateway.emit(const PaddleSandboxEvent(name: 'checkout.closed'));
        expect(viewModel.snapshot.phase, PaddleSandboxPhase.completed);
      },
    );

    test('maps failed, cancelled, and error events to retryable states', () {
      final gateway = _FakePaddleSandboxGateway();
      final viewModel = _viewModel(gateway);

      viewModel.handleEvent(
        const PaddleSandboxEvent(name: 'checkout.payment.failed'),
      );
      expect(viewModel.snapshot.phase, PaddleSandboxPhase.paymentFailed);
      expect(viewModel.snapshot.canStart, isTrue);

      viewModel.handleEvent(
        const PaddleSandboxEvent(name: 'checkout.closed'),
      );
      expect(viewModel.snapshot.phase, PaddleSandboxPhase.cancelled);
      expect(viewModel.snapshot.message, contains('完了していません'));

      viewModel.handleEvent(
        const PaddleSandboxEvent(
          name: 'checkout.error',
          message: 'catalog mismatch',
        ),
      );
      expect(viewModel.snapshot.phase, PaddleSandboxPhase.error);
      expect(viewModel.snapshot.message, 'catalog mismatch');
    });

    test('redacts the token from bridge errors', () async {
      final gateway = _FakePaddleSandboxGateway(
        initializeErrorMessage: 'bad token $_validToken',
      );
      final viewModel = _viewModel(gateway);

      await viewModel.startCheckout();

      expect(viewModel.snapshot.phase, PaddleSandboxPhase.error);
      expect(viewModel.snapshot.message, isNot(contains(_validToken)));
      expect(viewModel.snapshot.message, contains('[token]'));
    });
  });
}

PaddleSandboxViewModel _viewModel(_FakePaddleSandboxGateway gateway) {
  return PaddleSandboxViewModel(
    config: const PaddleSandboxConfig(
      enabled: true,
      clientSideToken: _validToken,
      priceId: _validPriceId,
    ),
    gateway: gateway,
    currentUri: Uri.parse('https://example.com/paddle-sandbox'),
  );
}

class _FakePaddleSandboxGateway implements PaddleSandboxGateway {
  _FakePaddleSandboxGateway({this.initializeErrorMessage});

  final String? initializeErrorMessage;
  void Function(PaddleSandboxEvent event)? _onEvent;
  int initializeCalls = 0;
  int openCalls = 0;

  @override
  bool get isSupported => true;

  @override
  Future<void> initialize({
    required String clientSideToken,
    required void Function(PaddleSandboxEvent event) onEvent,
  }) async {
    initializeCalls += 1;
    _onEvent = onEvent;
    final errorMessage = initializeErrorMessage;
    if (errorMessage != null) throw StateError(errorMessage);
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
