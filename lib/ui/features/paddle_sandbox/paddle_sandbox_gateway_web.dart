import 'dart:js_interop';

import 'paddle_sandbox_gateway.dart';
import 'paddle_sandbox_models.dart';

@JS('paddleSandboxBridge.initialize')
external JSPromise<JSString> _initializePaddleSandbox(
  JSString clientSideToken,
  JSFunction eventCallback,
);

@JS('paddleSandboxBridge.openCheckout')
external JSPromise<JSString> _openPaddleSandboxCheckout(
  JSString priceId,
  JSString successUrl,
);

PaddleSandboxGateway createPaddleSandboxGateway() {
  return _WebPaddleSandboxGateway();
}

class _WebPaddleSandboxGateway implements PaddleSandboxGateway {
  JSFunction? _eventCallback;

  @override
  bool get isSupported => true;

  @override
  Future<void> initialize({
    required String clientSideToken,
    required void Function(PaddleSandboxEvent event) onEvent,
  }) async {
    _eventCallback =
        (JSString eventName, JSString transactionId, JSString message) {
      onEvent(
        PaddleSandboxEvent(
          name: eventName.toDart,
          transactionId: transactionId.toDart,
          message: message.toDart,
        ),
      );
    }.toJS;

    await _initializePaddleSandbox(
      clientSideToken.toJS,
      _eventCallback!,
    ).toDart;
  }

  @override
  Future<void> openCheckout({
    required String priceId,
    required String successUrl,
  }) async {
    await _openPaddleSandboxCheckout(priceId.toJS, successUrl.toJS).toDart;
  }
}
