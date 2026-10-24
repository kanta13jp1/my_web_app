import 'dart:async';
import 'package:integration_test/integration_test.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:my_web_app/services/asset_liability_monthly_state_store.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';
import 'package:my_web_app/services/asset_liability_repository.dart';
import 'package:my_web_app/services/asset_recurring_tombstone_sync_service.dart';
import 'package:my_web_app/services/asset_sync_dirty_keys_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _date = DateTime(2026, 10, 14);

class _RecordingRepository extends SharedPreferencesAssetLiabilityRepository {
  _RecordingRepository() {
    final defaults = const AssetLiabilityPlanningService().buildWorkbook(
      latestSnapshot: const <String, double>{},
      baseDate: _date,
    );
    current = AssetLiabilityMonthlyState(
      paidAccountNames: defaults.debtMasterRows.map((row) => row.id).toSet(),
    );
  }
  late AssetLiabilityMonthlyState current;
  int saveCalls = 0;
  bool failSave = false;
  Completer<void>? saveGate;
  @override
  Future<AssetLiabilityMonthlyState> loadMonth(DateTime month) async => current;
  @override
  Future<void> saveMonth({
    required DateTime month,
    required AssetLiabilityMonthlyState state,
  }) async {
    saveCalls++;
    final gate = saveGate;
    if (gate != null) await gate.future;
    if (failSave) throw StateError('synthetic storage failure');
    current = state;
  }
}

Future<void> _pump(
  WidgetTester tester,
  _RecordingRepository repository, {
  double bank = 500000,
}) async {
  AssetSyncDirtyKeysStore.resetWriteLockForTest();
  AssetRecurringTombstoneSyncService.resetSharedForTest();
  await tester.pumpWidget(
    MaterialApp(
      home: AssetManagementPage(
        debugNow: _date,
        debugInitialRecentFlows: const <Map<String, dynamic>>[
          <String, dynamic>{
            'id': -10001,
            'action_type': 'borrowing',
            'amount': 10000,
            'description': '合成借入受取検査',
            'occurred_at': '2026-10-14T12:00:00',
          },
        ],
        debugCalendarNow: _date,
        assetLiabilityRepository: repository,
        debugInitialAssetData: <String, Map<String, double>>{
          '2026-10-14': <String, double>{'財布(現金)': 1000, '三井住友銀行': bank},
        },
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 2));
}

// Synthetic fixture only. Never press save/edit/delete or use a real backend.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const mobile = bool.fromEnvironment('TRIAGE_MOBILE');
  const viewport = mobile ? Size(390, 851) : Size(1440, 1000);
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: 'http://127.0.0.1:9999',
      publishableKey: 'test-publishable-key',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
    );
  });
  testWidgets('borrowed receipt selection and history without saving',
      (tester) async {
    await tester.binding.setSurfaceSize(viewport);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _RecordingRepository();
    await _pump(tester, repository);
    final dropdown = find.byKey(const Key('asset_flow_type_dropdown'));
    expect(dropdown, findsOneWidget,);
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('借入受取').last);
    await tester.pump(const Duration(milliseconds: 300));
    expect(
        tester.widget<DropdownButtonFormField<String>>(dropdown).initialValue,
        '借入受取',);
    expect(find.descendant(of: dropdown, matching: find.text('借入受取')),
        findsOneWidget,);
    final title = find.text('合成借入受取検査');
    expect(title, findsOneWidget,);
    final history = find.ancestor(of: title, matching: find.byType(ListTile));
    expect(history, findsOneWidget,);
    expect(find.descendant(of: history, matching: find.textContaining('借入受取')),
        findsOneWidget,);
    expect(find.descendant(of: history, matching: find.text('+￥10,000')),
        findsOneWidget,);
    expect(find.descendant(of: history, matching: find.textContaining('支出')),
        findsNothing,);
    for (final target in [dropdown, history]) {
      await Scrollable.ensureVisible(tester.element(target), alignment: 0.5);
      await tester.pump(const Duration(milliseconds: 500));
      await Scrollable.ensureVisible(tester.element(target), alignment: 0.5);
      await tester.pump();
      expect(target.hitTestable(), findsOneWidget,);
      await binding.takeScreenshot(
        '${mobile ? 'mobile' : 'desktop'}-borrowing-${target == dropdown ? 'selection' : 'history'}',
        <String, Object?>{
          'width': viewport.width,
          'height': viewport.height,
          'devicePixelRatio': mobile ? 2.75 : 1.0,
          'targetHitTestable': true,
        },
      );
    }
    expect(repository.saveCalls, 0);
    expect(repository.current.transferTasks, isEmpty);
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });
}
