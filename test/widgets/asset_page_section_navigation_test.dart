import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
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

  testWidgets('search reaches month records and hides signed-out payroll target',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: AssetManagementPage(
          debugNow: DateTime(2026, 6, 20),
          debugInitialAssetData: const {
            '2026-06-20': {'Synthetic bank': 1000},
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byTooltip('カード・項目を検索して移動'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    final search = find.byType(TextField).last;
    await tester.enterText(search, '給与控除');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('給与明細・税金・社会保険料の控除'), findsNothing);
    await tester.enterText(search, '月末記録');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('月末の残高記録'), findsOneWidget);
    await tester.ensureVisible(find.text('月末の残高記録'));
    await tester.pump();
    debugPrint(
      'SEARCH_DIAGNOSTIC sheet=${tester.getRect(find.byType(BottomSheet))} '
      'target=${tester.getRect(find.text('月末の残高記録'))} '
      'hit=${find.text('月末の残高記録').hitTestable().evaluate().length}',
    );
    await tester.tap(find.text('月末の残高記録'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(BottomSheet), findsNothing);
    final scroller = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    expect(scroller.position.pixels, greaterThan(0));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
