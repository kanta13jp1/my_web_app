import 'package:flutter/foundation.dart';

import '../../../../services/paddle_checkout.dart';

class PaddleSandboxCheckoutController extends ChangeNotifier {
  PaddleSandboxCheckoutController({
    required this.config,
    required PaddleCheckoutGateway gateway,
  })  : _gateway = gateway,
        _state = _initialState(config);

  final PaddleSandboxConfig config;
  final PaddleCheckoutGateway _gateway;

  PaddleCheckoutState _state;
  bool _disposed = false;

  PaddleCheckoutState get state => _state;

  Future<void> openCheckout() async {
    if (_state.isBusy) return;
    final validationMessage = config.validationMessage;
    if (validationMessage != null) {
      _replaceState(
        PaddleCheckoutState(
          phase: PaddleCheckoutPhase.unavailable,
          message: validationMessage,
        ),
      );
      return;
    }

    _replaceState(
      const PaddleCheckoutState(
        phase: PaddleCheckoutPhase.opening,
        message: 'Paddle.js を読み込み、sandbox checkout を準備しています。',
      ),
    );
    try {
      await _gateway.openCheckout(config: config, onEvent: _handleEvent);
    } catch (error) {
      debugPrint('Paddle sandbox checkout failed to open: $error');
      _replaceState(
        const PaddleCheckoutState(
          phase: PaddleCheckoutPhase.failed,
          message: 'Paddle sandbox の決済画面を開けませんでした。設定を確認して再試行してください。',
        ),
      );
    }
  }

  void _handleEvent(PaddleCheckoutEvent event) {
    if (_disposed) return;
    final current = _state;
    switch (event.name) {
      case 'checkout.loaded':
        _replaceState(
          PaddleCheckoutState(
            phase: PaddleCheckoutPhase.opened,
            message: 'Paddle sandbox checkout を表示しています。',
            checkoutId: event.checkoutId,
            transactionId: event.transactionId,
          ),
        );
      case 'checkout.updated':
        _replaceState(
          PaddleCheckoutState(
            phase: PaddleCheckoutPhase.opened,
            message: event.hasTaxIdentifier
                ? 'VAT / Tax ID を反映したSandbox税額を確認できます。'
                : 'Paddle sandbox checkout を表示しています。',
            checkoutId: event.checkoutId ?? current.checkoutId,
            transactionId: event.transactionId ?? current.transactionId,
            currencyCode: event.currencyCode,
            subtotal: event.subtotal,
            tax: event.tax,
            total: event.total,
            hasBusiness: event.hasBusiness,
            hasTaxIdentifier: event.hasTaxIdentifier,
          ),
        );
      case 'checkout.completed':
        _replaceState(
          PaddleCheckoutState(
            phase: PaddleCheckoutPhase.completed,
            message: 'Sandbox 決済が完了しました。実際の請求は発生していません。',
            checkoutId: event.checkoutId,
            transactionId: event.transactionId,
            currencyCode: event.currencyCode ?? current.currencyCode,
            subtotal: event.subtotal ?? current.subtotal,
            tax: event.tax ?? current.tax,
            total: event.total ?? current.total,
            hasBusiness: event.hasBusiness || current.hasBusiness,
            hasTaxIdentifier:
                event.hasTaxIdentifier || current.hasTaxIdentifier,
          ),
        );
      case 'checkout.payment.failed':
      case 'checkout.payment.error':
      case 'checkout.error':
        _replaceState(
          PaddleCheckoutState(
            phase: PaddleCheckoutPhase.failed,
            message: 'Sandbox 決済に失敗しました。入力内容を確認して再試行してください。',
            checkoutId: event.checkoutId,
            transactionId: event.transactionId,
            currencyCode: event.currencyCode ?? current.currencyCode,
            subtotal: event.subtotal ?? current.subtotal,
            tax: event.tax ?? current.tax,
            total: event.total ?? current.total,
            hasBusiness: event.hasBusiness || current.hasBusiness,
            hasTaxIdentifier:
                event.hasTaxIdentifier || current.hasTaxIdentifier,
          ),
        );
      case 'checkout.closed':
        if (current.phase == PaddleCheckoutPhase.completed ||
            current.phase == PaddleCheckoutPhase.failed) {
          return;
        }
        _replaceState(
          PaddleCheckoutState(
            phase: PaddleCheckoutPhase.canceled,
            message: 'Sandbox checkout を中断しました。請求は発生していません。',
            checkoutId: event.checkoutId,
            transactionId: event.transactionId,
          ),
        );
      default:
        break;
    }
  }

  void _replaceState(PaddleCheckoutState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _gateway.dispose();
    super.dispose();
  }
}

PaddleCheckoutState _initialState(PaddleSandboxConfig config) {
  final message = config.validationMessage;
  return message == null
      ? const PaddleCheckoutState.idle()
      : PaddleCheckoutState(
          phase: PaddleCheckoutPhase.unavailable,
          message: message,
        );
}
