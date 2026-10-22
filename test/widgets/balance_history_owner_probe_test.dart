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
  var balanceWrites = 0;
  var historyReads = 0;
  var historyGate = Completer<void>();
  var relatedWrites = 0;
  var syntheticUserId = '00000000-0000-4000-8000-000000000001';
  Completer<void>? balanceGate;
  var failBalanceAt = 1;
  var failRelatedWrite = false;
  var lastBalanceBatchSize = 0;
  final persistedBalances = <Map<String, dynamic>>[];
  var failSave = true;
  Completer<void>? holdWrite;
  Completer<void>? holdRead;

  var provideTodayBalance = false;
  var failClosingRead = false;
  var persistedClosing = false;
  var provideTask = false;
  Completer<void>? staleRead;
  var staleReads = 0;
  var reflectSuccessfulWrite = false;
  Map<String, dynamic>? serverClosing;
  Map<String, dynamic>? lastClosingWrite;
  setUp(() async {
    historyReads = 0;
    historyGate = Completer<void>();
    syntheticUserId = '00000000-0000-4000-8000-000000000001';
    if (Supabase.instance.client.auth.currentUser?.id != syntheticUserId) {
      await Supabase.instance.client.auth.signInWithPassword(
        email: 'probe@example.invalid',
        password: 'synthetic-only',
      );
    }

    failRelatedWrite = false;
    balanceWrites = 0;
    relatedWrites = 0;
    balanceGate = null;
    failBalanceAt = 1;
    lastBalanceBatchSize = 0;
    persistedBalances.clear();
    failSave = true;
    holdWrite = null;
    holdRead = null;

    provideTodayBalance = false;
    failClosingRead = false;
    persistedClosing = false;
    provideTask = false;
    staleRead = null;
    staleReads = 0;
    reflectSuccessfulWrite = false;
    serverClosing = null;
    lastClosingWrite = null;
    SharedPreferences.setMockInitialValues({});
  });
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final payload = base64Url
        .encode(
          utf8.encode(
            jsonEncode({
              'sub': '00000000-0000-4000-8000-000000000001',
              'exp': 4102444800,
              'role': 'authenticated',
            }),
          ),
        )
        .replaceAll('=', '');
    await Supabase.initialize(
      url: 'http://127.0.0.1:9999',
      publishableKey: 'diagnostic-test-key',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        const headers = {'content-type': 'application/json'};
        if (request.url.path == '/auth/v1/token') {
          return http.Response(
            jsonEncode({
              'access_token': 'e30.$payload.test',
              'refresh_token': 'diagnostic-refresh',
              'token_type': 'bearer',
              'expires_in': 3600,
              'user': {
                'id': syntheticUserId,
                'aud': 'authenticated',
                'role': 'authenticated',
                'app_metadata': {},
                'user_metadata': {},
                'created_at': '2026-01-01T00:00:00Z',
              },
            }),
            200,
            headers: headers,
            request: request,
          );
        }
        if (request.url.path
            .endsWith('/rpc/asset_management_recent_cfo_assets')) {
          return http.Response(
            '[{"id":1,"title":"現金","amount":1000,"created_at":"2026-01-01T03:00:00Z"},{"id":2,"title":"合成預金","amount":2000,"created_at":"2026-01-01T03:00:00Z"}]',
            200,
            headers: headers,
            request: request,
          );
        }
        if (request.method == 'POST' &&
            request.url.path.endsWith('/wealth_struggles')) {
          relatedWrites++;
        }
        if (failRelatedWrite &&
            request.method == 'POST' &&
            request.url.path.endsWith('/wealth_struggles')) {
          return http.Response(
            '{"message":"synthetic related failure"}',
            500,
            headers: headers,
            request: request,
          );
        }
        if (request.method == 'GET' &&
            request.url.path.endsWith('/cfo_assets') &&
            request.url.queryParameters['title'] == 'eq.合成預金') {
          historyReads++;
          await historyGate.future;
          return http.Response(
            '[{"id":9001,"title":"合成預金","amount":7654321,"created_at":"2001-01-01T00:00:00Z"}]',
            200,
            headers: headers,
            request: request,
          );
        }
        if (request.url.path.endsWith('/cfo_assets') &&
            request.method == 'POST') {
          balanceWrites++;
          if (balanceGate != null) await balanceGate!.future;
          final payload = jsonDecode(request.body);
          final rows = payload is List ? payload : [payload];
          lastBalanceBatchSize = rows.length;
          if (balanceWrites == failBalanceAt) {
            return http.Response(
              '{"message":"synthetic balance save failure"}',
              500,
              headers: headers,
              request: request,
            );
          }
          persistedBalances.addAll(
            rows.map((row) => Map<String, dynamic>.from(row as Map)),
          );
          return http.Response(
            '',
            201,
            headers: headers,
            request: request,
          );
        }
        if (request.url.path.endsWith('/cfo_daily_closings') &&
            request.method == 'GET') {
          if (staleRead != null && staleReads == 0) {
            staleReads++;
            final gate = staleRead!;
            await gate.future;
            return http.Response(
              '[{"assets_done":false}]',
              200,
              headers: headers,
              request: request,
            );
          }
          if (reflectSuccessfulWrite && serverClosing != null) {
            return http.Response(
              jsonEncode([serverClosing]),
              200,
              headers: headers,
              request: request,
            );
          }
        }
        if (request.url.path.endsWith('/cfo_daily_closings') &&
            request.method == 'GET') {
          if (failClosingRead) {
            return http.Response(
              '{"message":"synthetic read failure"}',
              500,
              headers: headers,
              request: request,
            );
          }
          if (persistedClosing) {
            return http.Response(
              '[{"assets_done":true,"fixed_costs_done":true}]',
              200,
              headers: headers,
              request: request,
            );
          }
        }
        if (provideTask && request.url.path.endsWith('/must_tasks')) {
          return http.Response(
            request.method == 'GET'
                ? '[{"id":"synthetic-task","title":"synthetic review task","deadline":"2026-10-22","is_completed":false}]'
                : '[{"id":"synthetic-task"}]',
            200,
            headers: headers,
            request: request,
          );
        }
        if (provideTodayBalance &&
            request.url.path
                .endsWith('/rpc/asset_management_recent_cfo_assets')) {
          return http.Response(
            '[{"id":1,"title":"現金","amount":1000,"created_at":"2026-10-22T03:00:00Z"}]',
            200,
            headers: headers,
            request: request,
          );
        }
        if (request.url.path.endsWith('/cfo_daily_closings') &&
            request.method == 'GET' &&
            holdRead != null) {
          final gate = holdRead!;
          await gate.future;
          return http.Response(
            '[{"assets_done":true,"fixed_costs_done":true}]',
            200,
            headers: headers,
            request: request,
          );
        }
        if (request.url.path.endsWith('/cfo_daily_closings') &&
            request.method == 'POST') {
          lastClosingWrite = jsonDecode(request.body) as Map<String, dynamic>;
          await holdWrite?.future;
          if (!failSave) {
            if (reflectSuccessfulWrite) serverClosing = lastClosingWrite;
            return http.Response(
              '',
              201,
              headers: headers,
              request: request,
            );
          }
          return http.Response(
            '{"code":"XX000","message":"simulated save failure"}',
            500,
            headers: headers,
            request: request,
          );
        }
        return http.Response(
          '[]',
          200,
          headers: headers,
          request: request,
        );
      }),
    );
    await Supabase.instance.client.auth.signInWithPassword(
      email: 'probe@example.invalid',
      password: 'synthetic-only',
    );
  });

  for (final switchOwner in [false, true]) {
    testWidgets('history response respects owner switch=$switchOwner',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const MaterialApp(home: AssetManagementPage()));
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final action = find.text('残高履歴').first;
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pump(const Duration(milliseconds: 300));
      expect(historyReads, 1);
      expect(find.text('合成預金の残高履歴'), findsOneWidget);
      if (switchOwner) {
        syntheticUserId = '00000000-0000-4000-8000-000000000002';
        await Supabase.instance.client.auth.signInWithPassword(
          email: 'second@example.invalid',
          password: 'synthetic-only',
        );
        expect(Supabase.instance.client.auth.currentUser!.id, syntheticUserId);
      }
      historyGate.complete();
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        find.text('¥7,654,321'),
        switchOwner ? findsNothing : findsOneWidget,
      );
      expect(
        find.text('2001-01-01 09:00 JST'),
        switchOwner ? findsNothing : findsOneWidget,
      );
      expect(balanceWrites, 0);
      expect(lastBalanceBatchSize, 0);
      expect(relatedWrites, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
    });
  }
}
