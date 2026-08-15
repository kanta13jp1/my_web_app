import 'package:flutter/foundation.dart';

@immutable
class SupabaseRuntimeConfig {
  const SupabaseRuntimeConfig({
    required this.environment,
    required this.url,
    required this.publishableKey,
  });

  static const String productionProjectRef = 'smmkxxavexumewbfaqpy';
  static const String _productionUrl =
      'https://$productionProjectRef.supabase.co';
  static const String _productionPublishableKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
      'eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNtbWt4eGF2ZXh1bWV3YmZhcXB5Iiw'
      'icm9sZSI6ImFub24iLCJpYXQiOjE3NjA2OTExNzYsImV4cCI6MjA3NjI2NzE3Nn0.'
      'U2OsYRYFvbpu2QjTwXulJ67v9wouMMpn0y9B9K5-WHw';

  final String environment;
  final String url;
  final String publishableKey;

  static SupabaseRuntimeConfig fromCompileTimeEnvironment() {
    const environment = String.fromEnvironment(
      'ENVIRONMENT',
      defaultValue: 'production',
    );
    const url = String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: _productionUrl,
    );
    const publishableKey = String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: _productionPublishableKey,
    );

    return fromValues(
      environment: environment,
      url: url,
      publishableKey: publishableKey,
    );
  }

  @visibleForTesting
  static SupabaseRuntimeConfig fromValues({
    required String environment,
    required String url,
    required String publishableKey,
  }) {
    final normalizedEnvironment = environment.trim().toLowerCase();
    final normalizedUrl = url.trim();
    final normalizedKey = publishableKey.trim();
    final uri = Uri.tryParse(normalizedUrl);
    final isLoopback = uri != null &&
        (uri.host == 'localhost' ||
            uri.host == '127.0.0.1' ||
            uri.host == '::1');

    if (normalizedEnvironment.isEmpty) {
      throw StateError('ENVIRONMENT must not be empty.');
    }
    if (uri == null ||
        !uri.hasScheme ||
        !uri.hasAuthority ||
        (uri.scheme != 'https' && !isLoopback)) {
      throw StateError('SUPABASE_URL must be a valid HTTPS or localhost URL.');
    }
    if (normalizedKey.isEmpty) {
      throw StateError('SUPABASE_ANON_KEY must not be empty.');
    }
    if (normalizedEnvironment == 'staging' &&
        uri.host == '$productionProjectRef.supabase.co') {
      throw StateError(
        'Staging must not connect to the production Supabase project.',
      );
    }

    return SupabaseRuntimeConfig(
      environment: normalizedEnvironment,
      url: normalizedUrl,
      publishableKey: normalizedKey,
    );
  }
}
