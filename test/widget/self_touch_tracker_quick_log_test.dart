import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/self_touch_tracker_page.dart';
import 'package:my_web_app/services/abstinence_guard_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('SelfTouchTrackerPage quick logs when opened from PWA shortcut', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: SelfTouchTrackerPage(quickLogOnOpen: true)),
    );

    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    final prefs = await SharedPreferences.getInstance();
    final trend = await AbstinenceGuardStore.loadSlipCountsByDate(
      itemId: 'touch_hair',
      days: 1,
      prefs: prefs,
    );

    expect(trend.single.count, 1);
  });
}
