// ignore_for_file: argument_type_not_assignable

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:my_web_app/services/theme_service.dart';
import 'package:my_web_app/widgets/note_editor/ai_assistant_menu.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'ai_assistant_menu_test.mocks.dart';

@GenerateMocks([SupabaseClient, GoTrueClient, FunctionsClient])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSupabaseClient mockSupabaseClient;
  late MockGoTrueClient mockGoTrueClient;
  late MockFunctionsClient mockFunctionsClient;
  late ThemeService themeService;
  late TextEditingController controller;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    mockSupabaseClient = MockSupabaseClient();
    mockGoTrueClient = MockGoTrueClient();
    mockFunctionsClient = MockFunctionsClient();
    themeService = ThemeService();
    controller = TextEditingController(text: 'Initial content');

    when(mockSupabaseClient.auth).thenReturn(mockGoTrueClient);
    when(mockSupabaseClient.functions).thenReturn(mockFunctionsClient);

    when(mockFunctionsClient.invoke(any, body: anyNamed('body'))).thenAnswer(
      (_) async => FunctionResponse(
        status: 200,
        data: <String, dynamic>{'result': 'Improved content'},
      ),
    );
  });

  tearDown(() {
    controller.dispose();
  });

  Widget buildTestWidget({required Function(String) onApply}) {
    return ChangeNotifierProvider<ThemeService>.value(
      value: themeService,
      child: MaterialApp(
        home: Scaffold(
          body: AiAssistantMenu(
            contentController: controller,
            onApply: onApply,
            supabaseClient: mockSupabaseClient,
          ),
        ),
      ),
    );
  }

  testWidgets('renders initial state with icon', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestWidget(onApply: (_) {}));

    expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('tapping icon opens popup menu with current items', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildTestWidget(onApply: (_) {}));

    await tester.tap(find.byIcon(Icons.auto_awesome));
    await tester.pumpAndSettle();

    expect(find.text('Improve Writing'), findsOneWidget);
    expect(find.text('Summarize'), findsOneWidget);
    expect(find.text('Expand Ideas'), findsOneWidget);
  });

  testWidgets(
    'selecting improve calls Supabase function and onApply on success',
    (WidgetTester tester) async {
      String? appliedResult;

      when(
        mockFunctionsClient.invoke(
          'ai-assistant',
          body: <String, dynamic>{
            'action': 'improve',
            'content': 'Initial content',
            'useMagi': true,
            'melchiorModel': 'gpt-4o-mini',
            'balthasarModel': 'claude-sonnet-4-6',
            'casperModel': 'gemini-2.5-flash',
            'synthesisModel': 'claude-sonnet-4-6',
          },
        ),
      ).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        return FunctionResponse(
          status: 200,
          data: <String, dynamic>{'result': 'Improved content'},
        );
      });

      await tester.pumpWidget(
        buildTestWidget(
          onApply: (result) {
            appliedResult = result;
          },
        ),
      );

      await tester.tap(find.byIcon(Icons.auto_awesome));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Improve Writing'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(appliedResult, 'Improved content');

      await tester.pumpAndSettle();
      expect(find.text('AI action completed.'), findsOneWidget);
    },
  );

  testWidgets('shows error snackbar when the function returns a failure status',
      (
    WidgetTester tester,
  ) async {
    when(mockFunctionsClient.invoke(any, body: anyNamed('body'))).thenAnswer(
      (_) async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return FunctionResponse(status: 500, data: 'Server Error');
      },
    );

    await tester.pumpWidget(buildTestWidget(onApply: (_) {}));

    await tester.tap(find.byIcon(Icons.auto_awesome));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Summarize'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('AI action failed: Server Error'), findsOneWidget);
  });

  testWidgets('shows error snackbar when the function throws', (
    WidgetTester tester,
  ) async {
    final exception = Exception('Network Error');
    when(mockFunctionsClient.invoke(any, body: anyNamed('body'))).thenAnswer(
      (_) async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        throw exception;
      },
    );

    await tester.pumpWidget(buildTestWidget(onApply: (_) {}));

    await tester.tap(find.byIcon(Icons.auto_awesome));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Expand Ideas'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      find.text('AI action errored: $exception'),
      findsOneWidget,
    );
  });
}
