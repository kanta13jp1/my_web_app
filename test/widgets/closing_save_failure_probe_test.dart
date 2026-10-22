import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Diagnostic only: no production endpoint, credentials, or persisted user data.
void main() {
  var closingWrites = 0;
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final payload = base64Url.encode(utf8.encode(jsonEncode({
      'sub': '00000000-0000-4000-8000-000000000001',
      'exp': 4102444800,
      'role': 'authenticated',
    }))).replaceAll('=', '');
    await Supabase.initialize(
      url: 'http://127.0.0.1:9999',
      publishableKey: 'diagnostic-test-key',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        const headers = {'content-type': 'application/json'};
        if (request.url.path == '/auth/v1/token') {
          return http.Response(jsonEncode({
            'access_token': 'e30.$payload.test',
            'refresh_token': 'diagnostic-refresh',
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': {
              'id': '00000000-0000-4000-8000-000000000001',
              'aud': 'authenticated',
              'role': 'authenticated',
              'app_metadata': {},
              'user_metadata': {},
              'created_at': '2026-01-01T00:00:00Z',
            },
          }), 200, headers: headers);
        }
        if (request.url.path.endsWith('/cfo_daily_closings') &&
            request.method == 'POST') {
          closingWrites++;
          return http.Response(
            '{"code":"XX000","message":"simulated save failure"}',
            500,
            headers: headers,
          );
        }
        return http.Response('[]', 200, headers: headers);
      }),
    );
    await Supabase.instance.client.auth.signInWithPassword(
      email: 'probe@example.invalid',
      password: 'synthetic-only',
    );
  });

  testWidgets('failed closing save must not leave an unchecked item completed',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: AssetManagementPage()));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final item = find.widgetWithText(CheckboxListTile, '① 全資産額を記録して把握');
    await tester.ensureVisible(item);
    await tester.tap(item);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(closingWrites, greaterThan(0), reason: 'must exercise the failing write');
    expect(tester.widget<CheckboxListTile>(item).value, isFalse,
        reason: 'a failed write cannot be presented as completed');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });
}
