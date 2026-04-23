import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/edge_llm_playground_service.dart';

void main() {
  test('invoke sends edge_llm action with parsed context JSON', () async {
    Map<String, dynamic>? capturedBody;
    final service = EdgeLlmPlaygroundService(
      invoker: (body) async {
        capturedBody = body;
        return <String, dynamic>{
          'success': true,
          'provider': 'google',
          'tier': 'budget',
          'model': 'gemini-2.5-flash',
          'text': '{"status":"ok"}',
          'parsed_json': <String, dynamic>{'status': 'ok'},
          'observability': <String, dynamic>{
            'provider': 'google',
            'latency_ms': 120,
            'trace_id': 'trace-123',
          },
        };
      },
    );

    final response = await service.invoke(
      userPrompt: 'KPI を JSON で返してください',
      systemPrompt: 'JSON だけ返してください',
      provider: 'auto',
      tier: 'budget',
      responseFormat: 'json',
      contextDraft: '{"goal":"習慣化"}',
      sessionId: 'session-1',
    );

    expect(capturedBody?['action'], 'edge_llm.invoke');
    expect(capturedBody?['tier'], 'budget');
    expect(capturedBody?['context_data'], <String, dynamic>{'goal': '習慣化'});
    expect(response.provider, 'google');
    expect(response.parsedJson, <String, dynamic>{'status': 'ok'});
    expect(response.observability?.provider, 'google');
  });

  test('invoke keeps plain text context when JSON parse fails', () async {
    Map<String, dynamic>? capturedBody;
    final service = EdgeLlmPlaygroundService(
      invoker: (body) async {
        capturedBody = body;
        return <String, dynamic>{
          'success': true,
          'provider': 'openai',
          'text': '了解しました',
        };
      },
    );

    await service.invoke(
      userPrompt: '要約してください',
      contextDraft: 'これは plain text context です',
    );

    expect(capturedBody?['context_data'], 'これは plain text context です');
    expect(capturedBody?.containsKey('provider'), isFalse);
  });
}
