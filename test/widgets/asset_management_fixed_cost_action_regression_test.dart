import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:my_web_app/services/asset_management_display_mode_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 2));
}

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
  });

  testWidgets(
    'recurring costs feed the fixed-cost card, closing, and daily summary',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'asset_management_display_mode_v1':
            AssetManagementDisplayMode.standard.storageId,
      });
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: AssetManagementPage(
            debugInitialRecurringFixedCosts: <AssetRecurringFixedCost>[
              AssetRecurringFixedCost(
                id: 'subscription_card_regression',
                name: 'AI・クラウドサブスク',
                amount: 104648,
                paymentDay: 15,
                category: AssetRecurringFixedCostCategory.subscription,
              ),
            ],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('¥104,648'), findsOneWidget);
      expect(
        find.textContaining('定期固定費・サブスク 1件を月額合計へ反映済み'),
        findsOneWidget,
      );

      final autoCheck = find.text('記録状況から自動チェック');
      await tester.ensureVisible(autoCheck);
      await tester.tap(autoCheck);
      await tester.pump(const Duration(milliseconds: 200));
      final fixedCostCheck = tester.widget<CheckboxListTile>(
        find.widgetWithText(
          CheckboxListTile,
          '③ 今月の固定費をすべて記録して把握',
        ),
      );
      expect(fixedCostCheck.value, isTrue);

      String? clipboardText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardText =
                (call.arguments as Map<Object?, Object?>)['text']?.toString();
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

      final copySummary = find.text('提出用サマリーをコピー');
      await tester.ensureVisible(copySummary);
      await tester.tap(copySummary);
      await tester.pump(const Duration(milliseconds: 200));

      expect(clipboardText, contains('- 月額合計: ¥104,648'));
      expect(
        clipboardText,
        contains('AI・クラウドサブスク: ¥104,648'),
      );

      await _unmount(tester);
    },
  );

  testWidgets(
    'fallback payslip does not hide the current payslip action',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'asset_management_display_mode_v1':
            AssetManagementDisplayMode.minimum.storageId,
      });
      final now = DateTime.now();
      final dateKey = DateFormat('yyyy-MM-dd').format(now);
      final fallbackPayDate = DateFormat(
        'yyyy-MM-dd',
      ).format(now.subtract(const Duration(days: 60)));
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: AssetManagementPage(
            debugInitialAssetData: <String, Map<String, double>>{
              dateKey: const <String, double>{'財布(現金)': 12012},
            },
            debugInitialPayslipRows: <Map<String, dynamic>>[
              <String, dynamic>{
                'pay_date': fallbackPayDate,
                'net_amount': 300000,
                'company_name': '前月給与',
              },
            ],
            debugInitialRecurringFixedCosts: const <AssetRecurringFixedCost>[
              AssetRecurringFixedCost(
                id: 'rent',
                name: '家賃',
                amount: 63000,
                paymentDay: 27,
              ),
            ],
            debugInitialDisposableBalanceResult: const <String, dynamic>{
              'required_actions': <Map<String, dynamic>>[
                <String, dynamic>{
                  'action_key': 'add_recurring_expenses',
                  'title': 'stale fixed-cost action',
                },
                <String, dynamic>{
                  'action_key': 'cancel_duplicate_music',
                  'title': 'music saving',
                  'amount_impact': 1080,
                },
              ],
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('今月の給与明細が未登録です'), findsOneWidget);
      expect(find.text('固定費が未登録です'), findsNothing);
      expect(find.text('音楽サブスクが重複しています'), findsOneWidget);
      expect(
        find.text('必要なアクションはありません。今の支出ペースを維持しましょう。'),
        findsNothing,
      );

      await _unmount(tester);
    },
  );
}
