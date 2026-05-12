import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/ai_hub_chat_service.dart';
import 'package:my_web_app/services/universal_x_share_service.dart';

void main() {
  const page = UniversalSharePageContext(
    routePath: '/gemini-university',
    title: 'Gemini University',
    url: 'https://my-web-app-b67f4.web.app/gemini-university',
  );

  test('fallback draft includes clean page URL', () {
    final draft = UniversalXShareService.buildFallbackDraft(page);

    expect(draft.text, contains(page.url));
    expect(draft.text, isNot(contains('/#/')));
    expect(draft.text.length, lessThanOrEqualTo(280));
    expect(draft.imagePrompt, contains('Gemini University'));
    expect(draft.videoPrompt, contains('Gemini University'));
  });

  test('generateDraft accepts JSON AI package', () async {
    final chat = AiHubChatService(
      invoker: (_) async => {
        'success': true,
        'provider': 'groq',
        'text': '''
{
  "text": "AI大学をアップデートしました。\\n${page.url}\\n#buildinpublic #FlutterWeb",
  "imagePrompt": "16:9 product UI share image for AI University",
  "videoPrompt": "short presenter video about AI University",
  "hashtags": ["#buildinpublic", "#FlutterWeb"]
}
''',
      },
    );
    final service = UniversalXShareService(chatService: chat);

    final draft = await service.generateDraft(page);

    expect(draft.fallbackUsed, isFalse);
    expect(draft.text, contains(page.url));
    expect(draft.imagePrompt, contains('AI University'));
    expect(draft.hashtags, contains('#FlutterWeb'));
  });

  test('postToX forwards optional media URL to growth-hub', () async {
    Map<String, dynamic>? capturedBody;
    String? capturedFunction;
    final service = UniversalXShareService(
      functionInvoker: (functionName, body) async {
        capturedFunction = functionName;
        capturedBody = body;
        return {
          'success': true,
          'posted': true,
          'account': '@kanta13jp1',
          'tweetId': '456',
        };
      },
    );

    final result = await service.postToX(
      context: page,
      text: 'テスト投稿\n${page.url}',
      mediaUrl: 'https://example.com/share.png',
    );

    expect(result.posted, isTrue);
    expect(result.tweetId, '456');
    expect(capturedFunction, 'growth-hub');
    expect(capturedBody?['action'], 'x.post');
    expect(capturedBody?['mediaUrl'], 'https://example.com/share.png');
  });

  test('postToX surfaces X developer project guidance', () async {
    final service = UniversalXShareService(
      functionInvoker: (functionName, body) async {
        return {
          'success': false,
          'posted': false,
          'error': 'X API app is not enrolled for v2 posting.',
          'code': 'x_client_not_enrolled',
          'actionRequired': 'Attach the App to an X Developer Project.',
          'registrationUrl': 'https://developer.x.com/en/portal/projects',
        };
      },
    );

    expect(
      () => service.postToX(context: page, text: '繝・せ繝域兜遞ｿ\n${page.url}'),
      throwsA(
        isA<Exception>()
            .having(
              (error) => error.toString(),
              'message',
              contains('Attach the App to an X Developer Project.'),
            )
            .having(
              (error) => error.toString(),
              'registration url',
              contains('https://developer.x.com/en/portal/projects'),
            ),
      ),
    );
  });

  test('postToX omits embedded data URL media', () async {
    Map<String, dynamic>? capturedBody;
    final service = UniversalXShareService(
      functionInvoker: (functionName, body) async {
        capturedBody = body;
        return {'success': true, 'posted': true};
      },
    );

    await service.postToX(
      context: page,
      text: 'Share text ${page.url}',
      mediaUrl: 'data:image/png;base64,${'a' * 3000}',
    );

    expect(capturedBody?['mediaUrl'], isNull);
  });

  test(
    'generateVideo uses My Finance mobile UX template for finance pages',
    () async {
      Map<String, dynamic>? capturedBody;
      String? capturedFunction;
      final service = UniversalXShareService(
        functionInvoker: (functionName, body) async {
          capturedFunction = functionName;
          capturedBody = body;
          return {'success': true, 'status': 'fallback_text'};
        },
      );
      const financePage = UniversalSharePageContext(
        routePath: '/asset-management',
        title: 'Asset Management',
        url: 'https://my-web-app-b67f4.web.app/asset-management',
      );
      final draft = UniversalXShareService.buildFallbackDraft(financePage);

      await service.generateVideo(
        context: financePage,
        draft: draft,
        imageUrl: 'https://example.com/share.png',
      );

      expect(capturedFunction, 'viral-video-ad-generator');
      expect(capturedBody?['template'], 'mobile_ux_validation');
      expect(capturedBody?['title'], 'マイファイナンス');
      expect(capturedBody?['preferredModel'], 'seedance-2.0');
      expect(capturedBody?['imageUrl'], 'https://example.com/share.png');
      expect(capturedBody?['creativePipeline'], const [
        'gpt-image-2',
        'gpt-5.5',
        'seedance-2.0',
      ]);
      expect(
        capturedBody?['customPrompt'],
        contains('Moving smartphone app UX validation video'),
      );
    },
  );

  test(
    'generateVideo can poll an existing Hedra generation and use download URL',
    () async {
      Map<String, dynamic>? capturedBody;
      final service = UniversalXShareService(
        functionInvoker: (functionName, body) async {
          capturedBody = body;
          return {
            'success': true,
            'videoStatus': 'complete',
            'generatedDownloadUrl': 'https://example.com/video.mp4',
          };
        },
      );

      final draft = UniversalXShareService.buildFallbackDraft(page);
      final result = await service.generateVideo(
        context: page,
        draft: draft,
        hedraGenerationId: '123e4567-e89b-12d3-a456-426614174000',
      );

      expect(result.url, 'https://example.com/video.mp4');
      expect(result.status, 'complete');
      expect(
        capturedBody?['hedraGenerationId'],
        '123e4567-e89b-12d3-a456-426614174000',
      );
    },
  );

  test('generateVideo does not forward embedded data URLs to Hedra', () async {
    String? capturedFunction;
    final service = UniversalXShareService(
      functionInvoker: (functionName, body) async {
        capturedFunction = functionName;
        return {'success': true, 'status': 'unexpected'};
      },
    );

    final draft = UniversalXShareService.buildFallbackDraft(page);
    final result = await service.generateVideo(
      context: page,
      draft: draft,
      imageUrl: 'data:image/png;base64,${'a' * 3000}',
    );

    expect(capturedFunction, isNull);
    expect(result.status, 'fallback_text');
    expect(result.raw['videoReason'], contains('public URL'));
  });

  test('isEmbeddedDataUrl detects generated inline images', () {
    expect(
      UniversalXShareService.isEmbeddedDataUrl('data:image/png;base64,abc'),
      isTrue,
    );
    expect(
      UniversalXShareService.isEmbeddedDataUrl('https://example.com/a.png'),
      isFalse,
    );
  });
}
