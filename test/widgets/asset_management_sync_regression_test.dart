import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:my_web_app/services/asset_liability_monthly_state_store.dart';
import 'package:my_web_app/services/asset_recurring_fixed_cost_store.dart';
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

  for (final pending in [true, false]) {
    testWidgets(
        'retained paid state is not labeled current while pending=$pending',
        (tester) async {
      final marker = pending ? '2026-08' : '2026-09';
      final stateMonth = DateTime(2026, pending ? 8 : 9);
      SharedPreferences.setMockInitialValues(<String, Object>{
        AssetSalaryResetMarkerStore.prefsKey: marker,
      });
      const store = AssetLiabilityMonthlyStateStore();
      await store.saveMonth(
        month: stateMonth,
        state: AssetLiabilityMonthlyState(
          paidAccountNames: const {'rent'},
          actualPaymentAmounts: const {'rent': 63000},
          incomePlans: [
            AssetLiabilityIncomePlan(
              id: 'synthetic_salary',
              name: '給料',
              date: DateTime(2026, 9, 25),
              amount: 416709,
              destinationAccountId: null,
              destinationAccountName: null,
              received: true,
            ),
          ],
        ),
      );
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: AssetManagementPage(
            debugNow: DateTime(2026, 10, 2),
            debugInitialAssetData: const {
              '2026-10-02': {'現金': 61505, '家賃': -63000},
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.text('給与の口座入金は未確認です'),
        pending ? findsOneWidget : findsNothing,
      );
      expect(
        find.byKey(const Key('asset_cashflow_statement_current')),
        pending ? findsNothing : findsOneWidget,
      );
      expect(await const AssetSalaryResetMarkerStore().load(), marker);
      expect(
        (await store.loadMonth(stateMonth)).paidAccountNames,
        contains('rent'),
      );
      expect(
        (await store.loadMonth(stateMonth)).actualPaymentAmounts['rent'],
        63000,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }

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
