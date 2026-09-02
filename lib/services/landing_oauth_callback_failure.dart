import 'package:flutter/foundation.dart';

enum LandingOAuthCallbackFailureCategory {
  cancelled,
  rateLimited,
  providerConfiguration,
  redirectConfiguration,
  callbackExchange,
  unknown,
}

@immutable
class LandingOAuthCallbackFailure {
  const LandingOAuthCallbackFailure({
    required this.category,
    required this.userMessage,
  });

  final LandingOAuthCallbackFailureCategory category;
  final String userMessage;

  static LandingOAuthCallbackFailure? fromUri(Uri? uri) {
    if (uri == null) {
      return null;
    }

    final parameters = <String, String>{...uri.queryParameters};
    final fragment = uri.fragment.trim();
    if (fragment.isNotEmpty) {
      final queryStart = fragment.indexOf('?');
      final encoded = queryStart >= 0
          ? fragment.substring(queryStart + 1)
          : fragment.startsWith('#')
              ? fragment.substring(1)
              : fragment;
      try {
        parameters.addAll(Uri.splitQueryString(encoded));
      } on FormatException {
        // A malformed callback is still surfaced as an unknown OAuth failure.
      }
    }

    final safeCategory = _categoryFromSafeCode(
      parameters['oauth_callback_failure']?.trim().toLowerCase(),
    );
    if (safeCategory != null) {
      return LandingOAuthCallbackFailure(
        category: safeCategory,
        userMessage: _messageFor(safeCategory),
      );
    }

    final error = parameters['error']?.trim() ?? '';
    final code = parameters['error_code']?.trim() ?? '';
    final description = parameters['error_description']?.trim() ?? '';
    if (error.isEmpty && code.isEmpty && description.isEmpty) {
      return null;
    }

    final signal = '$error $code $description'.toLowerCase();
    final category = _classify(signal);
    return LandingOAuthCallbackFailure(
      category: category,
      userMessage: _messageFor(category),
    );
  }

  static LandingOAuthCallbackFailureCategory _classify(String signal) {
    if (signal.contains('access_denied') ||
        signal.contains('cancelled') ||
        signal.contains('canceled') ||
        signal.contains('user denied')) {
      return LandingOAuthCallbackFailureCategory.cancelled;
    }
    if (signal.contains('rate_limit') ||
        signal.contains('too many requests') ||
        signal.contains('429')) {
      return LandingOAuthCallbackFailureCategory.rateLimited;
    }
    if (signal.contains('provider_disabled') ||
        signal.contains('provider is not enabled') ||
        signal.contains('unsupported provider')) {
      return LandingOAuthCallbackFailureCategory.providerConfiguration;
    }
    if (signal.contains('redirect') || signal.contains('callback url')) {
      return LandingOAuthCallbackFailureCategory.redirectConfiguration;
    }
    if (signal.contains('flow_state') ||
        signal.contains('pkce') ||
        signal.contains('code exchange') ||
        signal.contains('exchange external code') ||
        signal.contains('unable to exchange') ||
        signal.contains('oauth state')) {
      return LandingOAuthCallbackFailureCategory.callbackExchange;
    }
    return LandingOAuthCallbackFailureCategory.unknown;
  }

  static LandingOAuthCallbackFailureCategory? _categoryFromSafeCode(
    String? code,
  ) {
    return switch (code) {
      'cancelled' => LandingOAuthCallbackFailureCategory.cancelled,
      'rate_limit' => LandingOAuthCallbackFailureCategory.rateLimited,
      'provider_config' =>
        LandingOAuthCallbackFailureCategory.providerConfiguration,
      'redirect' => LandingOAuthCallbackFailureCategory.redirectConfiguration,
      'callback_exchange' =>
        LandingOAuthCallbackFailureCategory.callbackExchange,
      'unknown' => LandingOAuthCallbackFailureCategory.unknown,
      _ => null,
    };
  }

  static String _messageFor(
    LandingOAuthCallbackFailureCategory category,
  ) {
    switch (category) {
      case LandingOAuthCallbackFailureCategory.cancelled:
        return 'Google登録は完了していません。もう一度試すか、Magic Linkで続けられます。';
      case LandingOAuthCallbackFailureCategory.rateLimited:
        return 'Google登録の試行が続いたため、一時的に完了できません。少し待つか、Magic Linkで続けてください。';
      case LandingOAuthCallbackFailureCategory.providerConfiguration:
      case LandingOAuthCallbackFailureCategory.redirectConfiguration:
      case LandingOAuthCallbackFailureCategory.callbackExchange:
        return '現在Google登録を完了できません。Magic Linkならメール1通で続けられます。';
      case LandingOAuthCallbackFailureCategory.unknown:
        return 'Google登録を完了できませんでした。もう一度試すか、Magic Linkで続けてください。';
    }
  }
}
