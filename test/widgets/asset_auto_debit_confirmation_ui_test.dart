import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:my_web_app/services/asset_liability_monthly_state_store.dart';
import 'package:my_web_app/services/asset_recurring_fixed_cost_store.dart';
import 'package:my_web_app/services/asset_recurring_tombstone_sync_service.dart';
import 'package:my_web_app/services/asset_revolving_credit_config_store.dart';
import 'package:my_web_app/services/asset_salary_reset_marker_store.dart';
import 'package:my_web_app/services/asset_sync_dirty_keys_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

AssetRecurringFixedCost _cost(
  String id,
  String source, {
  double amount = 3000,
}) {
  return AssetRecurringFixedCost(
    id: id,
    name: id,
    amount: amount,
    paymentDay: 2,
    sourceAccountId: source,
  );
}

Future<void> _mount(
  WidgetTester tester,
  List<AssetRecurringFixedCost> costs, {
  double bank = 100000,
  double? card,
  double? limit,
}) async {
  SharedPreferences.setMockInitialValues({
    AssetSalaryResetMarkerStore.prefsKey: '2026-09',
    AssetRecurringFixedCostStore.prefsKey:
        jsonEncode(AssetRecurringFixedCostStore.encodeMirrorValue(costs)),
    AssetRevolvingCreditConfigStore.prefsKey: jsonEncode(
      AssetRevolvingCreditConfigStore.encodeMirrorValue({
        if (limit != null)
          'aupay_card': AssetLiabilityRevolvingCreditConfig(
            monthlyAmount: 1000,
            creditLimit: limit,
          ),
      }),
    ),
  });
  await tester.binding.setSurfaceSize(const Size(1200, 3200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: AssetManagementPage(
        debugNow: DateTime(2026, 10, 7),
        debugCalendarNow: DateTime(2026, 10, 7),
        debugInitialAssetData: {
          '2026-10-07': {
            '三井住友銀行大塚支店': bank,
            if (card != null) 'auPayカード': card,
          },
        },
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 5));
}

Finder _bulkButton() => find.widgetWithText(
      OutlinedButton,
      '残高・利用枠を確認できる2件をまとめて引落済み',
    );

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
    AssetSyncDirtyKeysStore.resetWriteLockForTest();
    AssetRecurringTombstoneSyncService.resetSharedForTest();
  });
  testWidgets('bank warning renders bank debit explanation', (tester) async {
    await _mount(
      tester,
      [_cost('bank_warning', 'smbc_otsuka_branch')],
      bank: 100,
    );
    expect(find.textContaining('引落が失敗している可能性'), findsWidgets);
    expect(find.textContaining('振替元カードの利用枠見込み'), findsNothing);
    await _dispose(tester);
  });

  testWidgets('card warning renders credit limit, never bank failure',
      (tester) async {
    await _mount(
      tester,
      [_cost('card_warning', 'aupay_card')],
      card: -98000,
      limit: 95000,
    );
    expect(find.textContaining('振替元カードの利用枠見込み'), findsWidgets);
    expect(find.textContaining('利用限度額を超過しています'), findsWidgets);
    expect(find.textContaining('引落が失敗している可能性'), findsNothing);
    await _dispose(tester);
  });

  testWidgets('unknown rows cannot raise eligible count above threshold',
      (tester) async {
    await _mount(
      tester,
      [
        _cost('eligible_bank', 'smbc_otsuka_branch'),
        _cost('unknown_card', 'aupay_card'),
        _cost('unknown_balance', 'missing_source'),
      ],
      card: -10000,
    );
    expect(_bulkButton(), findsNothing);
    expect(find.textContaining('件をまとめて引落済み'), findsNothing);
    expect(find.textContaining('振替元カードの利用枠見込み'), findsNothing);
    await _dispose(tester);
  });

  testWidgets(
      'bulk count, confirmation list and saved targets exclude unknowns',
      (tester) async {
    await _mount(
      tester,
      [
        _cost('eligible_one', 'smbc_otsuka_branch'),
        _cost('eligible_two', 'smbc_otsuka_branch'),
        _cost('unknown_card', 'aupay_card'),
        _cost('unknown_balance', 'missing_source'),
      ],
      card: -10000,
    );
    expect(_bulkButton(), findsOneWidget);
    await tester.ensureVisible(_bulkButton());
    await tester.tap(_bulkButton());
    await tester.pump(const Duration(milliseconds: 300));
    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    expect(
      find.descendant(
        of: dialog,
        matching: find.textContaining('eligible_one'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: dialog,
        matching: find.textContaining('unknown_card'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: dialog,
        matching: find.textContaining('unknown_balance'),
      ),
      findsNothing,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'まとめて引落済み'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    final state = await const AssetLiabilityMonthlyStateStore()
        .loadMonth(DateTime(2026, 9));
    expect(
      state.paidAccountNames,
      unorderedEquals(['custom_eligible_one', 'custom_eligible_two']),
    );
    await _dispose(tester);
  });
}
