import 'package:flutter/foundation.dart' show kReleaseMode;

enum PaddleCheckoutPhase {
  idle,
  opening,
  opened,
  completed,
  failed,
  canceled,
  unavailable,
}

class PaddleSandboxConfig {
  const PaddleSandboxConfig({
    required this.enabled,
    required this.clientSideToken,
    required this.priceId,
    required this.releaseMode,
  });

  factory PaddleSandboxConfig.fromEnvironment() {
    return const PaddleSandboxConfig(
      enabled: bool.fromEnvironment('PADDLE_SANDBOX_ENABLED'),
      clientSideToken: String.fromEnvironment(
        'PADDLE_SANDBOX_CLIENT_TOKEN',
      ),
      priceId: String.fromEnvironment('PADDLE_SANDBOX_PRICE_ID'),
      releaseMode: kReleaseMode,
    );
  }

  final bool enabled;
  final String clientSideToken;
  final String priceId;
  final bool releaseMode;

  /// The sandbox experiment is never exposed by a release build.
  bool get shouldExpose => enabled && !releaseMode;

  String? get validationMessage {
    if (releaseMode) {
      return 'Paddle sandbox は本番ビルドでは利用できません。';
    }
    if (!enabled) {
      return 'Paddle sandbox は無効です。';
    }
    if (!clientSideToken.trim().startsWith('test_')) {
      return 'Paddle sandbox の client-side token が設定されていません。';
    }
    if (!priceId.trim().startsWith('pri_')) {
      return 'Paddle sandbox の price ID が設定されていません。';
    }
    return null;
  }

  bool get canOpen => shouldExpose && validationMessage == null;
}

class PaddleCheckoutEvent {
  const PaddleCheckoutEvent({
    required this.name,
    this.checkoutId,
    this.transactionId,
    this.message,
  });

  final String name;
  final String? checkoutId;
  final String? transactionId;
  final String? message;

  factory PaddleCheckoutEvent.fromJson(Map<String, dynamic> json) {
    return PaddleCheckoutEvent(
      name: json['name']?.toString() ?? '',
      checkoutId: _nonEmpty(json['checkoutId']),
      transactionId: _nonEmpty(json['transactionId']),
      message: _nonEmpty(json['message']),
    );
  }
}

class PaddleCheckoutState {
  const PaddleCheckoutState({
    required this.phase,
    required this.message,
    this.checkoutId,
    this.transactionId,
  });

  const PaddleCheckoutState.idle()
      : phase = PaddleCheckoutPhase.idle,
        message = 'Paddle sandbox checkout を開始できます。',
        checkoutId = null,
        transactionId = null;

  final PaddleCheckoutPhase phase;
  final String message;
  final String? checkoutId;
  final String? transactionId;

  bool get isBusy =>
      phase == PaddleCheckoutPhase.opening ||
      phase == PaddleCheckoutPhase.opened;
}

abstract interface class PaddleCheckoutGateway {
  Future<void> openCheckout({
    required PaddleSandboxConfig config,
    required void Function(PaddleCheckoutEvent event) onEvent,
  });

  void dispose();
}

class PaddleCheckoutException implements Exception {
  const PaddleCheckoutException(this.message);

  final String message;

  @override
  String toString() => 'PaddleCheckoutException: $message';
}

String? _nonEmpty(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
