import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:my_web_app/models/asset_calendar_reflection.dart';
import 'package:my_web_app/services/asset_spending_attention_calendar.dart';
import 'package:my_web_app/widgets/asset_attention_day_label.dart';
import 'package:my_web_app/widgets/asset_reflection_day_badge.dart';
import 'package:my_web_app/widgets/asset_unreconciled_expense_badge.dart';
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
  testWidgets('narrow badge remains visible with enlarged text',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Center(
            child: SizedBox(
              width: 40,
              height: 24,
              child: AssetUnreconciledExpenseBadge(),
            ),
          ),
        ),
      ),
    );
    expect(find.text('不明'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('unknown, attention, and reflection marks coexist in narrow cell',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 40,
            height: 84,
            child: Column(
              children: [
                const Text('20', style: TextStyle(fontSize: 11)),
                const Text('1,000', style: TextStyle(fontSize: 9)),
                const AssetUnreconciledExpenseBadge(),
                AssetAttentionDayLabel(
                  day: AssetSpendingAttentionCalendar.forDate(
                      DateTime(2026, 6, 20),),
                ),
                const Expanded(
                  child: AssetReflectionDayBadge(
                    kinds: {
                      AssetReflectionKind.dining,
                      AssetReflectionKind.drinkingOut,
                      AssetReflectionKind.alcoholPurchase,
                      AssetReflectionKind.reading,
                    },
                  ),
                ),
                const SizedBox(height: 5),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.text('不明'), findsOneWidget);
    expect(find.text('注意'), findsOneWidget);
    expect(find.textContaining('外食'), findsOneWidget);
    expect(tester.getSize(find.byType(AssetReflectionDayBadge)).height,
        greaterThan(0),);
    expect(tester.takeException(), isNull);
  });
  for (final width in [1200.0, 390.0]) {
    testWidgets('calendar unknown reference and source explanation at $width',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await tester.binding.setSurfaceSize(Size(width, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: AssetManagementPage(
            debugNow: DateTime(2026, 6, 20),
            debugCalendarNow: DateTime(2026, 6, 20),
            debugInitialAssetData: const {
              '2026-06-20': {'Synthetic bank': 10000},
            },
            debugInitialRecentFlows: const [
              {
                'description': '使途不明金（残高差分から自動記録）',
                'amount': 700,
                'action_type': 'expense',
                'occurred_at': '2026-06-20T12:00:00',
              },
              {
                'description': '通常の購入',
                'amount': 300,
                'action_type': 'expense',
                'occurred_at': '2026-06-20T12:00:00',
              },
            ],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      final badge = find.byKey(
        const Key('asset_calendar_unreconciled_2026_6_20'),
      );
      await tester.ensureVisible(badge);
      await tester.pump();
      expect(badge, findsOneWidget);
      final day = find.byKey(const Key('asset_calendar_day_20'));
      await tester.ensureVisible(day);
      await tester.pump();
      await tester.tap(day);
      await tester.pump();
      expect(
        find.byKey(const Key('asset_calendar_unreconciled_details')),
        findsOneWidget,
      );
      expect(find.textContaining('日別支出に含まれる参考内訳'), findsOneWidget);
      expect(find.textContaining('消費を確認した記録ではありません'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }
}
