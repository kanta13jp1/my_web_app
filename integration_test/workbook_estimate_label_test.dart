import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:my_web_app/services/asset_liability_monthly_state_store.dart';
import 'package:my_web_app/services/asset_liability_repository.dart';
import 'package:my_web_app/services/asset_recurring_tombstone_sync_service.dart';
import 'package:my_web_app/services/asset_sync_dirty_keys_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _ReadOnlyFixtureRepository extends SharedPreferencesAssetLiabilityRepository {
  int saveCalls = 0;
  @override
  Future<AssetLiabilityMonthlyState> loadMonth(DateTime month) async =>
      const AssetLiabilityMonthlyState();
  @override
  Future<void> saveMonth({required DateTime month, required AssetLiabilityMonthlyState state,}) async {
    saveCalls += 1;
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const mobile = bool.fromEnvironment('LABEL_MOBILE');
  const viewport = mobile ? Size(390, 844) : Size(1440, 1000);
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: 'http://127.0.0.1:9999',
      publishableKey: 'synthetic-fixture-only',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
    );
  });
  testWidgets('pending billing shows principal and monthly interest as estimates without save', (tester) async {
    await tester.binding.setSurfaceSize(viewport);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AssetSyncDirtyKeysStore.resetWriteLockForTest();
    AssetRecurringTombstoneSyncService.resetSharedForTest();
    final repository = _ReadOnlyFixtureRepository();
    final now = DateTime(2026, 9, 1);
    await tester.pumpWidget(MaterialApp(home: AssetManagementPage(
      debugNow: now,
      debugCalendarNow: now,
      assetLiabilityRepository: repository,
      debugInitialAssetData: const <String, Map<String, double>>{
        '2026-09-01': <String, double>{'財布(現金)': 1000, '三井住友銀行': 500000},
      },
    ),),);
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    final row = find.textContaining('元金返済の概算').first;
    expect(row, findsOneWidget);
    expect(tester.widget<Text>(row).data, contains('月利息の概算'));
    await Scrollable.ensureVisible(tester.element(row), alignment: 0.5);
    for (var frame = 0; frame < 3; frame++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    final rect = tester.getRect(row);
    expect(rect.overlaps(Offset.zero & viewport), isTrue);
    expect(repository.saveCalls, 0);
    expect(tester.takeException(), isNull);
    binding.reportData = <String, dynamic>{
      'width': viewport.width,
      'height': viewport.height,
      'saveCalls': repository.saveCalls,
      'visibleRow': tester.widget<Text>(row).data,
      'rowRect': rect.toString(),
      'productBase': '4e58530b76dd8b094833d1a90126b99661ffbae5',
    };
    await binding.takeScreenshot('${mobile ? 'mobile' : 'desktop'}-pending-estimate-labels', <String, Object?>{
      'width': viewport.width, 'height': viewport.height, 'saveCalls': repository.saveCalls,
    });
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });
}
