import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/self_touch_tracker_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('records a self-touch event from the quick action',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SelfTouchTrackerPage()),
    );
    await tester.pumpAndSettle();

    expect(find.text('自己接触トラッカー'), findsOneWidget);
    expect(find.text('ワンタップ記録'), findsOneWidget);

    await tester.tap(find.text('いま記録'));
    await tester.pumpAndSettle();

    expect(find.textContaining('行き詰まり'), findsWidgets);
  });
}
