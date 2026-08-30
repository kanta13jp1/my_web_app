import 'paddle_sandbox_models.dart';

abstract class PaddleSandboxGateway {
  bool get isSupported;

  Future<void> initialize({
    required String clientSideToken,
    required void Function(PaddleSandboxEvent event) onEvent,
  });

  Future<void> openCheckout({
    required String priceId,
    required String successUrl,
  });
}
