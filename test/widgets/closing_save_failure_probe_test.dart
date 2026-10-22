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
  Completer<void>? holdRead;
  var delayedReads = 0;
  var provideTodayBalance = false;
  var failClosingRead = false;
  var persistedClosing = false;
  var provideTask = false;
  Map<String, dynamic>? lastClosingWrite;
  setUp(() {
    closingWrites = 0;
    failSave = true;
    holdWrite = null;
    holdRead = null;
    delayedReads = 0;
    provideTodayBalance = false;
    failClosingRead = false;
    persistedClosing = false;
    provideTask = false;
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
          return http.Response(request.method == 'GET'
              ? '[{"id":"synthetic-task","title":"synthetic review task","deadline":"2026-10-22","is_completed":false}]'
              : '[{"id":"synthetic-task"}]', 200, headers: headers, request: request,);
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
          delayedReads++;
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
          closingWrites++;
          lastClosingWrite = jsonDecode(request.body) as Map<String, dynamic>;
          await holdWrite?.future;
          if (!failSave) {
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
    expect(
      closingWrites,
      greaterThan(0),
      reason: 'must exercise the failing write',
    );
    expect(
      tester.widget<CheckboxListTile>(item).value,
      isFalse,
      reason: 'a failed write cannot be presented as completed',
    );
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
    provideTodayBalance = true;
    holdWrite = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: AssetManagementPage(
          debugNow: DateTime(2026, 10, 22),
          debugInitialAssetData: const {
            '2026-10-22': {'現金': 1000},
          },
        ),
      ),
    );
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final action = find.text('記録状況から自動チェック');
    await tester.ensureVisible(action);
    await tester.tap(action);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final assetCheck = find.widgetWithText(CheckboxListTile, '① 全資産額を記録して把握');
    expect(tester.widget<CheckboxListTile>(assetCheck).value, isTrue);
    holdWrite!.complete();
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.widget<CheckboxListTile>(assetCheck).value, isFalse);
    expect(closingWrites, 1);
    expect(find.textContaining('チェックを保存できませんでした'), findsOneWidget);
    expect(find.textContaining('登録口座の本日記録を確認しました。'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets(
      'a pending save prevents a second write and rolls back on failure',
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
  testWidgets('a save completing after midnight cannot mark the new day done',
      (tester) async {
    failSave = false;
    holdWrite = Completer<void>();
    await tester.binding.setSurfaceSize(const Size(1200, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: AssetManagementPage(debugNow: DateTime(2026, 10, 22, 23, 59)),
      ),
    );
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final item = find.widgetWithText(CheckboxListTile, '① 全資産額を記録して把握');
    await tester.ensureVisible(item);
    await tester.tap(item);
    await tester.pump(const Duration(milliseconds: 100));
    expect(closingWrites, 1);
    await tester.pumpWidget(
      MaterialApp(
        home: AssetManagementPage(debugNow: DateTime(2026, 10, 23, 0, 1)),
      ),
    );
    holdRead = Completer<void>();
    holdWrite!.complete();
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(delayedReads, 1);
    final second = find.widgetWithText(CheckboxListTile, '③ 今月の固定費をすべて記録して把握');
    await tester.ensureVisible(second);
    await tester.tap(second);
    await tester.pump(const Duration(milliseconds: 100));
    expect(closingWrites, 1);
    await tester.pumpWidget(
      MaterialApp(
        home: AssetManagementPage(debugNow: DateTime(2026, 10, 24, 0, 1)),
      ),
    );
    final pendingRead = holdRead!;
    holdRead = null;
    pendingRead.complete();
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.widget<CheckboxListTile>(second).value, isFalse);
    expect(tester.widget<CheckboxListTile>(item).value, isFalse);
    expect(find.textContaining('元の状態に戻しました'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets(
      'failed recovery reads block manual and automatic writes until retry succeeds',
      (tester) async {
    failSave = false;
    holdWrite = Completer<void>();
    await tester.binding.setSurfaceSize(const Size(1200, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: AssetManagementPage(
          debugNow: DateTime(2026, 10, 22),
        ),
      ),
    );
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final asset = find.widgetWithText(CheckboxListTile, '① 全資産額を記録して把握');
    final fixed = find.widgetWithText(CheckboxListTile, '③ 今月の固定費をすべて記録して把握');
    await tester.ensureVisible(asset);
    await tester.tap(asset);
    await tester.pump(const Duration(milliseconds: 100));
    expect(closingWrites, 1);
    failClosingRead = true;
    persistedClosing = true;
    await tester.pumpWidget(
      MaterialApp(
        home: AssetManagementPage(
          debugNow: DateTime(2026, 10, 23),
        ),
      ),
    );
    holdWrite!.complete();
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.ensureVisible(asset);
    await tester.tap(asset);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(closingWrites, 1);
    expect(find.textContaining('現在のチェックを取得できませんでした'), findsOneWidget);
    final auto = find.text('記録状況から自動チェック');
    await tester.ensureVisible(auto);
    await tester.tap(auto);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(closingWrites, 1);
    failClosingRead = false;
    holdWrite = null;
    await tester.ensureVisible(asset);
    await tester.tap(asset);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(closingWrites, 2);
    expect(lastClosingWrite?['fixed_costs_done'], isTrue);
    expect(lastClosingWrite?['date'], '2026-10-23');
    expect(tester.widget<CheckboxListTile>(fixed).value, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });

  for (final automatic in [false, true]) {
    testWidgets('newer closing read survives failed save automatic=$automatic', (tester) async {
      provideTask = true;
      provideTodayBalance = true;
      holdWrite = Completer<void>();
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(home: AssetManagementPage(debugNow: DateTime(2026, 10, 22),),),
      );
      for (var i = 0; i < 12; i++) { await tester.pump(const Duration(milliseconds: 100)); }
      final asset = find.widgetWithText(CheckboxListTile, '① 全資産額を記録して把握');
      final fixed = find.widgetWithText(CheckboxListTile, '③ 今月の固定費をすべて記録して把握');
      final action = automatic ? find.text('記録状況から自動チェック') : asset;
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pump(const Duration(milliseconds: 100));
      expect(closingWrites, 1);
      persistedClosing = true;
      final task = find.widgetWithText(CheckboxListTile, 'synthetic review task');
      await tester.ensureVisible(task);
      await tester.tap(task);
      for (var i = 0; i < 12; i++) { await tester.pump(const Duration(milliseconds: 100)); }
      expect(tester.widget<CheckboxListTile>(fixed).value, isTrue);
      holdWrite!.complete();
      for (var i = 0; i < 12; i++) { await tester.pump(const Duration(milliseconds: 100)); }
      expect(tester.widget<CheckboxListTile>(asset).value, isTrue);
      expect(tester.widget<CheckboxListTile>(fixed).value, isTrue);
      expect(closingWrites, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
    });
  }

  testWidgets(
    'logout during a save discards the previous owner completion',
    (tester) async {
      failSave = false;
      holdWrite = Completer<void>();
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const MaterialApp(home: AssetManagementPage()));
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final item = find.widgetWithText(CheckboxListTile, '① 全資産額を記録して把握');
      await tester.ensureVisible(item);
      await tester.tap(item);
      await tester.pump(const Duration(milliseconds: 100));
      expect(closingWrites, 1);
      await tester.runAsync(
        () => Supabase.instance.client.auth.signOut(scope: SignOutScope.local),
      );
      holdWrite!.complete();
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(Supabase.instance.client.auth.currentUser, isNull);
      expect(tester.widget<CheckboxListTile>(item).value, isFalse);
      expect(
        find.textContaining('元の状態に戻しました'),
        findsNothing,
        reason: 'the old owner snapshot must not be restored after logout',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
    },
    timeout: const Timeout(Duration(seconds: 45)),
  );
}
