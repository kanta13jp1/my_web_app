import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('initialize synthetic localhost auth without a real server', () async {
    print('setup diagnostic: before preferences mock');
    SharedPreferences.setMockInitialValues(<String, Object>{});
    print('setup diagnostic: before Supabase initialize');
    await Supabase.initialize(
      url: 'http://127.0.0.1:9999',
      publishableKey: 'test-publishable-key',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
    ).timeout(const Duration(seconds: 15));
    print('setup diagnostic: Supabase initialize returned');
  });
}
