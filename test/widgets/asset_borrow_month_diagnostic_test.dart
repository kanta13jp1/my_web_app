import 'dart:async';

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


// Synthetic diagnostic: select the fixture month through the visible UI.
void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: 'http://127.0.0.1:9999',
      publishableKey: 'test-publishable-key',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false, detectSessionInUri: false),
    );
  });
  testWidgets('borrowed history selects its fixture month without saving', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _RecordingRepository();
    await _pump(tester, repository);
    final flowCard = find.ancestor(
      of: find.text('④収支の記録'), matching: find.byType(Card),
    ).first;
    final previous = find.descendant(of: flowCard, matching: find.byTooltip('前月'));
    expect(previous, findsOneWidget);
    final today = DateTime.now();
    final shifts = (today.year - _date.year) * 12 + today.month - _date.month;
    expect(shifts, inInclusiveRange(0, 48));
    for (var i = 0; i < shifts; i++) {
      await tester.ensureVisible(previous);
      await tester.tap(previous);
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.descendant(of: flowCard, matching: find.text('2026/10')), findsWidgets);
    expect(find.text('合成借入受取検査'), findsOneWidget);
    final history = find.ancestor(
      of: find.text('合成借入受取検査'), matching: find.byType(ListTile),
    );
    expect(find.descendant(of: history, matching: find.text('+￥10,000')), findsOneWidget);
    expect(repository.saveCalls, 0);
    expect(tester.takeException(), isNull);
    print('diagnostic: expected month, history and zero saves verified');
    await _unmount(tester);
    await tester.pump(const Duration(seconds: 10));
    expect(tester.takeException(), isNull);
    print('diagnostic: widget disposed and pending timeout elapsed');
  });
}
