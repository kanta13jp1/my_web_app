import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:my_web_app/services/asset_revolving_credit_config_store.dart';
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

  testWidgets('借金しない宣言違反がある月は上部赤バナーが表示され、停止ToDo作成で使用停止中タグが付く (#4217)', (
    tester,
  ) async {
    final now = DateTime(2026, 7, 10);
    final dateKey = DateFormat('yyyy-MM-dd').format(now);
    final mirrorValue = AssetRevolvingCreditConfigStore.encodeMirrorValue(
      <String, AssetLiabilityRevolvingCreditConfig>{
        'aupay_card': const AssetLiabilityRevolvingCreditConfig(
          monthlyAmount: 0,
          newUsageAmount: 15000,
          creditLimit: 100000,
        ),
      },
    );
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.binding.setSurfaceSize(const Size(1200, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // 1. 違反あり: バナーが表示され、停止ToDo作成で対象口座に使用停止中タグが付く
    await tester.pumpWidget(
      MaterialApp(
        home: AssetManagementPage(
          debugNow: now,
          debugCalendarNow: now,
          debugRevolvingConfigsMirror: mirrorValue,
          debugInitialAssetData: <String, Map<String, double>>{
            dateKey: const <String, double>{
              '三井住友銀行大塚支店': 50000,
              'auPayカード': -100000,
            },
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(const Key('asset_discipline_violation_banner')),
      findsOneWidget,
    );
    final suspendButton = find.byKey(
      const Key('discipline_banner_suspend_todo_aupay_card'),
    );
    expect(suspendButton, findsOneWidget);

    await tester.ensureVisible(suspendButton);
    await tester.tap(suspendButton);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('debt_suspended_tag_aupay_card')),
      findsOneWidget,
    );

    await _unmount(tester);

    // 2. 違反なし: バナーは表示されない
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(
      MaterialApp(
        home: AssetManagementPage(
          debugNow: now,
          debugCalendarNow: now,
          debugInitialAssetData: <String, Map<String, double>>{
            dateKey: const <String, double>{
              '三井住友銀行大塚支店': 200000,
              'auPayカード': 0,
            },
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(const Key('asset_discipline_violation_banner')),
      findsNothing,
    );

    await _unmount(tester);
  });
}
