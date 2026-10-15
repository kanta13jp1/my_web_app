import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:my_web_app/services/asset_management_display_mode_store.dart';
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
    for (final override in [
      AssetManagementSectionVisibilityOverride.hidden,
      AssetManagementSectionVisibilityOverride.pinned,
    ]) {
      testWidgets('savings $override setting and guest search at width $width',
          (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            home: AssetManagementPage(debugNow: DateTime(2026, 10, 15)),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.ensureVisible(find.text('カスタマイズ'));
        await tester.tap(find.text('カスタマイズ'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        final dropdown =
            find.byKey(const Key('asset_section_override_savingsPlan'));
        await tester.ensureVisible(dropdown);
        await tester.tap(dropdown);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        await tester.tap(find.text(override.label).last);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(
          (await const AssetManagementDisplayModeStore()
              .loadOverrides())[AssetManagementSectionId.savingsPlan],
          override,
        );
        await tester.tap(find.text('閉じる'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        await tester
            .tap(find.byKey(const Key('asset_section_search_appbar_button')));
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
        expect(find.text('貯蓄目標と生活費の計画'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });
    }
  }
}
