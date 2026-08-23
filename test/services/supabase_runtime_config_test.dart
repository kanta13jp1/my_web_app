import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/supabase_runtime_config.dart';

void main() {
  group('SupabaseRuntimeConfig', () {
    test('accepts an isolated staging project', () {
      final config = SupabaseRuntimeConfig.fromValues(
        environment: 'staging',
        url: 'https://abcdefghijklmnopqrst.supabase.co',
        publishableKey: 'public-anon-key',
      );

      expect(config.environment, 'staging');
      expect(config.url, 'https://abcdefghijklmnopqrst.supabase.co');
    });

    test('rejects the production project in staging', () {
      expect(
        () => SupabaseRuntimeConfig.fromValues(
          environment: 'staging',
          url:
              'https://${SupabaseRuntimeConfig.productionProjectRef}.supabase.co',
          publishableKey: 'public-anon-key',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('allows localhost for isolated validation', () {
      final config = SupabaseRuntimeConfig.fromValues(
        environment: 'local',
        url: 'http://127.0.0.1:54321',
        publishableKey: 'local-anon-key',
      );

      expect(config.environment, 'local');
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
