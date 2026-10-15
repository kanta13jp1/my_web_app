import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:my_web_app/services/asset_recurring_tombstone_sync_service.dart';
import 'package:my_web_app/services/asset_sync_dirty_keys_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://127.0.0.1:9999',
      publishableKey: 'test-publishable-key',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
    );
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AssetSyncDirtyKeysStore.resetWriteLockForTest();
    AssetRecurringTombstoneSyncService.resetSharedForTest();
  });
  for (final width in <double>[1200, 390]) {
    testWidgets('saving scope details are reachable at width $width',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        home: AssetManagementPage(debugNow: DateTime(2026, 10, 15)),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const Key('asset_sync_status_chip')));
      await tester.pumpAndSettle();
      expect(find.text('同期ステータス'), findsOneWidget);
      expect(find.textContaining('以下の6領域だけの保存状況です'), findsOneWidget);
      expect(find.textContaining('月次の支払・計画設定：'), findsOneWidget);
      expect(find.textContaining('現在値の照合に未対応'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('閉じる'));
      await tester.pumpAndSettle();
      expect(find.text('同期ステータス'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }
}
