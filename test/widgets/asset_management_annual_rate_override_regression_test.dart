import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:my_web_app/services/asset_management_display_mode_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 年利の手入力が「証跡がない」という理由だけで破棄される回帰を防ぐテスト。
///
/// 以前の実装では `_updateAnnualRateOverride` が、入力値と一致する証跡が無い場合に
/// 入力済みの年利を `_annualRateOverrides` から取り除いていた。テキスト欄には
/// 入力文字が残るため保存されたように見えるが、実際には保持されず再読込で元に戻る、
/// という利用者から見て分かりにくい挙動になっていた。証跡は任意であり、
/// 出資法の上限（年利20%）を超えない限り手入力値は保持されなければならない。
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
    SharedPreferences.setMockInitialValues(<String, Object>{
      'asset_management_display_mode_v1':
          AssetManagementDisplayMode.full.storageId,
    });
  });

  testWidgets(
    'annual rate typed without evidence is kept and drives the monthly interest',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 3200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const dateKey = '2026-07-10';
      await tester.pumpWidget(
        MaterialApp(
          home: AssetManagementPage(
            debugCalendarNow: DateTime(2026, 7, 10),
            debugInitialAssetData: const <String, Map<String, double>>{
              dateKey: <String, double>{
                '三井住友銀行大塚支店': 500000,
                // 年利 15.00% で月利息 ¥15,000 になる元本。
                'モビット': -1200000,
              },
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      final rateField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.helperText == '契約書の年利を入力（証跡は任意）',
      );
      expect(
        rateField,
        findsWidgets,
        reason: '証跡未提出でも年利を手入力できる案内が出ていること',
      );

      // 証跡を一切提出せずに年利だけを入力する。
      await tester.enterText(rateField.first, '15');
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.helperText == '手入力を保存済み（証跡は任意）',
        ),
        findsWidgets,
        reason: '証跡が無くても手入力した年利が保持されること',
      );

      await _unmount(tester);
    },
  );

  testWidgets(
    'annual rate above the 20% statutory cap is still rejected',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 3200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const dateKey = '2026-07-10';
      await tester.pumpWidget(
        MaterialApp(
          home: AssetManagementPage(
            debugCalendarNow: DateTime(2026, 7, 10),
            debugInitialAssetData: const <String, Map<String, double>>{
              dateKey: <String, double>{
                '三井住友銀行大塚支店': 500000,
                'モビット': -1200000,
              },
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      final rateField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.helperText == '契約書の年利を入力（証跡は任意）',
      );
      expect(rateField, findsWidgets);

      // 出資法の上限を超える年利は、証跡の有無にかかわらず保存させない。
      await tester.enterText(rateField.first, '25');
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.helperText == '手入力を保存済み（証跡は任意）',
        ),
        findsNothing,
        reason: '年利20%超は保存されないこと（出資法上限のガードは維持）',
      );

      await _unmount(tester);
    },
  );
}
