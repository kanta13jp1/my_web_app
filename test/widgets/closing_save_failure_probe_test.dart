import 'dart:async';
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
  var failSave = true;
  Completer<void>? holdWrite;
  setUp(() {
    closingWrites = 0;
    failSave = true;
    holdWrite = null;
    SharedPreferences.setMockInitialValues({});
  });
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
          }), 200, headers: headers, request: request);
        }
        if (request.url.path.endsWith('/cfo_daily_closings') &&
            request.method == 'POST') {
          closingWrites++;
          await holdWrite?.future;
          if (!failSave) {
            return http.Response('', 201, headers: headers, request: request);
          }
          return http.Response(
            '{"code":"XX000","message":"simulated save failure"}',
            500,
            headers: headers,
            request: request,
          );
        }
        return http.Response('[]', 200, headers: headers, request: request);
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
    expect(find.textContaining('チェックを保存できませんでした'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('successful closing save keeps the requested completion',
      (tester) async {
    failSave = false;
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
    expect(closingWrites, 1);
    expect(tester.widget<CheckboxListTile>(item).value, isTrue);
    expect(find.textContaining('チェックを保存できませんでした'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('automatic check reports a failed save instead of success',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: AssetManagementPage()));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final action = find.text('記録状況から自動チェック');
    await tester.ensureVisible(action);
    await tester.tap(action);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(closingWrites, 1);
    expect(find.textContaining('チェックを保存できませんでした'), findsOneWidget);
    expect(find.textContaining('登録口座の本日記録を確認しました。'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('a pending save prevents a second write and rolls back on failure',
      (tester) async {
    holdWrite = Completer<void>();
    await tester.binding.setSurfaceSize(const Size(1200, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: AssetManagementPage()));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final first = find.widgetWithText(CheckboxListTile, '① 全資産額を記録して把握');
    final second = find.widgetWithText(CheckboxListTile, '② 全負債額を記録して把握');
    await tester.ensureVisible(first);
    await tester.tap(first);
    await tester.pump(const Duration(milliseconds: 100));
    expect(closingWrites, 1);
    await tester.ensureVisible(second);
    await tester.tap(second);
    await tester.pump(const Duration(milliseconds: 100));
    expect(closingWrites, 1, reason: 'only one request may be in flight');
    expect(tester.widget<CheckboxListTile>(second).value, isFalse);
    holdWrite!.complete();
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.widget<CheckboxListTile>(first).value, isFalse);
    expect(find.textContaining('チェックを保存できませんでした'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });
}
