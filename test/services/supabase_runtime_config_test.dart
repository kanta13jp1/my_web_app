import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/supabase_runtime_config.dart';

void main() {
  group('SupabaseRuntimeConfig', () {
    test('accepts an isolated staging project', () {
      final config = SupabaseRuntimeConfig.fromValues(
        environment: 'staging',
        url: 'https://abcdefghijklmnopqrst.supabase.co',
        publishableKey: 'sb_publishable_example',
        productionProjectRef: 'zyxwvutsrqponmlkjihg',
      );

      expect(config.environment, 'staging');
      expect(config.url, 'https://abcdefghijklmnopqrst.supabase.co');
    });

    test('rejects the production project in staging', () {
      expect(
        () => SupabaseRuntimeConfig.fromValues(
          environment: 'staging',
          url: 'https://zyxwvutsrqponmlkjihg.supabase.co',
          publishableKey: 'sb_publishable_example',
          productionProjectRef: 'zyxwvutsrqponmlkjihg',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('allows localhost for isolated validation', () {
      final config = SupabaseRuntimeConfig.fromValues(
        environment: 'local',
        url: 'http://127.0.0.1:54321',
        publishableKey: 'sb_publishable_local',
      );

      expect(config.environment, 'local');
    });

    test('normalizes a trailing slash on the project origin', () {
      final config = SupabaseRuntimeConfig.fromValues(
        environment: 'local',
        url: 'http://127.0.0.1:54321/',
        publishableKey: 'sb_publishable_local',
      );

      expect(config.url, 'http://127.0.0.1:54321');
    });

    test('rejects unsupported URL schemes even for localhost', () {
      expect(
        () => SupabaseRuntimeConfig.fromValues(
          environment: 'local',
          url: 'ftp://127.0.0.1:54321',
          publishableKey: 'sb_publishable_local',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('rejects a new secret key', () {
      expect(
        () => SupabaseRuntimeConfig.fromValues(
          environment: 'production',
          url: 'https://example.supabase.co',
          publishableKey: 'sb_secret_example',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('rejects a legacy service role JWT', () {
      final serviceRoleJwt = _fakeLegacyJwt('service_role');
      expect(
        () => SupabaseRuntimeConfig.fromValues(
          environment: 'production',
          url: 'https://example.supabase.co',
          publishableKey: serviceRoleJwt,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('accepts a legacy anon JWT during migration', () {
      final config = SupabaseRuntimeConfig.fromValues(
        environment: 'production',
        url: 'https://example.supabase.co',
        publishableKey: _fakeLegacyJwt('anon'),
      );

      expect(config.publishableKey, isNotEmpty);
    });

    test('requires the production project ref in staging', () {
      expect(
        () => SupabaseRuntimeConfig.fromValues(
          environment: 'staging',
          url: 'https://abcdefghijklmnopqrst.supabase.co',
          publishableKey: 'sb_publishable_example',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('builds an Edge Function URI from the injected project URL', () {
      final config = SupabaseRuntimeConfig.fromValues(
        environment: 'production',
        url: 'https://example.supabase.co',
        publishableKey: 'sb_publishable_example',
      );

      expect(
        config.functionUri('core-hub'),
        Uri.parse('https://example.supabase.co/functions/v1/core-hub'),
      );
      expect(() => config.functionUri('../core-hub'), throwsArgumentError);
    });

    test('rejects an empty publishable key', () {
      expect(
        () => SupabaseRuntimeConfig.fromValues(
          environment: 'production',
          url: 'https://example.supabase.co',
          publishableKey: ' ',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}

String _fakeLegacyJwt(String role) {
  final payload = base64Url
      .encode(utf8.encode(jsonEncode(<String, String>{'role': role})))
      .replaceAll('=', '');
  return 'header.$payload.signature';
}
