import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/data/services/custom_task_list_ai_service.dart';
import 'package:my_web_app/services/ai_hub_chat_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AiHubChatQuotaGuard.resetForTesting();
  });

  test('generates at least three tasks from fenced JSON', () async {
    Map<String, dynamic>? request;
    final generator = AiCustomTaskListGenerator(
      chatService: AiHubChatService(
        invoker: (body) async {
          request = body;
          return <String, dynamic>{
            'success': true,
            'provider': 'test-provider',
            'text': '''
```json
{"tasks":[
  {"title":"荷物を部屋別に数える"},
  {"title":"不要品を3箱に分類する"},
  {"title":"引っ越し業者へ見積もりを依頼する"}
]}
```
''',
          };
        },
      ),
    );

    final result = await generator.generate(
      goal: '来週までに引っ越し準備を終える',
      situation: '平日は30分だけ使える',
    );

    expect(result.taskTitles, hasLength(3));
    expect(result.taskTitles.first, '荷物を部屋別に数える');
    expect(request?['action'], 'provider.chat_auto');
    expect(request?['routing_use_case'], 'task_planning');
    expect(request?['message'], contains('平日は30分だけ使える'));
  });

  test('rejects an AI response with fewer than three unique tasks', () {
    expect(
      () => AiCustomTaskListGenerator.parseTaskTitles(
        '{"tasks":["同じ作業","同じ作業"]}',
      ),
      throwsA(isA<CustomTaskListGenerationException>()),
    );
  });

  test('accepts string and object task shapes while removing duplicates', () {
    final tasks = AiCustomTaskListGenerator.parseTaskTitles(
      '{"tasks":["机を片付ける",{"action":"本を箱に入れる"},'
      '{"task":"床を掃除する"},{"title":"机を片付ける"}]}',
    );

    expect(tasks, <String>['机を片付ける', '本を箱に入れる', '床を掃除する']);
  });

  test('rejects oversized input before invoking AI', () async {
    var invoked = false;
    final generator = AiCustomTaskListGenerator(
      chatService: AiHubChatService(
        invoker: (_) async {
          invoked = true;
          return <String, dynamic>{};
        },
      ),
    );

    await expectLater(
      generator.generate(
        goal: List<String>.filled(501, 'x').join(),
        situation: '',
      ),
      throwsA(
        isA<CustomTaskListGenerationException>().having(
          (error) => error.message,
          'message',
          contains('500文字'),
        ),
      ),
    );
    expect(invoked, isFalse);
  });

  test('does not expose provider exception details', () async {
    final generator = AiCustomTaskListGenerator(
      chatService: AiHubChatService(
        invoker: (_) => throw StateError('provider-secret-detail'),
      ),
    );

    await expectLater(
      generator.generate(goal: '片付ける', situation: ''),
      throwsA(
        isA<CustomTaskListGenerationException>()
            .having(
              (error) => error.message,
              'message',
              contains('時間をおいて再試行'),
            )
            .having(
              (error) => error.message,
              'message',
              isNot(contains('provider-secret-detail')),
            ),
      ),
    );
  });
}
