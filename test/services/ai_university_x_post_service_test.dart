import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/ai_hub_chat_service.dart';
import 'package:my_web_app/services/ai_university_x_post_service.dart';

void main() {
  const metrics = AiUniversityXPostMetrics(
    correctAnswers: 6,
    totalQuestions: 39,
    providerCount: 39,
    currentStreak: 2,
  );

  test('fallback post uses clean gemini-university URL', () {
    final text = AiUniversityXPostService.buildFallbackLearningPost(metrics);

    expect(text, contains('AI大学で 6/39 問正解'));
    expect(text, contains(AiUniversityXPostService.defaultUrl));
    expect(text, isNot(contains('/#/')));
    expect(text, isNot(contains('#/gemini-university')));
    expect(text.length, lessThanOrEqualTo(280));
  });

  test('generateLearningPost uses AI output when it is valid', () async {
    final chat = AiHubChatService(
      invoker: (_) async => {
        'success': true,
        'provider': 'groq',
        'text': '''
```text
AI大学で 6/39 問正解
今日はモデル間の設計思想の違いを整理。
${AiUniversityXPostService.defaultUrl}
#AILearning #buildinpublic #FlutterWeb
```
''',
      },
    );
    final service = AiUniversityXPostService(chatService: chat);

    final result = await service.generateLearningPost(metrics);

    expect(result.fallbackUsed, isFalse);
    expect(result.text, isNot(contains('```')));
    expect(result.text, contains(AiUniversityXPostService.defaultUrl));
  });

  test('generateAndPostLearningUpdate publishes generated text', () async {
    String? publishedText;
    bool? publishedDryRun;
    final chat = AiHubChatService(
      invoker: (_) async => {
        'success': true,
        'provider': 'groq',
        'text':
            'AI大学で 6/39 問正解\n${AiUniversityXPostService.defaultUrl}\n#AILearning #buildinpublic #FlutterWeb',
      },
    );
    final service = AiUniversityXPostService(
      chatService: chat,
      publisher: ({required text, required dryRun}) async {
        publishedText = text;
        publishedDryRun = dryRun;
        return {
          'success': true,
          'posted': true,
          'account': '@kanta13jp1',
          'tweetId': '123',
        };
      },
    );

    final result = await service.generateAndPostLearningUpdate(
      metrics: metrics,
      dryRun: true,
    );

    expect(result.posted, isTrue);
    expect(result.tweetId, '123');
    expect(publishedDryRun, isTrue);
    expect(publishedText, result.text);
  });
}
