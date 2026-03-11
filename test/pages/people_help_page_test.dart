import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/people_help_page.dart';
import 'package:my_web_app/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('PeopleHelpPage renders quick actions and opens onboarding memo',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeService(),
        child: const MaterialApp(
          home: PeopleHelpPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('people_help_page_scaffold')), findsOneWidget);
    expect(find.byKey(const Key('people_help_hero_card')), findsOneWidget);
    expect(find.byKey(const Key('people_help_quick_notes')), findsOneWidget);
    expect(
      find.byKey(const Key('people_help_quick_onboarding')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('people_help_quick_rewards')), findsOneWidget);
    expect(find.byKey(const Key('people_help_quick_stats')), findsOneWidget);

    await tester.tap(find.byKey(const Key('people_help_quick_onboarding')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('note_editor_page_scaffold')), findsOneWidget);
    expect(find.byKey(const Key('note_editor_title_field')), findsOneWidget);
  });
}
