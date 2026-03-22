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

// Mock Supabase classes
@GenerateMocks([SupabaseClient, GoTrueClient, FunctionsClient])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSupabaseClient mockSupabaseClient;
  late MockGoTrueClient mockGoTrueClient;
  late MockFunctionsClient mockFunctionsClient;
  late ThemeService themeService;
  late TextEditingController controller;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockSupabaseClient = MockSupabaseClient();
    mockGoTrueClient = MockGoTrueClient();
    mockFunctionsClient = MockFunctionsClient();
    themeService = ThemeService();
    controller = TextEditingController(text: 'Initial content');

    when(mockSupabaseClient.auth).thenReturn(mockGoTrueClient);
    when(mockSupabaseClient.functions).thenReturn(mockFunctionsClient);

    // Default stub for a successful function invocation
    when(mockFunctionsClient.invoke(any, body: anyNamed('body'))).thenAnswer(
      (_) async => FunctionResponse(
        status: 200,
        data: {'result': 'Improved content'},
      ),
    );
  });

  tearDown(() {
    controller.dispose();
  });

  // Wrapper function to build the widget with necessary providers
  Widget buildTestWidget({required Function(String) onApply}) {
    return ChangeNotifierProvider<ThemeService>.value(
      value: themeService,
      child: MaterialApp(
        home: Scaffold(
          body: AiAssistantMenu(
            contentController: controller,
            onApply: onApply,
            supabaseClient: mockSupabaseClient, // Inject the mock client
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

  testWidgets('tapping icon opens popup menu with correct items',
      (WidgetTester tester) async {
    await tester.pumpWidget(buildTestWidget(onApply: (_) {}));

    await tester.tap(find.byIcon(Icons.auto_awesome));
    await tester.pumpAndSettle(); // Wait for menu to appear

    expect(find.text('文章を洗練'), findsOneWidget);
    expect(find.text('要約'), findsOneWidget);
    expect(find.text('CSO分析'), findsOneWidget);
  });

  testWidgets(
      'selecting "文章を洗練" calls Supabase function and onApply on success',
      (WidgetTester tester) async {
    String? appliedResult;

    when(
      mockFunctionsClient.invoke(
        'ai-assistant',
        body: {
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
      // Simulate network delay
      await Future.delayed(const Duration(milliseconds: 100));
      return FunctionResponse(
        status: 200,
        data: {'result': 'Improved content'},
      );
    });

    await tester.pumpWidget(
      buildTestWidget(
        onApply: (result) {
          appliedResult = result;
        },
      ),
    );

    // Open menu
    await tester.tap(find.byIcon(Icons.auto_awesome));
    await tester.pumpAndSettle();

    // Select item
    await tester.tap(find.text('文章を洗練'));
    await tester.pump(); // Start the async operation

    // Verify loading state
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester
        .pump(const Duration(milliseconds: 150)); // Wait for future to complete

    // Verify loading is gone
    expect(find.byType(CircularProgressIndicator), findsNothing);

    // Verify onApply was called
    expect(appliedResult, 'Improved content');

    // Verify snackbar appears
    await tester.pumpAndSettle();
    expect(find.text('AIがimproveを実行しました。'), findsOneWidget);
  });

  testWidgets(
      'shows error snackbar when function call fails with non-200 status',
      (WidgetTester tester) async {
    when(mockFunctionsClient.invoke(any, body: anyNamed('body')))
        .thenAnswer((_) async {
      await Future.delayed(const Duration(milliseconds: 10));
      return FunctionResponse(status: 500, data: 'Server Error');
    });

    await tester.pumpWidget(buildTestWidget(onApply: (_) {}));

    await tester.tap(find.byIcon(Icons.auto_awesome));
    await tester.pumpAndSettle();

    await tester.tap(find.text('要約'));
    await tester.pump(); // Start loading

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle(); // Wait for future and snackbar

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('AI機能の呼び出しに失敗しました: Server Error'), findsOneWidget);
  });

  testWidgets('shows error snackbar when function call throws an exception',
      (WidgetTester tester) async {
    final exception = Exception('Network Error');
    when(mockFunctionsClient.invoke(any, body: anyNamed('body')))
        .thenAnswer((_) async {
      await Future.delayed(const Duration(milliseconds: 10));
      throw exception;
    });

    await tester.pumpWidget(buildTestWidget(onApply: (_) {}));

    await tester.tap(find.byIcon(Icons.auto_awesome));
    await tester.pumpAndSettle();

    await tester.tap(find.text('CSO分析'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('AI機能でエラーが発生しました: $exception'), findsOneWidget);
  });
}
