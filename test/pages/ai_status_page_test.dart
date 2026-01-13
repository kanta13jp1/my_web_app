import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:my_web_app/pages/ai_status_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@GenerateMocks([
  SupabaseClient,
  FunctionsClient,
  FunctionResponse,
])
import 'ai_status_page_test.mocks.dart';

void main() {
  late MockSupabaseClient mockSupabaseClient;
  late MockFunctionsClient mockFunctionsClient;

  setUp(() {
    mockSupabaseClient = MockSupabaseClient();
    mockFunctionsClient = MockFunctionsClient();
    when(mockSupabaseClient.functions).thenReturn(mockFunctionsClient);
  });

  Widget createTestWidget() {
    return MaterialApp(
      home: AiStatusPage(supabaseClient: mockSupabaseClient),
    );
  }

  testWidgets('初期表示: モデル一覧を取得し、正規化して表示すること', (WidgetTester tester) async {
    final modelsResponse = {
      'success': true,
      'models': [
        {'name': 'gemini-pro', 'provider': 'Google', 'score': 80},
        {'model': 'gpt-4', 'provider': 'openai'},
      ],
    };
    final mockResponse = MockFunctionResponse();
    when(mockResponse.data).thenReturn(modelsResponse);
    when(mockResponse.status).thenReturn(200);

    // 引数を具体的に指定
    when(
      mockFunctionsClient.invoke(
        'ai-assistant',
        body: {'action': 'get_models'},
      ),
    ).thenAnswer((_) async => mockResponse);

    await tester.pumpWidget(createTestWidget());
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('gemini-pro'), findsOneWidget);
    expect(find.text('Provider: GEMINI'), findsOneWidget);
    expect(find.text('80'), findsOneWidget);
    expect(find.text('gpt-4'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('モデルテスト実行: 成功時にスコアが更新され詳細が表示されること', (WidgetTester tester) async {
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

  testWidgets('全テスト実行ボタン: 順次テストが実行されること', (WidgetTester tester) async {
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
      'benchmark': {'score': 50}
    });

    // argThatを使わず、個別に定義
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

  testWidgets('エラー系: APIエラー時にエラーメッセージが表示されること', (WidgetTester tester) async {
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

    expect(find.textContaining('API Error: 500'), findsOneWidget);
  });
}
