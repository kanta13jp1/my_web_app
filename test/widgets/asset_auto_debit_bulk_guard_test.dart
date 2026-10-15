import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:my_web_app/services/asset_liability_monthly_state_store.dart';
import 'package:my_web_app/services/asset_salary_reset_marker_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> pumpPage(
  WidgetTester tester,
  List<AssetRecurringFixedCost> costs,
) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    AssetSalaryResetMarkerStore.prefsKey: '2026-05',
  });
  await tester.binding.setSurfaceSize(const Size(1200, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: AssetManagementPage(
        debugNow: DateTime(2026, 6, 20),
        debugInitialAssetData: const {
          '2026-06-20': {'現金': 100000, '合成カード': -10000},
        },
        debugInitialRecurringFixedCosts: costs,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

const knownA = AssetRecurringFixedCost(
  id: 'synthetic_known_a',
  name: '確認対象A',
  amount: 1000,
  paymentDay: 10,
  category: AssetRecurringFixedCostCategory.utility,
  sourceAccountId: '現金',
);
const knownB = AssetRecurringFixedCost(
  id: 'synthetic_known_b',
  name: '確認対象B',
  amount: 2000,
  paymentDay: 11,
  category: AssetRecurringFixedCostCategory.utility,
  sourceAccountId: '現金',
);
const unknownA = AssetRecurringFixedCost(
  id: 'synthetic_unknown_a',
  name: '残高未確認A',
  amount: 1000,
  paymentDay: 12,
  category: AssetRecurringFixedCostCategory.utility,
  sourceAccountId: '合成カード',
);
const unknownB = AssetRecurringFixedCost(
  id: 'synthetic_unknown_b',
  name: '残高未確認B',
  amount: 2000,
  paymentDay: 13,
  category: AssetRecurringFixedCostCategory.utility,
  sourceAccountId: '合成カード',
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

  testWidgets('unknown credit limits remain individual confirmations',
      (tester) async {
    await pumpPage(tester, const [unknownA, unknownB]);
    // Boot restoration spans several asynchronous stores. Wait for the card,
    // without waiting for unrelated persistent page animations to settle.
    for (var attempt = 0; attempt < 20; attempt++) {
      if (find.textContaining('引落の確認待ち').evaluate().isNotEmpty) break;
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(
      find.text('引落の確認待ち (2件)'),
      findsOneWidget,
      reason: find
          .byType(Text)
          .evaluate()
          .map((e) => (e.widget as Text).data)
          .join(' / '),
    );
    expect(find.textContaining('件をまとめて引落済み'), findsNothing);
    expect(find.text('引落済み'), findsNWidgets(2));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('bulk count and confirmation exclude unresolved source rows',
      (tester) async {
    await pumpPage(tester, const [knownA, knownB, unknownA]);
    final bulk = find.text('警告のない2件をまとめて引落済み');
    expect(bulk, findsOneWidget);
    await tester.ensureVisible(bulk);
    await tester.tap(bulk);
    await tester.pump(const Duration(milliseconds: 400));
    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    expect(
      find.descendant(of: dialog, matching: find.textContaining('確認対象A')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.textContaining('確認対象B')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.textContaining('残高未確認A')),
      findsNothing,
    );
    await tester.tap(find.widgetWithText(TextButton, 'キャンセル'));
    await tester.pump(const Duration(milliseconds: 400));
    final saved = await const AssetLiabilityMonthlyStateStore()
        .loadMonth(DateTime(2026, 5));
    expect(saved.paidAccountNames, isEmpty);
    expect(find.text('引落の確認待ち (3件)'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
