import 'dart:convert';
import 'dart:js_interop';

import 'paddle_checkout.dart';

@JS('openPaddleSandboxCheckout')
external JSPromise<JSAny?> _openPaddleSandboxCheckout(
  JSString clientSideToken,
  JSString priceId,
  JSFunction eventCallback,
);

@JS('releasePaddleSandboxCheckout')
external void _releasePaddleSandboxCheckout(JSFunction eventCallback);

PaddleCheckoutGateway createPaddleCheckoutGateway() {
  return PaddleJsCheckoutGateway();
}

class PaddleJsCheckoutGateway implements PaddleCheckoutGateway {
  JSFunction? _eventCallback;

  @override
  Future<void> openCheckout({
    required PaddleSandboxConfig config,
    required void Function(PaddleCheckoutEvent event) onEvent,
  }) async {
    final validationMessage = config.validationMessage;
    if (validationMessage != null) {
      throw PaddleCheckoutException(validationMessage);
    }

    final callback = ((JSString rawEvent) {
      final decoded = jsonDecode(rawEvent.toDart);
      if (decoded is! Map) return;
      onEvent(
        PaddleCheckoutEvent.fromJson(
          decoded.map((key, value) => MapEntry(key.toString(), value)),
        ),
      );
    }).toJS;
    _eventCallback = callback;

    await _openPaddleSandboxCheckout(
      config.clientSideToken.trim().toJS,
      config.priceId.trim().toJS,
      callback,
    ).toDart;
  }

  @override
  void dispose() {
    final callback = _eventCallback;
    _eventCallback = null;
    if (callback == null) return;
    try {
      _releasePaddleSandboxCheckout(callback);
    } catch (_) {
      // The local bridge may already be gone during a page teardown.
    }
  }
}
