import 'package:flutter/foundation.dart';

import 'paddle_sandbox_gateway.dart';
import 'paddle_sandbox_models.dart';

class PaddleSandboxViewModel extends ChangeNotifier {
  PaddleSandboxViewModel({
    required PaddleSandboxConfig config,
    required PaddleSandboxGateway gateway,
    required Uri currentUri,
  })  : _config = config,
        _gateway = gateway,
        _currentUri = currentUri,
        _snapshot = _initialSnapshot(config, gateway);

  final PaddleSandboxConfig _config;
  final PaddleSandboxGateway _gateway;
  final Uri _currentUri;

  PaddleSandboxSnapshot _snapshot;
  PaddleSandboxSnapshot get snapshot => _snapshot;

  Future<void> startCheckout() async {
    if (!_snapshot.canStart) return;

    final validationError = _config.validationError;
    if (validationError != null) {
      _replace(
        PaddleSandboxPhase.misconfigured,
        'Sandbox 設定を確認してください',
        validationError,
      );
      return;
    }
    if (!_gateway.isSupported) {
      _replace(
        PaddleSandboxPhase.unsupported,
        'Flutter Web で開いてください',
        'Paddle.js checkout は Web ビルドでのみ利用できます。',
      );
      return;
    }

    try {
      _replace(
        PaddleSandboxPhase.initializing,
        'Paddle.js を初期化しています',
        'sandbox 環境と client-side token を確認しています。',
      );
      await _gateway.initialize(
        clientSideToken: _config.clientSideToken,
        onEvent: handleEvent,
      );
      _replace(
        PaddleSandboxPhase.opening,
        'チェックアウトを開いています',
        'Paddle sandbox の overlay を準備しています。',
      );
      await _gateway.openCheckout(
        priceId: _config.priceId,
        successUrl: _config.successUrl(_currentUri),
      );
      if (_snapshot.phase == PaddleSandboxPhase.opening) {
        _replace(
          PaddleSandboxPhase.checkoutOpen,
          'Sandbox checkout を開きました',
          '成功・失敗・キャンセルのいずれかを検証してください。',
        );
      }
    } catch (error) {
      _replace(
        PaddleSandboxPhase.error,
        'チェックアウトを開始できませんでした',
        _safeError(error),
        lastEventName: 'bridge.error',
      );
    }
  }

  void handleEvent(PaddleSandboxEvent event) {
    switch (event.name) {
      case 'checkout.loaded':
        _replace(
          PaddleSandboxPhase.checkoutOpen,
          'Sandbox checkout を開きました',
          'Paddle.js から checkout.loaded を受信しました。',
          lastEventName: event.name,
        );
      case 'checkout.completed':
        _replace(
          PaddleSandboxPhase.completed,
          'Sandbox 決済が完了しました',
          'テスト取引が完了しました。実課金は発生していません。',
          lastEventName: event.name,
          transactionId: event.transactionId,
        );
      case 'checkout.payment.failed':
      case 'checkout.payment.error':
        _replace(
          PaddleSandboxPhase.paymentFailed,
          'Sandbox 決済が拒否されました',
          event.message.isEmpty
              ? 'declined test card の結果を受信しました。入力内容を確認して再試行できます。'
              : event.message,
          lastEventName: event.name,
        );
      case 'checkout.closed':
        if (_snapshot.phase == PaddleSandboxPhase.completed) return;
        _replace(
          PaddleSandboxPhase.cancelled,
          'チェックアウトを閉じました',
          '決済は完了していません。必要ならもう一度開始できます。',
          lastEventName: event.name,
        );
      case 'checkout.error':
        _replace(
          PaddleSandboxPhase.error,
          'Paddle checkout でエラーが発生しました',
          event.message.isEmpty
              ? 'Paddle.js から checkout.error を受信しました。'
              : event.message,
          lastEventName: event.name,
        );
      default:
        _snapshot = PaddleSandboxSnapshot(
          phase: _snapshot.phase,
          title: _snapshot.title,
          message: _snapshot.message,
          lastEventName: event.name,
          transactionId: _snapshot.transactionId,
        );
        notifyListeners();
    }
  }

  void _replace(
    PaddleSandboxPhase phase,
    String title,
    String message, {
    String lastEventName = '',
    String transactionId = '',
  }) {
    _snapshot = PaddleSandboxSnapshot(
      phase: phase,
      title: title,
      message: message,
      lastEventName: lastEventName,
      transactionId: transactionId,
    );
    notifyListeners();
  }

  static PaddleSandboxSnapshot _initialSnapshot(
    PaddleSandboxConfig config,
    PaddleSandboxGateway gateway,
  ) {
    if (!config.enabled) {
      return const PaddleSandboxSnapshot(
        phase: PaddleSandboxPhase.disabled,
        title: 'Paddle sandbox は無効です',
        message: 'sandbox 用の dart-define を指定した Web ビルドでのみ有効になります。',
      );
    }
    final validationError = config.validationError;
    if (validationError != null) {
      return PaddleSandboxSnapshot(
        phase: PaddleSandboxPhase.misconfigured,
        title: 'Sandbox 設定を確認してください',
        message: validationError,
      );
    }
    if (!gateway.isSupported) {
      return const PaddleSandboxSnapshot(
        phase: PaddleSandboxPhase.unsupported,
        title: 'Flutter Web で開いてください',
        message: 'Paddle.js checkout は Web ビルドでのみ利用できます。',
      );
    }
    return const PaddleSandboxSnapshot(
      phase: PaddleSandboxPhase.ready,
      title: 'Sandbox checkout を開始できます',
      message: 'Paddle の sandbox workspace にだけ接続します。',
    );
  }

  String _safeError(Object error) {
    final text = error.toString().replaceAll(
          _config.clientSideToken,
          '[token]',
        );
    return text.length <= 240 ? text : '${text.substring(0, 240)}…';
  }
}
