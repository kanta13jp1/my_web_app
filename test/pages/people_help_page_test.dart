@TestOn('browser')

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/note_editor_page.dart';
import 'package:my_web_app/pages/people_help_page.dart';
import 'package:my_web_app/services/ai_service.dart';
import 'package:my_web_app/services/people_leave_request_service.dart';
import 'package:my_web_app/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeEditorSupabaseClient extends Fake implements SupabaseClient {}

class _FakeNoteEditorAIService extends AIService {
  _FakeNoteEditorAIService() : super(_FakeEditorSupabaseClient());

  AIServiceException? summarizeError;
  AIServiceException? customPromptError;
  String? lastSummarizeStyleName;
  String? lastSummarizeModel;
  String? lastSuggestTitlesModel;
  String? lastCustomPrompt;
  String? lastCustomPromptModel;

  @override
  Future<String> summarizeText(
    String content, {
    String? model,
    String? styleName,
    String? styleInstruction,
  }) async {
    final error = summarizeError;
    if (error != null) {
      throw error;
    }
    lastSummarizeModel = model;
    lastSummarizeStyleName = styleName;
    return 'summary[$styleName]: $content';
  }

  @override
  Future<List<String>> suggestTitles(
    String content, {
    String? model,
  }) async {
    lastSuggestTitlesModel = model;
    return <String>['AI generated note title'];
  }

  @override
  Future<String> runCustomPrompt(
    String prompt, {
    String? model,
    String? styleName,
    String? styleInstruction,
  }) async {
    final error = customPromptError;
    if (error != null) {
      throw error;
    }
    lastCustomPrompt = prompt;
    lastCustomPromptModel = model;
    return 'custom[$model]: ${prompt.split('\n').first}';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('PeopleHelpPage renders quick actions and opens onboarding memo',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.byKey(const Key('people_help_quick_rewards')),
      200,
      scrollable: scrollable,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('people_help_leave_requests_section')),
      200,
      scrollable: scrollable,
    );

    expect(find.byKey(const Key('people_help_page_scaffold')), findsOneWidget);
    expect(find.byKey(const Key('people_help_hero_card')), findsOneWidget);
    expect(find.byKey(const Key('people_help_quick_notes')), findsOneWidget);
    expect(
      find.byKey(const Key('people_help_quick_onboarding')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('people_help_quick_rewards')), findsOneWidget);
    expect(find.byKey(const Key('people_help_quick_stats')), findsNothing);
    expect(
      find.byKey(const Key('people_help_leave_requests_section')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('people_help_quick_onboarding')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('note_editor_page_scaffold')), findsOneWidget);
    expect(find.byKey(const Key('note_editor_title_field')), findsOneWidget);
  });

  testWidgets('NoteEditorPage slash commands update favorite, style, and title',
      (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'preferred_ai_model': 'gpt-4o-mini',
    });
    final aiService = _FakeNoteEditorAIService();

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeService(),
        child: MaterialApp(
          home: NoteEditorPage(
            initialContent: 'Revenue growth notes',
            supabaseClient: _FakeEditorSupabaseClient(),
            aiService: aiService,
          ),
        ),
      ),
    );
    await tester.pump();

    final commandField = find.byKey(
      const Key('note_editor_slash_command_field'),
    );

    Future<void> submitSlashCommand(String command) async {
      await tester.ensureVisible(commandField);
      await tester.showKeyboard(commandField);
      await tester.enterText(commandField, command);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.pump();
    }

    expect(
      find.byKey(const Key('note_editor_slash_command_bar')),
      findsOneWidget,
    );
    expect(find.text('/style concise'), findsOneWidget);
    expect(
      find.byKey(const Key('note_editor_selected_ai_model_chip')),
      findsOneWidget,
    );
    expect(find.text('Default model: gpt-4o-mini'), findsOneWidget);
    expect(find.byIcon(Icons.star_border), findsOneWidget);

    await submitSlashCommand('/favorite');

    expect(find.byIcon(Icons.star), findsOneWidget);

    await submitSlashCommand('/style concise');

    final conciseChip = tester.widget<ChoiceChip>(
      find.byKey(const Key('note_editor_ai_style_concise')),
    );
    expect(conciseChip.selected, isTrue);
    expect(find.text('Short, direct, and easy to scan.'), findsOneWidget);

    await submitSlashCommand('/summarize');

    final contentField = tester.widget<TextField>(
      find.byKey(const Key('note_editor_content_field')),
    );
    expect(
      contentField.controller?.text,
      'summary[concise]: Revenue growth notes',
    );
    expect(aiService.lastSummarizeModel, 'gpt-4o-mini');
    expect(aiService.lastSummarizeStyleName, 'concise');

    await submitSlashCommand('/title');

    final titleField = tester.widget<TextField>(
      find.byKey(const Key('note_editor_title_field')),
    );
    expect(titleField.controller?.text, 'AI generated note title');
    expect(aiService.lastSuggestTitlesModel, 'gpt-4o-mini');
  });

  testWidgets(
    'NoteEditorPage shows upgrade dialog and opens billing on free limit',
    (WidgetTester tester) async {
      final aiService = _FakeNoteEditorAIService()
        ..summarizeError = AIServiceException.fromFunctionPayload({
          'status': 402,
          'code': 'free_limit_reached',
          'message': '今月の無料AI質問30回を使い切りました。',
          'upgrade_url': '/billing',
        });

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => ThemeService(),
          child: MaterialApp(
            routes: {
              '/billing': (_) => const Scaffold(
                    body: Text('Billing upgrade page'),
                  ),
            },
            home: NoteEditorPage(
              initialContent: 'Revenue growth notes',
              supabaseClient: _FakeEditorSupabaseClient(),
              aiService: aiService,
            ),
          ),
        ),
      );
      await tester.pump();

      final commandField = find.byKey(
        const Key('note_editor_slash_command_field'),
      );
      await tester.ensureVisible(commandField);
      await tester.showKeyboard(commandField);
      await tester.enterText(commandField, '/summarize');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('ai_free_limit_upgrade_dialog')),
        findsOneWidget,
      );
      expect(find.text('無料枠の上限に達しました'), findsOneWidget);
      expect(find.text('今月の無料AI質問30回を使い切りました。'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('ai_free_limit_upgrade_primary_button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Billing upgrade page'), findsOneWidget);
    },
  );

  testWidgets('NoteEditorPage prompt library saves and runs a custom prompt', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'preferred_ai_model': 'gpt-4o-mini',
      'note_prompt_library_v1': jsonEncode([
        {
          'id': 'board-brief',
          'title': 'Board Brief',
          'prompt':
              'Turn this note into a board-ready brief.\nTitle: {{note_title}}\nContent: {{note_content}}\nStyle: {{writing_style}}',
          'updatedAt': '2026-03-20T09:00:00.000',
        },
      ]),
    });
    final aiService = _FakeNoteEditorAIService();

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeService(),
        child: MaterialApp(
          home: NoteEditorPage(
            initialTitle: 'Q1 Planning',
            initialContent: 'Revenue growth notes',
            supabaseClient: _FakeEditorSupabaseClient(),
            aiService: aiService,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const Key('note_editor_prompt_library_section')),
      findsOneWidget,
    );
    final commandField = find.byKey(
      const Key('note_editor_slash_command_field'),
    );
    final libraryTile = find.descendant(
      of: find.byKey(const Key('note_editor_prompt_library_section')),
      matching: find.byType(ListTile),
    );

    Future<void> submitSlashCommand(String command) async {
      await tester.ensureVisible(commandField);
      await tester.showKeyboard(commandField);
      await tester.enterText(commandField, command);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.pump();
    }

    await tester.ensureVisible(libraryTile);
    await tester.tap(libraryTile);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('note_editor_prompt_template_chip_board-brief')),
      findsOneWidget,
    );

    await submitSlashCommand('/prompt board-brief');

    final contentField = tester.widget<TextField>(
      find.byKey(const Key('note_editor_content_field')),
    );
    expect(
      contentField.controller?.text,
      'custom[gpt-4o-mini]: You are running a saved prompt from a Claude-style workbench.',
    );
    expect(aiService.lastCustomPromptModel, 'gpt-4o-mini');
    expect(aiService.lastCustomPrompt, contains('Template title: Board Brief'));
    expect(
      aiService.lastCustomPrompt,
      contains('Current note title: Q1 Planning'),
    );
    expect(aiService.lastCustomPrompt, contains('Revenue growth notes'));
    expect(
      aiService.lastCustomPrompt,
      contains('Style: normal'),
    );
  });

  testWidgets('PeopleHelpPage creates and approves a leave request', (
    WidgetTester tester,
  ) async {
    const leaveRequestService = PeopleLeaveRequestService();
    await tester.binding.setSurfaceSize(const Size(1200, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeService(),
        child: const MaterialApp(
          home: PeopleHelpPage(
            leaveRequestService: leaveRequestService,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.byKey(const Key('people_help_leave_requests_section')),
      200,
      scrollable: scrollable,
    );

    expect(
      find.byKey(const Key('people_help_leave_requests_empty')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('people_help_leave_request_add_button')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('people_help_leave_request_employee_field')),
      'Aiko Tanaka',
    );
    await tester.enterText(
      find.byKey(const Key('people_help_leave_request_start_field')),
      '2026-03-25',
    );
    await tester.enterText(
      find.byKey(const Key('people_help_leave_request_end_field')),
      '2026-03-26',
    );
    await tester.enterText(
      find.byKey(const Key('people_help_leave_request_reason_field')),
      'Family trip',
    );

    await tester.tap(
      find.byKey(const Key('people_help_leave_request_submit_button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aiko Tanaka'), findsOneWidget);
    expect(find.text('Paid leave'), findsOneWidget);
    expect(find.text('2026-03-25 to 2026-03-26'), findsOneWidget);
    expect(find.text('pending'), findsOneWidget);

    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();

    expect(find.text('approved'), findsOneWidget);
  });
}
