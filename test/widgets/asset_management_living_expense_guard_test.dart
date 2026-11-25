import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
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

  testWidgets('使用可能額がマイナスのときは生活費優先ガードダイアログが挟まり、正のときはブロックされない (#4219)', (
    tester,
  ) async {
    final now = DateTime.now();
    final dateKey = DateFormat('yyyy-MM-dd').format(now);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.binding.setSurfaceSize(const Size(1200, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // 1. 使用可能額が負の場合: ガードダイアログが表示される
    await tester.pumpWidget(
      MaterialApp(
        home: AssetManagementPage(
          debugCalendarNow: DateTime(2026, 7, 10),
          debugInitialAssetData: <String, Map<String, double>>{
            dateKey: const <String, double>{'三井住友銀行大塚支店': 5000, 'モビット': -45000},
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    final negativeCheckbox = find.byKey(const Key('debt_paid_checkbox_mobit'));
    await tester.ensureVisible(negativeCheckbox);
    await tester.tap(negativeCheckbox);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('asset_living_expense_guard_dialog')),
      findsOneWidget,
    );

    // キャンセル時は支払済みにならない
    await tester.tap(find.byKey(const Key('living_guard_cancel_button')));
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(negativeCheckbox).value, isFalse);

    // 再度タップして「それでも実行」で支払済みになる
    await tester.tap(negativeCheckbox);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('asset_living_expense_guard_dialog')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('living_guard_force_execute_button')),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(negativeCheckbox).value, isTrue);

    await _unmount(tester);

    // 2. 使用可能額が正の場合: ブロックされない
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(
      MaterialApp(
        home: AssetManagementPage(
          debugCalendarNow: DateTime(2026, 7, 10),
          debugInitialAssetData: <String, Map<String, double>>{
            dateKey: const <String, double>{
              '三井住友銀行大塚支店': 200000,
              'モビット': -45000,
            },
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    final positiveCheckbox = find.byKey(const Key('debt_paid_checkbox_mobit'));
    await tester.ensureVisible(positiveCheckbox);
    await tester.tap(positiveCheckbox);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('asset_living_expense_guard_dialog')),
      findsNothing,
    );
    expect(tester.widget<Checkbox>(positiveCheckbox).value, isTrue);

    await _unmount(tester);
  });
}
