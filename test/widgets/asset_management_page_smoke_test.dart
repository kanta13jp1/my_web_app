import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 資産管理ページの widget スモーク足場 (#3260)。
/// 未ログイン (auth.currentUser == null) では Supabase フェッチ群が
/// 早期 return する性質を利用し、ネットワークなしで UI 契約だけを検証する。
Future<void> _pumpAssetPage(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(home: AssetManagementPage()),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

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

  group('AssetManagementPage smoke', () {
    testWidgets('display mode chips reduce visible sections', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpAssetPage(tester);

      expect(find.byKey(const Key('asset_display_mode_minimum')), findsOne);
      final cardsInFull = tester.widgetList(find.byType(Card)).length;

      await tester.tap(find.byKey(const Key('asset_display_mode_minimum')));
      await tester.pump(const Duration(milliseconds: 100));

      final cardsInMinimum = tester.widgetList(find.byType(Card)).length;
      expect(cardsInMinimum, lessThan(cardsInFull));
      expect(find.textContaining('最重要のみ'), findsWidgets);

      await _unmount(tester);
    });

    testWidgets('calendar month navigation updates the label', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpAssetPage(tester);

      final now = DateTime.now();
      final current = DateFormat('yyyy年M月').format(now);
      final next = DateFormat(
        'yyyy年M月',
      ).format(DateTime(now.year, now.month + 1));
      expect(find.text(current), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const Key('asset_calendar_next_month')),
      );
      await tester.tap(find.byKey(const Key('asset_calendar_next_month')));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text(next), findsOneWidget);
      expect(find.text(current), findsNothing);

      await _unmount(tester);
    });

    testWidgets('tapping a day reveals the prefill action', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpAssetPage(tester);

      expect(
        find.byKey(const Key('asset_calendar_prefill_flow_button')),
        findsNothing,
      );

      await tester.ensureVisible(
        find.byKey(const Key('asset_calendar_day_15')),
      );
      await tester.tap(find.byKey(const Key('asset_calendar_day_15')));
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.byKey(const Key('asset_calendar_prefill_flow_button')),
        findsOneWidget,
      );

      await _unmount(tester);
    });
  });
}
