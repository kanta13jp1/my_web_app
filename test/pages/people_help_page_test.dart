import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/note_editor_page.dart';
import 'package:my_web_app/pages/people_help_page.dart';
import 'package:my_web_app/services/ai_service.dart';
import 'package:my_web_app/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeEditorSupabaseClient extends Fake implements SupabaseClient {}

class _FakeNoteEditorAIService extends AIService {
  _FakeNoteEditorAIService() : super(_FakeEditorSupabaseClient());

  @override
  Future<List<String>> suggestTitles(String content) async {
    return <String>['AI generated note title'];
  }
}

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
        child: MaterialApp(
          home: PeopleHelpPage(
            onboardingNotePage: NoteEditorPage(
              initialTitle: 'オンボーディングメモ',
              initialContent: '目的:\n- \n',
              supabaseClient: _FakeEditorSupabaseClient(),
              aiService: _FakeNoteEditorAIService(),
            ),
          ),
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

  testWidgets('NoteEditorPage slash commands update favorite state and title', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeService(),
        child: MaterialApp(
          home: NoteEditorPage(
            initialContent: 'Revenue growth notes',
            supabaseClient: _FakeEditorSupabaseClient(),
            aiService: _FakeNoteEditorAIService(),
          ),
        ),
      ),
    );
    await tester.pump();

    final commandField = find.byKey(
      const Key('note_editor_slash_command_field'),
    );
    final runButton = find.byKey(
      const Key('note_editor_slash_command_run_button'),
    );

    expect(
      find.byKey(const Key('note_editor_slash_command_bar')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.star_border), findsOneWidget);

    await tester.enterText(commandField, '/favorite');
    await tester.ensureVisible(runButton);
    await tester.tap(runButton);
    await tester.pump();

    expect(find.byIcon(Icons.star), findsOneWidget);

    await tester.enterText(commandField, '/title');
    await tester.ensureVisible(runButton);
    await tester.tap(runButton);
    await tester.pump();
    await tester.pump();

    final titleField = tester.widget<TextField>(
      find.byKey(const Key('note_editor_title_field')),
    );
    expect(titleField.controller?.text, 'AI generated note title');
  });
}
