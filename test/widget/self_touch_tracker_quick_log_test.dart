import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/self_touch_tracker_page.dart';
import 'package:my_web_app/services/abstinence_guard_store.dart';
import 'package:my_web_app/services/self_touch_consent_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('first use blocks PWA quick log until disclosure is accepted', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: SelfTouchTrackerPage(quickLogOnOpen: true)),
    );
    await tester.pumpAndSettle();

    expect(find.text('記録を始める前に'), findsWidgets);
    expect(find.textContaining('医療上の診断や治療ではありません'), findsNWidgets(2));

    final prefs = await SharedPreferences.getInstance();
    final trend = await AbstinenceGuardStore.loadSlipCountsByDate(
      itemId: 'touch_hair',
      days: 1,
      prefs: prefs,
    );
    expect(trend.single.count, 0);
  });

  testWidgets('SelfTouchTrackerPage quick logs after current consent', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await SelfTouchConsentStore.grantConsent(
      version: SelfTouchDisclosure.fallback.version,
      preferences: prefs,
      now: DateTime.utc(2026, 9, 3),
    );

    await tester.pumpWidget(
      const MaterialApp(home: SelfTouchTrackerPage(quickLogOnOpen: true)),
    );

    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    final trend = await AbstinenceGuardStore.loadSlipCountsByDate(
      itemId: 'touch_hair',
      days: 1,
      prefs: prefs,
    );

    expect(trend.single.count, 1);
  });

  testWidgets('accepting disclosure records version before enabling UI', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: SelfTouchTrackerPage()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('内容を理解して記録を始める'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString(SelfTouchConsentStore.localVersionKey),
      SelfTouchDisclosure.fallback.version,
    );
    expect(
      DateTime.tryParse(
        prefs.getString(SelfTouchConsentStore.localConsentedAtKey) ?? '',
      ),
      isNotNull,
    );
    expect(find.text('医療上の診断・治療ではありません'), findsOneWidget);
    expect(find.textContaining('厚生労働省'), findsOneWidget);
  });
}
