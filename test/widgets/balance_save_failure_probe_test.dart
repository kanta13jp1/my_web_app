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
    if (Supabase.instance.client.auth.currentUser == null) {
      await Supabase.instance.client.auth.signInWithPassword(
        email: 'probe@example.invalid',
        password: 'synthetic-only',
      );
    }

    failRelatedWrite = false;
    balanceWrites = 0;
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
                'id': '00000000-0000-4000-8000-000000000001',
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
        if (request.url.path.endsWith('/cfo_assets') &&
            request.method == 'POST') {
          balanceWrites++;
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

  for (final bulk in [false, true]) {
    testWidgets('balance save failure is visible and input retained bulk=$bulk',
        (tester) async {
      failBalanceAt = 1;
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const MaterialApp(home: AssetManagementPage()));
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final fields = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == '今日の残高',
      );
      expect(fields, findsNWidgets(2));
      await tester.ensureVisible(fields.at(0));
      await tester.enterText(fields.at(0), '3000');
      if (bulk) {
        await tester.ensureVisible(fields.at(1));
        await tester.enterText(fields.at(1), '4000');
      }
      final action = bulk ? find.text('全体状況を保存') : find.text('記録').first;
      await tester.ensureVisible(action);
      await tester.tap(action);
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(balanceWrites, 1);
      expect(lastBalanceBatchSize, bulk ? 2 : 1);
      expect(persistedBalances.length, 0);
      expect(tester.widget<TextField>(fields.at(0)).controller!.text, '3000');
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching:
              find.textContaining(RegExp('保存.*(失敗|でき|確認)|記録.*(失敗|でき)|一部.*保存')),
        ),
        findsWidgets,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
    });
  }
  for (final bulk in [false, true]) {
    testWidgets(
        'balance save success sends one request and clears input bulk=$bulk',
        (tester) async {
      failBalanceAt = 0;
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const MaterialApp(home: AssetManagementPage()));
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final fields = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == '今日の残高',
      );
      expect(fields, findsNWidgets(2));
      await tester.ensureVisible(fields.at(0));
      await tester.enterText(fields.at(0), '3000');
      if (bulk) {
        await tester.ensureVisible(fields.at(1));
        await tester.enterText(fields.at(1), '4000');
      }
      final action = bulk ? find.text('全体状況を保存') : find.text('記録').first;
      await tester.ensureVisible(action);
      await tester.tap(action);
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(balanceWrites, 1);
      expect(lastBalanceBatchSize, bulk ? 2 : 1);
      expect(persistedBalances.length, bulk ? 2 : 1);
      expect(tester.widget<TextField>(fields.at(0)).controller!.text, '');
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.textContaining(RegExp('記録しました|一括記録')),
        ),
        findsWidgets,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
    });
  }
  for (final bulk in [false, true]) {
    testWidgets(
        'balance saved but related failure warns against resaving bulk=$bulk',
        (tester) async {
      failBalanceAt = 0;
      failRelatedWrite = true;
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const MaterialApp(home: AssetManagementPage()));
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final fields = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == '今日の残高',
      );
      expect(fields, findsNWidgets(2));
      await tester.ensureVisible(fields.at(bulk ? 0 : 1));
      await tester.enterText(fields.at(bulk ? 0 : 1), '500');
      if (bulk) {
        await tester.ensureVisible(fields.at(1));
        await tester.enterText(fields.at(1), '500');
      }
      final action = bulk ? find.text('全体状況を保存') : find.text('記録').last;
      await tester.ensureVisible(action);
      await tester.tap(action);
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(balanceWrites, 1);
      if (!bulk) {
        expect(persistedBalances.single['title'], '現金');
      }
      expect(lastBalanceBatchSize, bulk ? 2 : 1);
      expect(persistedBalances.length, bulk ? 2 : 1);
      expect(tester.widget<TextField>(fields.at(bulk ? 0 : 1)).controller!.text,
          '500',
      );
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.textContaining(RegExp('保存済み.*再保存せず')),
        ),
        findsWidgets,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
    });
  }
}
