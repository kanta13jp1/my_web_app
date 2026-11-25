import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:my_web_app/features/vision_benchmark/domain/vision_benchmark_models.dart';
import 'package:my_web_app/features/vision_benchmark/vision_benchmark_container.dart';
import 'package:my_web_app/pages/ai_status_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@GenerateMocks([
  SupabaseClient,
  FunctionsClient,
  FunctionResponse,
])
import 'ai_status_page_test.mocks.dart';

class _FakeUser extends Fake implements User {
  @override
  String get id => 'test-user-id';
}

class _FakeGoTrueClient extends Fake implements GoTrueClient {
  @override
  User? get currentUser => _FakeUser();
}

class _RecordingVisionRepository implements VisionBenchmarkRepository {
  final List<VisionBenchmarkRun> runs = <VisionBenchmarkRun>[];

  @override
  Future<VisionBenchmarkSnapshot> fetchDashboard({
    required int threshold,
    String? modelFilter,
    int limit = 40,
  }) async {
    return VisionBenchmarkSnapshot.build(
      runs: runs.take(limit).toList(growable: false),
      threshold: threshold,
    );
  }

  @override
  Future<VisionBenchmarkRun> recordRun({
    required String model,
    required String provider,
    required int score,
    required int latencyMs,
    required int threshold,
    required bool passed,
    required String detail,
    List<VisionBenchmarkLevel> levels = const <VisionBenchmarkLevel>[],
  }) async {
    final run = VisionBenchmarkRun(
      id: 'ai-status-run-${runs.length + 1}',
      model: model,
      provider: provider,
      score: score,
      latencyMs: latencyMs,
      threshold: threshold,
      passed: passed,
      detail: detail,
      levels: levels,
      recordedAt: DateTime.utc(2026, 11, 25, 13, runs.length),
    );
    runs.insert(0, run);
    return run;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSupabaseClient mockSupabaseClient;
  late MockFunctionsClient mockFunctionsClient;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockSupabaseClient = MockSupabaseClient();
    mockFunctionsClient = MockFunctionsClient();
    when(mockSupabaseClient.functions).thenReturn(mockFunctionsClient);
    when(mockSupabaseClient.auth).thenReturn(_FakeGoTrueClient());
  });

  Widget createTestWidget() {
    return MaterialApp(
      home: AiStatusPage(supabaseClient: mockSupabaseClient),
    );
  }

  Future<void> revealInScrollView(
    WidgetTester tester,
    Finder finder, {
    double delta = 300,
  }) async {
    await tester.scrollUntilVisible(
      finder,
      delta,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
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

    expect(
      find.byKey(const ValueKey<String>('gemma-3n-e2b-it')),
      findsOneWidget,
    );
    expect(find.textContaining('CASPER (GEMINI)'), findsOneWidget);
    expect(find.text('80'), findsOneWidget);

    final openAiCard = find.byKey(const ValueKey<String>('o4-mini'));
    await revealInScrollView(tester, openAiCard);
    expect(openAiCard, findsOneWidget);
    expect(find.textContaining('MELCHIOR (GPT)'), findsOneWidget);

    final deepSeekCard = find.byKey(const ValueKey<String>('deepseek-chat'));
    await revealInScrollView(tester, deepSeekCard);
    expect(deepSeekCard, findsOneWidget);
    expect(find.textContaining('MELCHIOR (DEEPSEEK)'), findsOneWidget);

    expect(find.byKey(const ValueKey<String>('grok-2')), findsNothing);
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

    final modelCard = find.byKey(const ValueKey<String>('test-model'));
    await revealInScrollView(tester, modelCard);
    await tester.tap(modelCard);
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

    final defaultButton = find.byKey(
      const Key('ai_status_default_model_button_claude-sonnet-4-6'),
    );
    await revealInScrollView(tester, defaultButton);
    await tester.tap(defaultButton);
    await tester.pump();
    await tester.pumpAndSettle();

    await revealInScrollView(
      tester,
      find.byKey(const Key('ai_status_default_model_banner')),
      delta: -300,
    );

    expect(
      find.byKey(const Key('ai_status_default_model_banner')),
      findsOneWidget,
    );
    expect(find.text('claude-sonnet-4-6'), findsWidgets);

    final badge = find.byKey(
      const Key('ai_status_default_model_badge_claude-sonnet-4-6'),
    );
    await revealInScrollView(tester, badge);
    expect(badge, findsOneWidget);
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

  testWidgets('records Vision benchmark runs and opens AI dashboard', (
    WidgetTester tester,
  ) async {
    final visionRepo = _RecordingVisionRepository();
    final mockListResp = MockFunctionResponse();
    when(mockListResp.status).thenReturn(200);
    when(mockListResp.data).thenReturn(<String, Object?>{
      'success': true,
      'models': <Map<String, Object?>>[
        <String, Object?>{
          'model': 'gemini-2.5-flash',
          'provider': 'google',
          'score': 60,
        },
      ],
    });
    when(
      mockFunctionsClient.invoke(
        'ai-assistant',
        body: {'action': 'get_models'},
      ),
    ).thenAnswer((_) async => mockListResp);

    final mockTestResp = MockFunctionResponse();
    when(mockTestResp.status).thenReturn(200);
    when(mockTestResp.data).thenReturn(<String, Object?>{
      'success': true,
      'benchmark': <String, Object?>{
        'score': 55,
        'latency': 720,
        'detail': 'Low accuracy on L5 test',
        'levels': <Object?>[],
      },
    });
    when(
      mockFunctionsClient.invoke(
        'ai-assistant',
        body: {'action': 'test_model', 'model': 'gemini-2.5-flash'},
      ),
    ).thenAnswer((_) async => mockTestResp);

    await tester.pumpWidget(
      MaterialApp(
        home: AiStatusPage(
          supabaseClient: mockSupabaseClient,
          visionBenchmarkRepository: visionRepo,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final card = find.byKey(const ValueKey<String>('gemini-2.5-flash'));
    await revealInScrollView(tester, card);
    await tester.tap(card);
    await tester.pumpAndSettle();

    expect(visionRepo.runs, hasLength(1));
    expect(visionRepo.runs.first.model, 'gemini-2.5-flash');
    expect(visionRepo.runs.first.score, 55);

    await tester.tap(
      find.byKey(const Key('ai_status_vision_dashboard_button')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(VisionBenchmarkDashboardPage), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('vision_benchmark_alert_banner')),
      findsOneWidget,
    );
    expect(find.textContaining('gemini-2.5-flash: 55点'), findsOneWidget);
  });
}
