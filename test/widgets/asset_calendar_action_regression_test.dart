import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:my_web_app/widgets/debt_progress_share_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../fixtures/asset_calendar_action_probe.dart' as probe;

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

  testWidgets('probe counter semantics hides during modal and restores cumulative pushes',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);
    await tester.pumpWidget(const probe.ActionProbe());
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.bySemanticsLabel('fixture-popup-pushes:0'), findsOneWidget);
    await tester.tap(find.text('合成：モーダル'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('fixture-popup-pushes:')), findsNothing);
    await tester.tap(find.text('合成モーダルを閉じる'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.bySemanticsLabel('fixture-popup-pushes:1'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
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
          debugCalendarNow: DateTime(2026, 6, 20),
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
    final nextRect = tester.getRect(next);
    final shareRect = tester.getRect(
      find.byKey(const Key('debt_progress_share_appbar_button')),
    );
    expect(nextRect.overlaps(shareRect), isFalse);
    debugPrint('A13_RECT next=$nextRect appbarShare=$shareRect');
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

  testWidgets('next cycle keyboard focus and Enter do not open share dialog',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: AssetManagementPage(
          debugNow: DateTime(2026, 6, 20),
          debugCalendarNow: DateTime(2026, 6, 20),
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
    bool nextIsFocused() =>
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<IconButton>()
            ?.key ==
        const Key('asset_calendar_next_month');
    for (var tabs = 0; tabs < 250 && !nextIsFocused(); tabs++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(nextIsFocused(), isTrue, reason: 'Enter must target next cycle');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('2026/6/25〜7/24'), findsOneWidget);
    expect(find.byType(DebtProgressShareDialog), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
