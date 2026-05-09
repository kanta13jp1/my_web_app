import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/calendar_events_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://dummy.supabase.co',
      anonKey: 'dummy',
      debug: false,
    );
  });

  testWidgets('CalendarEventsPage switches to day timeline grid',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: CalendarEventsPage()),
    );
    await tester.pump();

    expect(find.text('Month'), findsOneWidget);
    expect(find.text('Week'), findsOneWidget);
    expect(find.text('Day'), findsOneWidget);

    await tester.tap(find.text('Week'));
    await tester.pump();
    expect(find.text('Day view'), findsNothing);

    await tester.tap(find.text('Day'));
    await tester.pump();

    expect(find.text('Day view'), findsOneWidget);
    expect(find.text('00:00'), findsOneWidget);
    expect(find.text('23:00'), findsOneWidget);
  });
}
