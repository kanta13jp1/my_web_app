import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mockito/mockito.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:my_web_app/services/asset_management_display_mode_store.dart';
import 'package:my_web_app/services/asset_recurring_tombstone_sync_service.dart';
import 'package:my_web_app/services/asset_sync_dirty_keys_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main_test.mocks.dart';

void main() {
  const owner = User(
    id: 'synthetic-owner',
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: '2026-01-01',
  );
  late SupabaseClient transport;
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://127.0.0.1:9999',
      publishableKey: 'test-publishable-key',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        final rows =
            request.url.path.endsWith('/asset_management_recent_cfo_assets') ||
                    (request.method == 'GET' &&
                        request.url.path.endsWith('/cfo_assets'))
                ? [
                    {
                      'id': 1,
                      'user_id': owner.id,
                      'title': '現金',
                      'amount': 12345,
                      'created_at': '2026-10-15T09:00:00Z',
                    },
                  ]
                : [];
        return http.Response(
          jsonEncode(rows),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    transport = Supabase.instance.client;
  });
  tearDownAll(() async {
    Supabase.instance.client = transport;
    await Supabase.instance.dispose();
  });

  for (final width in [1200.0, 390.0]) {
    testWidgets('partial asset-only data preserves settings at $width',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'debt_lockdown_enabled_v1': true,
        'konbini_udon_challenge_enabled_v1': true,
      });
      AssetSyncDirtyKeysStore.resetWriteLockForTest();
      AssetRecurringTombstoneSyncService.resetSharedForTest();
      final client = MockSupabaseClient();
      final auth = MockGoTrueClient();
      final session = MockSession();
      when(client.auth).thenReturn(auth);
      when(auth.currentUser).thenReturn(owner);
      when(auth.currentSession).thenReturn(session);
      when(auth.getUser(any)).thenAnswer(
        (_) async => UserResponse.fromJson(owner.toJson()),
      );
      when(auth.onAuthStateChange).thenAnswer((_) => const Stream.empty());
      when(session.user).thenReturn(owner);
      when(session.accessToken).thenReturn('synthetic-access-token');
      when(client.from(any)).thenAnswer(
        (invocation) =>
            transport.from(invocation.positionalArguments.first as String),
      );
      when(client.rpc(any, params: anyNamed('params'))).thenAnswer(
        (invocation) => transport.rpc(
          invocation.positionalArguments.first as String,
          params: invocation.namedArguments[#params] as Map<String, dynamic>?,
        ),
      );
      when(client.functions).thenReturn(transport.functions);
      when(client.storage).thenReturn(transport.storage);
      Supabase.instance.client = client;
      addTearDown(() => Supabase.instance.client = transport);
      const display = AssetManagementDisplayModeStore();
      await display.save(AssetManagementDisplayMode.full);
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: AssetManagementPage(
            debugNow: DateTime(2026, 10, 15),
            debugInitialAssetData: const {
              '2026-10-15': {'現金': 12345},
            },
          ),
        ),
      );
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('debt_lockdown_enabled_v1'), isTrue);
      expect(prefs.getBool('konbini_udon_challenge_enabled_v1'), isTrue);
      expect(find.text('登録済み負債の合計は0円です。未登録の負債がないか確認してください。'), findsOneWidget);
      expect(find.text('完済までの収監モード'), findsNothing);
      expect(find.text('うどん縛り — 完済までの獄中食'), findsNothing);
      final legacy = find.byKey(const Key('legacy-meal-rule-history'));
      expect(legacy, findsOneWidget);
      await tester.ensureVisible(legacy);
      await tester.tap(find.text('以前の食費ルール（任意）'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      final pause = find.text('以前の食費ルールを中断');
      await tester.ensureVisible(pause);
      await tester.tap(pause);
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(prefs.getBool('konbini_udon_challenge_enabled_v1'), isFalse);
      expect(prefs.getBool('debt_lockdown_enabled_v1'), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }
}
