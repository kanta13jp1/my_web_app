import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/abstinence_guard_page.dart';
import 'package:my_web_app/services/abstinence_guard_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('AbstinenceGuardPage shows tracked harmful habits',
      (WidgetTester tester) async {
    final prefs = await SharedPreferences.getInstance();
    await AbstinenceGuardStore.setEnabled(
      itemId: 'alcohol',
      isEnabled: true,
      prefs: prefs,
      now: DateTime(2026, 2, 26),
    );
    await AbstinenceGuardStore.incrementSlip(
      itemId: 'alcohol',
      prefs: prefs,
      now: DateTime(2026, 2, 26),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: AbstinenceGuardPage(
          nowProvider: _fixedNow,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('禁欲ガード'), findsOneWidget);
    expect(find.text('今日やらないことを固定する'), findsOneWidget);
    expect(find.text('酒'), findsOneWidget);
    expect(find.textContaining('逸脱 +1 (1)'), findsOneWidget);
  });
}

DateTime _fixedNow() => DateTime(2026, 2, 26, 9, 0);
