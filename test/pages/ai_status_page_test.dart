import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:my_web_app/pages/ai_status_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@GenerateMocks([
  SupabaseClient,
  FunctionsClient,
  FunctionResponse,
])
import 'ai_status_page_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSupabaseClient mockSupabaseClient;
  late MockFunctionsClient mockFunctionsClient;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockSupabaseClient = MockSupabaseClient();
    mockFunctionsClient = MockFunctionsClient();
    when(mockSupabaseClient.functions).thenReturn(mockFunctionsClient);
  });

  Widget createTestWidget() {
    return MaterialApp(
      home: AiStatusPage(supabaseClient: mockSupabaseClient),
    );
  }

  testWidgets('normalizes providers and hides xai entries', (
    WidgetTester tester,
  ) async {
    final modelsResponse = {
      'success': true,
      'models': [
        {'name': 'gemma-3n-e2b-it', 'provider': 'Google', 'score': 80},
        {'model': 'o4-mini', 'provider': 'openai'},
        {'model': 'deepseek-chat', 'provider': 'DeepSeek', 'score': 70},
        {'model': 'grok-2', 'provider': 'xAI', 'score': 99},
      ],
    };
    final mockResponse = MockFunctionResponse();
    when(mockResponse.data).thenReturn(modelsResponse);
    when(mockResponse.status).thenReturn(200);

    when(
      mockFunctionsClient.invoke(
        'ai-assistant',
        body: {'action': 'get_models'},
      ),
    ).thenAnswer((_) async => mockResponse);

    await tester.pumpWidget(createTestWidget());
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('gemma-3n-e2b-it'), findsOneWidget);
    expect(find.textContaining('CASPER (GEMINI)'), findsOneWidget);
    expect(find.text('80'), findsOneWidget);

    expect(find.text('o4-mini'), findsOneWidget);
    expect(find.textContaining('MELCHIOR (GPT)'), findsOneWidget);

    expect(find.text('deepseek-chat'), findsOneWidget);
    expect(find.textContaining('MELCHIOR (DEEPSEEK)'), findsOneWidget);

    expect(find.text('grok-2'), findsNothing);
  });

  testWidgets('updates score and benchmark details after a successful test', (
    WidgetTester tester,
  ) async {
    final modelsResponse = {
      'success': true,
      'models': [
        {'model': 'test-model', 'provider': 'test', 'score': 50},
      ],
    };
    final mockListResp = MockFunctionResponse();
    when(mockListResp.data).thenReturn(modelsResponse);
    when(mockListResp.status).thenReturn(200);
    when(
      mockFunctionsClient.invoke(
        'ai-assistant',
        body: {'action': 'get_models'},
      ),
    ).thenAnswer((_) async => mockListResp);

    final testResultResponse = {
      'success': true,
      'benchmark': {
        'score': 90,
        'latency': 500,
        'detail': 'Great performance',
        'levels': [
          {'level': 'level1', 'passed': true, 'score': 10, 'maxPoints': 10},
        ],
      },
    };
    final mockTestResp = MockFunctionResponse();
    when(mockTestResp.data).thenReturn(testResultResponse);

    when(
      mockFunctionsClient.invoke(
        'ai-assistant',
        body: {'action': 'test_model', 'model': 'test-model'},
      ),
    ).thenAnswer((_) async => mockTestResp);

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    await tester.tap(find.text('test-model'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('895'), findsOneWidget);
    expect(find.text('Great performance'), findsOneWidget);
  });

  testWidgets('runs all model tests from the toolbar action', (
    WidgetTester tester,
  ) async {
    final modelsResponse = {
      'success': true,
      'models': [
        {'model': 'model-A', 'score': 10},
        {'model': 'model-B', 'score': 20},
      ],
    };
    final mockListResp = MockFunctionResponse();
    when(mockListResp.data).thenReturn(modelsResponse);
    when(mockListResp.status).thenReturn(200);
    when(
      mockFunctionsClient.invoke(
        'ai-assistant',
        body: {'action': 'get_models'},
      ),
    ).thenAnswer((_) async => mockListResp);

    final mockTestResp = MockFunctionResponse();
    when(mockTestResp.data).thenReturn({
      'success': true,
      'benchmark': {'score': 50},
    });

    when(
      mockFunctionsClient.invoke(
        'ai-assistant',
        body: {'action': 'test_model', 'model': 'model-A'},
      ),
    ).thenAnswer((_) async => mockTestResp);
    when(
      mockFunctionsClient.invoke(
        'ai-assistant',
        body: {'action': 'test_model', 'model': 'model-B'},
      ),
    ).thenAnswer((_) async => mockTestResp);

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.play_circle_outline));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    verify(
      mockFunctionsClient.invoke(
        'ai-assistant',
        body: {'action': 'test_model', 'model': 'model-A'},
      ),
    ).called(1);
    verify(
      mockFunctionsClient.invoke(
        'ai-assistant',
        body: {'action': 'test_model', 'model': 'model-B'},
      ),
    ).called(1);
  });

  testWidgets('shows the api error state', (WidgetTester tester) async {
    final mockErrResp = MockFunctionResponse();
    when(mockErrResp.status).thenReturn(500);

    when(
      mockFunctionsClient.invoke(
        'ai-assistant',
        body: {'action': 'get_models'},
      ),
    ).thenAnswer((_) async => mockErrResp);

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(find.textContaining('500'), findsOneWidget);
  });

  testWidgets('can set and show the default ai model', (
    WidgetTester tester,
  ) async {
    final modelsResponse = {
      'success': true,
      'models': [
        {'model': 'claude-sonnet-4-6', 'provider': 'anthropic'},
        {'model': 'gpt-4o-mini', 'provider': 'openai'},
      ],
    };
    final mockResponse = MockFunctionResponse();
    when(mockResponse.data).thenReturn(modelsResponse);
    when(mockResponse.status).thenReturn(200);

    when(
      mockFunctionsClient.invoke(
        'ai-assistant',
        body: {'action': 'get_models'},
      ),
    ).thenAnswer((_) async => mockResponse);

    await tester.pumpWidget(createTestWidget());
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(
        const Key('ai_status_default_model_button_claude-sonnet-4-6'),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('ai_status_default_model_banner')),
      findsOneWidget,
    );
    expect(find.text('claude-sonnet-4-6'), findsWidgets);
    expect(
      find.byKey(
        const Key('ai_status_default_model_badge_claude-sonnet-4-6'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('can update MAGI system settings from the status page', (
    WidgetTester tester,
  ) async {
    final modelsResponse = {
      'success': true,
      'models': [
        {'model': 'gpt-4o-mini', 'provider': 'openai'},
        {'model': 'gpt-5.4', 'provider': 'openai'},
        {'model': 'claude-sonnet-4-6', 'provider': 'anthropic'},
        {'model': 'gemini-2.5-flash', 'provider': 'google'},
      ],
    };
    final mockResponse = MockFunctionResponse();
    when(mockResponse.data).thenReturn(modelsResponse);
    when(mockResponse.status).thenReturn(200);

    when(
      mockFunctionsClient.invoke(
        'ai-assistant',
        body: {'action': 'get_models'},
      ),
    ).thenAnswer((_) async => mockResponse);

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ai_status_magi_system_card')), findsOneWidget);

    await tester.tap(find.byKey(const Key('ai_status_magi_enabled_switch')));
    await tester.pumpAndSettle();

    var prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('magi_system_enabled_v1'), isFalse);

    await tester.tap(find.byKey(const Key('ai_status_magi_enabled_switch')));
    await tester.pumpAndSettle();

    prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('magi_system_enabled_v1'), isTrue);

    await tester.tap(find.byKey(const Key('ai_status_melchior_dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('gpt-5.4').last);
    await tester.pumpAndSettle();

    prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('magi_system_melchior_model_v1'), 'gpt-5.4');
  });
}
