import 'paddle_checkout.dart';

PaddleCheckoutGateway createPaddleCheckoutGateway() {
  return _UnsupportedPaddleCheckoutGateway();
}

class _UnsupportedPaddleCheckoutGateway implements PaddleCheckoutGateway {
  @override
  Future<void> openCheckout({
    required PaddleSandboxConfig config,
    required void Function(PaddleCheckoutEvent event) onEvent,
  }) {
    throw const PaddleCheckoutException(
      'Paddle Checkout is only available on Flutter Web.',
    );
  }

  @override
  void dispose() {}
}
