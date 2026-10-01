import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:my_web_app/services/asset_recurring_fixed_cost_store.dart';
import 'package:my_web_app/services/asset_liability_monthly_state_store.dart';
import 'package:my_web_app/services/asset_recurring_tombstone_sync_service.dart';
import 'package:my_web_app/services/asset_salary_reset_marker_store.dart';
import 'package:my_web_app/services/asset_sync_dirty_keys_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: 'http://127.0.0.1:9999',
      publishableKey: 'test-publishable-key',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
    );
  });
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AssetSyncDirtyKeysStore.resetWriteLockForTest();
    AssetRecurringTombstoneSyncService.resetSharedForTest();
  });

  testWidgets(
      'pending salary does not label retained paid state as current cashflow',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      AssetSalaryResetMarkerStore.prefsKey: '2026-08',
    });
    const store = AssetLiabilityMonthlyStateStore();
    await store.saveMonth(
      month: DateTime(2026, 8),
      state: const AssetLiabilityMonthlyState(
        paidAccountNames: {'rent'},
        actualPaymentAmounts: {'rent': 63000},
      ),
    );
    await tester.binding.setSurfaceSize(const Size(1200, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: AssetManagementPage(
          debugNow: DateTime(2026, 10, 2),
          debugInitialAssetData: const {
            '2026-10-02': {'現金': 61505, '家賃': -63000}
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('給料の入金を確認できません'), findsOneWidget);
    expect(
      find.byKey(const Key('asset_cashflow_statement_current')),
      findsNothing,
    );
    expect(await const AssetSalaryResetMarkerStore().load(), '2026-08');
    expect(
      (await store.loadMonth(DateTime(2026, 8))).paidAccountNames,
      contains('rent'),
    );
    expect(
      (await store.loadMonth(DateTime(2026, 8))).actualPaymentAmounts['rent'],
      63000,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  for (final dirty in [false, true]) {
    testWidgets(
        'Claude remote billing replaces stale clean cache, dirty=$dirty',
        (tester) async {
      const id = 'fc_1781980533253000';
      const stale = AssetRecurringFixedCost(
        id: id,
        name: 'Claude Pro',
        amount: 3000,
        paymentDay: 26,
        sourceAccountId: 'aupay',
        category: AssetRecurringFixedCostCategory.subscription,
      );
      const current = AssetRecurringFixedCost(
        id: id,
        name: 'Claude',
        amount: 3574,
        paymentDay: 3,
        sourceAccountId: 'custom_ab350028',
        category: AssetRecurringFixedCostCategory.subscription,
      );
      SharedPreferences.setMockInitialValues(<String, Object>{
        AssetRecurringFixedCostStore.prefsKey:
            jsonEncode(AssetRecurringFixedCostStore.encodeMirrorValue([stale])),
        if (dirty)
          AssetSyncDirtyKeysStore.prefsKey: jsonEncode({
            'recurring_fixed_costs': [id],
          }),
      });
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: AssetManagementPage(
            debugNow: DateTime(2026, 10, 1),
            debugMirrorReadsAuthoritative: false,
            debugRecurringFixedCostsMirror:
                AssetRecurringFixedCostStore.encodeMirrorValue([current]),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      final loaded = (await const AssetRecurringFixedCostStore().load()).single;
      expect(loaded.amount, dirty ? 3000 : 3574);
      expect(loaded.paymentDay, dirty ? 26 : 3);
      expect(loaded.sourceAccountId, dirty ? 'aupay' : 'custom_ab350028');
      expect(
        await const AssetSalaryResetMarkerStore().load(),
        isNull,
        reason: 'opening a page must not acknowledge an unconfirmed salary',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }
}
