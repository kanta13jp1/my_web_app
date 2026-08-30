import 'paddle_sandbox_gateway.dart';
import 'paddle_sandbox_models.dart';

PaddleSandboxGateway createPaddleSandboxGateway() {
  return const _UnsupportedPaddleSandboxGateway();
}

class _UnsupportedPaddleSandboxGateway implements PaddleSandboxGateway {
  const _UnsupportedPaddleSandboxGateway();

  @override
  bool get isSupported => false;

  @override
  Future<void> initialize({
    required String clientSideToken,
    required void Function(PaddleSandboxEvent event) onEvent,
  }) {
    throw UnsupportedError('Paddle sandbox checkout は Flutter Web 専用です。');
  }

  @override
  Future<void> openCheckout({
    required String priceId,
    required String successUrl,
  }) {
    throw UnsupportedError('Paddle sandbox checkout は Flutter Web 専用です。');
  }
}
