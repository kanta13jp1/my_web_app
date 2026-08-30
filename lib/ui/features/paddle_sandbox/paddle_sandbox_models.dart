enum PaddleSandboxPhase {
  disabled,
  misconfigured,
  unsupported,
  ready,
  initializing,
  opening,
  checkoutOpen,
  completed,
  paymentFailed,
  cancelled,
  error,
}

class PaddleSandboxConfig {
  const PaddleSandboxConfig({
    required this.enabled,
    required this.clientSideToken,
    required this.priceId,
  });

  factory PaddleSandboxConfig.fromEnvironment() {
    return const PaddleSandboxConfig(
      enabled: bool.fromEnvironment('PADDLE_SANDBOX_ENABLED'),
      clientSideToken: String.fromEnvironment('PADDLE_SANDBOX_CLIENT_TOKEN'),
      priceId: String.fromEnvironment('PADDLE_SANDBOX_PRICE_ID'),
    );
  }

  final bool enabled;
  final String clientSideToken;
  final String priceId;

  static final RegExp _sandboxTokenPattern = RegExp(r'^test_[a-zA-Z0-9]{27}$');
  static final RegExp _priceIdPattern = RegExp(r'^pri_[a-z0-9]+$');

  String? get validationError {
    if (!enabled) {
      return 'Paddle sandbox はビルド設定で無効です。';
    }
    if (!_sandboxTokenPattern.hasMatch(clientSideToken)) {
      return 'sandbox client-side token（test_ で始まる値）が必要です。';
    }
    if (!_priceIdPattern.hasMatch(priceId)) {
      return 'sandbox の price ID（pri_ で始まる値）が必要です。';
    }
    return null;
  }

  String successUrl(Uri currentUri) {
    final base = currentUri.hasScheme ? currentUri : Uri.base;
    if (base.scheme != 'http' && base.scheme != 'https') {
      throw const FormatException('Paddle の戻り先には HTTP(S) URL が必要です。');
    }
    return Uri.parse(base.origin).replace(
      path: '/paddle-sandbox',
      queryParameters: const {'paddle': 'completed'},
    ).toString();
  }
}

class PaddleSandboxEvent {
  const PaddleSandboxEvent({
    required this.name,
    this.transactionId = '',
    this.message = '',
  });

  final String name;
  final String transactionId;
  final String message;
}

class PaddleSandboxSnapshot {
  const PaddleSandboxSnapshot({
    required this.phase,
    required this.title,
    required this.message,
    this.lastEventName = '',
    this.transactionId = '',
  });

  final PaddleSandboxPhase phase;
  final String title;
  final String message;
  final String lastEventName;
  final String transactionId;

  bool get isBusy =>
      phase == PaddleSandboxPhase.initializing ||
      phase == PaddleSandboxPhase.opening;

  bool get canStart =>
      phase == PaddleSandboxPhase.ready ||
      phase == PaddleSandboxPhase.completed ||
      phase == PaddleSandboxPhase.paymentFailed ||
      phase == PaddleSandboxPhase.cancelled ||
      phase == PaddleSandboxPhase.error;
}
