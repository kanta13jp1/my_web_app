import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:my_web_app/widgets/debt_progress_share_dialog.dart';
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

  testWidgets('visible next cycle pointer updates range without share dialog',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: AssetManagementPage(
          debugNow: DateTime(2026, 6, 20),
          debugInitialAssetData: const {
            '2026-06-20': {'Synthetic bank': 1000, 'アコムローン': -10000},
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    final next = find.byKey(const Key('asset_calendar_next_month'));
    await tester.ensureVisible(next);
    await tester.pump();
    expect(next.hitTestable(), findsOneWidget);
    expect(find.text('2026/5/25〜6/24'), findsOneWidget);
    await tester.tapAt(tester.getCenter(next));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('2026/6/25〜7/24'), findsOneWidget);
    expect(find.byType(DebtProgressShareDialog), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
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
    await tester.tap(find.text('月末の残高記録'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(BottomSheet), findsNothing);
    final pageScrollbar = tester.widget<Scrollbar>(
      find.byKey(const Key('asset_page_scrollbar')),
    );
    expect(pageScrollbar.controller!.offset, greaterThan(0));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
