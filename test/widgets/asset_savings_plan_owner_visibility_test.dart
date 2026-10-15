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
        final rows = request.method == 'GET' &&
                request.url.path.endsWith('/cfo_assets')
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

  testWidgets('owner can hide, restore, find and jump to the savings card',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    AssetSyncDirtyKeysStore.resetWriteLockForTest();
    AssetRecurringTombstoneSyncService.resetSharedForTest();
    final client = MockSupabaseClient();
    final auth = MockGoTrueClient();
    final session = MockSession();
    when(client.auth).thenReturn(auth);
    when(auth.currentUser).thenReturn(owner);
    when(auth.currentSession).thenReturn(session);
    when(auth.onAuthStateChange).thenAnswer((_) => const Stream.empty());
    when(session.user).thenReturn(owner);
    when(session.accessToken).thenReturn('synthetic-access-token');
    when(client.from(any)).thenAnswer(
      (invocation) => transport.from(invocation.positionalArguments.first as String),
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
    await display.saveOverride(
      AssetManagementSectionId.savingsPlan,
      AssetManagementSectionVisibilityOverride.hidden,
    );
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: AssetManagementPage(
          debugNow: DateTime(2026, 10, 15),
          debugInitialAssetData: const {'2026-10-15': {'現金': 12345}},
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    final card = find.byKey(const ValueKey('savings-life-plan:synthetic-owner'));
    expect(card, findsNothing);
    Future<Finder> openSearch() async {
      await tester.tap(find.byKey(const Key('asset_section_search_appbar_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.enterText(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(TextField),
        ),
        '貯蓄目標',
      );
      await tester.pump();
      return find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('貯蓄目標と生活費の計画'),
      );
    }
    expect(await openSearch(), findsNothing);
    Navigator.of(tester.element(find.byType(BottomSheet))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.ensureVisible(find.text('カスタマイズ'));
    await tester.tap(find.text('カスタマイズ'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    final dropdown = find.byKey(const Key('asset_section_override_savingsPlan'));
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('常に表示').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('閉じる'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(card, findsOneWidget);
    final outer = find.byType(Scrollable).first;
    await tester.drag(outer, const Offset(0, -700));
    await tester.pump(const Duration(milliseconds: 350));
    final position = tester.state<ScrollableState>(outer).position;
    final beforeJump = position.pixels;
    expect(beforeJump, greaterThan(0));
    final destination = await openSearch();
    expect(destination, findsOneWidget);
    await tester.tap(destination);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.byType(BottomSheet), findsNothing);
    expect((position.pixels - beforeJump).abs(), greaterThan(1));
    expect(tester.getTopLeft(card).dy, inInclusiveRange(0, 899));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
