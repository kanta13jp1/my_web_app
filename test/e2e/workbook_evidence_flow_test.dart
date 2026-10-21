import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:my_web_app/services/asset_recurring_tombstone_sync_service.dart';
import 'package:my_web_app/services/asset_liability_monthly_state_store.dart';
import 'package:my_web_app/services/asset_revolving_credit_config_store.dart';
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

  for (final scenario in <({double width, double usage})>[
    (width: 1200, usage: 30000),
    (width: 390, usage: 30000),
    (width: 1200, usage: 0),
  ]) {
    testWidgets('unreconciled evidence ${scenario.width}/${scenario.usage}', (
      tester,
    ) async {
      final monthKey = AssetLiabilityMonthlyStateStore.formatSalaryCycleMonthKey(
        DateTime.now(),
      );
      SharedPreferences.setMockInitialValues(<String, Object>{
        AssetLiabilityMonthlyStateStore.actualPaymentPrefsKey: jsonEncode(
          <String, Map<String, double>>{
            monthKey: <String, double>{'famipay_card': 5000},
          },
        ),
        AssetLiabilityMonthlyStateStore.paidPrefsKey: jsonEncode(
          <String, List<String>>{
            monthKey: <String>['famipay_card'],
          },
        ),
      });
      AssetSyncDirtyKeysStore.resetWriteLockForTest();
      AssetRecurringTombstoneSyncService.resetSharedForTest();
      await tester.binding.setSurfaceSize(Size(scenario.width, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final mirror = AssetRevolvingCreditConfigStore.encodeMirrorValue(
        <String, AssetLiabilityRevolvingCreditConfig>{
          'famipay_card': AssetLiabilityRevolvingCreditConfig(
            monthlyAmount: 5000,
            newUsageAmount: scenario.usage,
          ),
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: AssetManagementPage(
            debugRevolvingConfigsMirror: mirror,
            debugInitialAssetData: <String, Map<String, double>>{
              DateFormat('yyyy-MM-dd').format(DateTime.now()):
                  const <String, double>{
                '財布(現金)': 50000,
                'ファミペイ': -100000,
              },
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('借金しない宣言モニター'), findsOneWidget);
      expect(find.textContaining('違反 '), findsNothing);
      expect(find.textContaining('を達成しています'), findsNothing);
      if (scenario.usage > 0) {
        expect(find.textContaining('要確認（未照合）'), findsWidgets);
        expect(find.textContaining('手入力設定額'), findsWidgets);
        expect(find.textContaining('違反の確定ではありません'), findsWidgets);
      } else {
        expect(find.textContaining('前月残高データがないため'), findsWidgets);
        expect(find.textContaining('検出なし（未照合）'), findsWidgets);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
    });
  }
}
