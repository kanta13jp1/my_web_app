import 'dart:convert';

import 'package:flutter/foundation.dart';

@immutable
class SupabaseRuntimeConfig {
  const SupabaseRuntimeConfig({
    required this.environment,
    required this.url,
    required this.publishableKey,
  });

  final String environment;
  final String url;
  final String publishableKey;

  static SupabaseRuntimeConfig fromCompileTimeEnvironment() {
    const environment = String.fromEnvironment(
      'ENVIRONMENT',
      defaultValue: 'production',
    );
    const url = String.fromEnvironment('SUPABASE_URL');
    const publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
    const productionProjectRef = String.fromEnvironment(
      'SUPABASE_PRODUCTION_PROJECT_REF',
    );

    return fromValues(
      environment: environment,
      url: url,
      publishableKey: publishableKey,
      productionProjectRef: productionProjectRef,
    );
  }

  @visibleForTesting
  static SupabaseRuntimeConfig fromValues({
    required String environment,
    required String url,
    required String publishableKey,
    String productionProjectRef = '',
  }) {
    final normalizedEnvironment = environment.trim().toLowerCase();
    final normalizedUrl = url.trim();
    final normalizedKey = publishableKey.trim();
    final normalizedProductionProjectRef = productionProjectRef.trim();
    final uri = Uri.tryParse(normalizedUrl);
    final isLoopback = uri != null &&
        (uri.host == 'localhost' ||
            uri.host == '127.0.0.1' ||
            uri.host == '::1');
    final hasOriginOnlyPath =
        uri != null && (uri.path.isEmpty || uri.path == '/');

    if (normalizedEnvironment.isEmpty) {
      throw StateError('ENVIRONMENT must not be empty.');
    }
    if (uri == null ||
        !uri.hasScheme ||
        !uri.hasAuthority ||
        uri.userInfo.isNotEmpty ||
        !hasOriginOnlyPath ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.scheme != 'https' && !(uri.scheme == 'http' && isLoopback))) {
      throw StateError('SUPABASE_URL must be a valid HTTPS or localhost URL.');
    }
    if (normalizedKey.isEmpty) {
      throw StateError('SUPABASE_PUBLISHABLE_KEY must not be empty.');
    }
    final legacyRole = _legacyJwtRole(normalizedKey);
    if (normalizedKey.startsWith('sb_secret_') ||
        legacyRole == 'service_role') {
      throw StateError(
        'SUPABASE_PUBLISHABLE_KEY must never contain a secret or service_role key.',
      );
    }
    if (!normalizedKey.startsWith('sb_publishable_') && legacyRole != 'anon') {
      throw StateError(
        'SUPABASE_PUBLISHABLE_KEY must contain an sb_publishable_ key or a legacy anon JWT.',
      );
    }
    if (normalizedEnvironment == 'staging' &&
        !RegExp(
          r'^[a-z0-9]{20}$',
        ).hasMatch(normalizedProductionProjectRef.toLowerCase())) {
      throw StateError(
        'SUPABASE_PRODUCTION_PROJECT_REF is required for staging isolation.',
      );
    }
    if (normalizedEnvironment == 'staging' &&
        normalizedProductionProjectRef.isNotEmpty &&
        uri.host ==
            '${normalizedProductionProjectRef.toLowerCase()}.supabase.co') {
      throw StateError(
        'Staging must not connect to the production Supabase project.',
      );
    }

    return SupabaseRuntimeConfig(
      environment: normalizedEnvironment,
      url: normalizedUrl.endsWith('/')
          ? normalizedUrl.substring(0, normalizedUrl.length - 1)
          : normalizedUrl,
      publishableKey: normalizedKey,
    );
  }

  Uri functionUri(String functionName) {
    final normalizedName = functionName.trim();
    if (!RegExp(r'^[a-z0-9][a-z0-9-]*$').hasMatch(normalizedName)) {
      throw ArgumentError.value(
        functionName,
        'functionName',
        'Function name must be one non-empty path segment.',
      );
    }
    return Uri.parse('$url/functions/v1/$normalizedName');
  }

  static String? _legacyJwtRole(String key) {
    final segments = key.split('.');
    if (segments.length != 3) {
      return null;
    }
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(segments[1]))),
      );
      if (payload is Map && payload['role'] is String) {
        return payload['role'] as String;
      }
      return null;
    } on FormatException {
      return null;
    }
  }
}
