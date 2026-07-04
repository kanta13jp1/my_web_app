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
    expect(draft.text, contains('utm_campaign=first_user_growth'));
    expect(draft.text, isNot(contains('/#/')));
    expect(draft.text.length, lessThanOrEqualTo(280));
    expect(draft.imagePrompt, contains('Gemini University'));
    expect(draft.videoPrompt, contains('Gemini University'));
  });

  test('growth draft variants include measurable X acquisition URLs', () {
    final draft = UniversalXShareService.buildGrowthDraft(
      page,
      variant: UniversalXGrowthShareVariant.questionPost,
    );

    expect(draft.source, 'growth-fallback');
    expect(draft.text, contains(page.url));
    expect(draft.text, contains('utm_source=x'));
    expect(draft.text, contains('utm_medium=ai_share'));
    expect(draft.text, contains('utm_campaign=first_user_growth'));
    expect(draft.text, contains('utm_content=question_post'));
    expect(draft.text, contains('質問です'));
    expect(draft.text, contains('一言もらえると助かります'));
    expect(draft.text, isNot(contains('繝')));
    expect(draft.text, isNot(contains('譛')));
    expect(draft.text, isNot(contains('/#/')));
    expect(draft.text.length, lessThanOrEqualTo(280));
    expect(draft.imagePrompt, contains('presenter'));
    expect(draft.imagePrompt, contains('no explicit sexualization'));
  });

  test('daily briefing draft turns X trends into a thread', () {
    final draft = UniversalXShareService.buildGrowthDraft(
      page,
      trendTopics: const [
        UniversalXTrendTopic(name: 'ワールドカップ', tweetCount: 120000),
        UniversalXTrendTopic(name: 'OpenAI', tweetCount: 42000),
        UniversalXTrendTopic(name: '日経平均', tweetCount: 18000),
      ],
    );

    expect(draft.text, contains('デイリーブリーフィング'));
    // Lead post must open with today's top headline, not a generic app blurb.
    expect(draft.text, contains('今日の注目'));
    expect(draft.text, contains('ワールドカップ'));
    expect(draft.text, isNot(contains('Xで伸びている論点')));
    expect(draft.text, contains(page.url));
    expect(draft.text, contains('utm_content=daily_briefing'));
    expect(draft.text.length, lessThanOrEqualTo(280));
    expect(draft.threadReplies.length, greaterThanOrEqualTo(4));
    expect(draft.threadReplies.first, contains('なぜ重要か'));
    expect(draft.threadReplies.first, contains('見通し'));
    expect(draft.threadReplies.first.length, lessThanOrEqualTo(280));
  });

  test('share image rotates the scene setting for dramatic variation', () {
    final draft = UniversalXShareService.buildGrowthDraft(
      page,
      trendTopics: const [UniversalXTrendTopic(name: '熊本豪雨から6年')],
    );

    // 固定オフィスでなく「舞台のローテ」+「presenterキャラのローテ」が
    // 画像プロンプトに入っていること。
    expect(draft.imagePrompt, contains('in the setting of'));
    expect(draft.imagePrompt, contains('as the friendly presenter'));
    // 安全ガード: 未成年除外・非性的が入っていること。
    expect(draft.imagePrompt, contains('no minors'));
    expect(draft.imagePrompt, contains('no explicit sexualization'));
    final hasScene = <String>[
      'broadcast news desk',
      'glass studio',
      'evening study',
      'co-working space',
      'rooftop lounge',
      'control room',
    ].any(draft.imagePrompt.contains);
    expect(hasScene, isTrue);
  });

  test('presenter character rotates across a diverse adult pool', () {
    // 異なるニュース(=異なる draft.text)で presenter が変わり得ること、
    // かつ全て成人・ブランドセーフ指定であることを確認する。
    final seenCharacters = <String>{};
    for (final topic in const [
      '熊本豪雨から6年',
      'OpenAI 新モデル発表',
      'ワールドカップ開幕',
      '株価が最高値を更新',
      '大型連休の交通情報',
    ]) {
      final draft = UniversalXShareService.buildGrowthDraft(
        page,
        trendTopics: [UniversalXTrendTopic(name: topic)],
      );
      expect(draft.imagePrompt, contains('as the friendly presenter'));
      expect(draft.imagePrompt, contains('adult'));
      expect(draft.imagePrompt, isNot(contains('child')));
      final matched = <String>[
        'secretary',
        'gyaru',
        'news anchor',
        'nurse',
        'CEO',
        'guitarist',
        'knight',
        'chef',
        'detective',
        'athlete',
        'barista',
        'librarian',
        'kimono',
        'elf',
        'android',
        'dancer',
        'idol',
        'gentleman',
      ].where(draft.imagePrompt.contains);
      seenCharacters.addAll(matched);
    }
    // 5トピックで少なくとも2種類以上の異なるキャラが登場すること。
    expect(seenCharacters.length, greaterThanOrEqualTo(2));
  });

  test('growth draft imagePrompt weaves today\'s date and trend headlines', () {
    final draft = UniversalXShareService.buildGrowthDraft(
      page,
      trendTopics: const [
        UniversalXTrendTopic(name: 'OpenAI 新モデル発表', tweetCount: 42000),
        UniversalXTrendTopic(name: 'ワールドカップ', tweetCount: 120000),
      ],
    );

    final now = DateTime.now().toUtc().add(const Duration(hours: 9));
    final date = '${now.year}/${now.month}/${now.day}';
    // 固定キービジュアルが毎回ほぼ同一で X アルゴリズムへ重複信号を送っていた
    // 問題(#3776)を解消 — 当日の日付と実ニュース見出しを画像テーマへ反映する。
    expect(draft.imagePrompt, contains('Daily edition $date'));
    expect(draft.imagePrompt, contains('OpenAI 新モデル発表'));
    // 見出しは視覚テーマへ反映するのみで、事実の捏造や画像内テキスト描画はしない。
    expect(draft.imagePrompt, contains('do not invent'));
    expect(draft.imagePrompt, contains('any on-image text'));
    // presenter はローテしつつ、ブランドセーフ指定は維持する。
    expect(draft.imagePrompt, contains('presenter'));
    expect(draft.imagePrompt, contains('no text overlays'));
  });

  test('growth draft imagePrompt still varies by date without trends', () {
    final draft = UniversalXShareService.buildGrowthDraft(page);

    final now = DateTime.now().toUtc().add(const Duration(hours: 9));
    final date = '${now.year}/${now.month}/${now.day}';
    // 見出しが無い日でも、日付だけで最低限の日替り変化を保証する。
    expect(draft.imagePrompt, contains('Daily edition $date'));
    expect(draft.imagePrompt, isNot(contains('today\'s news mood')));
  });

  test('fallback draft (no URL) weaves date and trend into imagePrompt', () {
    const emptyUrlPage = UniversalSharePageContext(
      routePath: '/gemini-university',
      title: 'Gemini University',
      url: '',
    );

    final draft = UniversalXShareService.buildFallbackDraft(
      emptyUrlPage,
      trendTopics: const [
        UniversalXTrendTopic(name: 'ITmedia 生成AI', tweetCount: 3000),
      ],
    );

    final now = DateTime.now().toUtc().add(const Duration(hours: 9));
    final date = '${now.year}/${now.month}/${now.day}';
    expect(draft.imagePrompt, contains('Daily edition $date'));
    expect(draft.imagePrompt, contains('ITmedia 生成AI'));
    expect(draft.imagePrompt, contains('product screenshot style hero image'));
  });

  test('fallback draft (no URL, finance) weaves date into finance imagePrompt',
      () {
    const emptyUrlFinance = UniversalSharePageContext(
      routePath: '/asset-management',
      title: 'Asset Management',
      url: '',
    );

    final draft = UniversalXShareService.buildFallbackDraft(emptyUrlFinance);

    final now = DateTime.now().toUtc().add(const Duration(hours: 9));
    final date = '${now.year}/${now.month}/${now.day}';
    expect(draft.imagePrompt, contains('My Finance'));
    expect(draft.imagePrompt, contains('Daily edition $date'));
  });

  test('acquisitionUrlFor preserves existing query and strips fragments', () {
    const pageWithQuery = UniversalSharePageContext(
      routePath: '/work-menu',
      title: 'Work Menu',
      url: 'https://my-web-app-b67f4.web.app/work-menu?tab=ai#ignored',
    );

    final url = UniversalXShareService.acquisitionUrlFor(
      pageWithQuery,
      content: 'Pinned Post',
    );

    expect(url, contains('tab=ai'));
    expect(url, contains('utm_source=x'));
    expect(url, contains('utm_campaign=first_user_growth'));
    expect(url, contains('utm_content=pinned_post'));
    expect(url, isNot(contains('#')));
  });

  test('generateDraft accepts JSON AI package', () async {
    String? capturedPrompt;
    final chat = AiHubChatService(
      invoker: (body) async {
        capturedPrompt = body['message']?.toString();
        return {
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
        };
      },
    );
    final service = UniversalXShareService(
      chatService: chat,
      functionInvoker: (functionName, body) async {
        if (body['action'] == 'x.performance_context') {
          return {
            'success': true,
            'promptContext':
                'Measured X performance context: best variant=daily_briefing, Winner 1 score=30000',
          };
        }
        if (body['action'] == 'x.trends') {
          return {'success': true, 'trends': []};
        }
        return {'success': true};
      },
    );

    final draft = await service.generateDraft(page);

    expect(draft.fallbackUsed, isFalse);
    expect(draft.text, contains(page.url));
    expect(draft.text, contains('utm_campaign=first_user_growth'));
    expect(draft.imagePrompt, contains('AI University'));
    expect(draft.hashtags, contains('#FlutterWeb'));
    expect(
      capturedPrompt,
      contains('Recent X analytics and A/B test feedback'),
    );
    expect(capturedPrompt, contains('best variant=daily_briefing'));
    expect(capturedPrompt, contains('utm_content=daily_briefing'));
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
    expect(capturedBody?['experimentKey'], 'x_first_user_growth_10k');
    expect(capturedBody?['variant'], 'post_to_x');
    expect(capturedBody?['promptProfile'], 'performance_context_v1');
    expect(capturedBody?['contentKind'], 'media');
  });

  test('postToX adds X acquisition URL when text has no URL', () async {
    Map<String, dynamic>? capturedBody;
    final service = UniversalXShareService(
      functionInvoker: (functionName, body) async {
        capturedBody = body;
        return {'success': true, 'posted': true};
      },
    );

    await service.postToX(context: page, text: 'First user feedback wanted');

    final text = capturedBody?['text']?.toString() ?? '';
    expect(text, contains(page.url));
    expect(text, contains('utm_campaign=first_user_growth'));
    expect(text, contains('utm_content=post_to_x'));
  });

  test('postToX can move the link to a reply thread', () async {
    Map<String, dynamic>? capturedBody;
    final service = UniversalXShareService(
      functionInvoker: (functionName, body) async {
        capturedBody = body;
        return {
          'success': true,
          'posted': true,
          'tweetId': '100',
          'replyTweetIds': ['101', '102'],
        };
      },
    );

    final result = await service.postToX(
      context: page,
      text: 'デイリーブリーフィング\n${page.url}',
      threadReplies: const ['1. 【AI】OpenAI\nなぜ重要か: 仕事の入口が変わる。'],
      linkInReply: true,
    );

    final text = capturedBody?['text']?.toString() ?? '';
    final replies = capturedBody?['replyTexts'] as List;
    expect(text, isNot(contains(page.url)));
    expect(replies.first.toString(), contains('OpenAI'));
    expect(replies.last.toString(), contains(page.url));
    expect(result.replyTweetIds, ['101', '102']);
  });

  test('buildManualShareParts moves the URL out of the lead into a reply', () {
    final parts = UniversalXShareService.buildManualShareParts(
      context: page,
      text: 'デイリーブリーフィング\n今日の注目:「テスト見出し」\n${page.url}',
      threadReplies: const ['1. 【AI】OpenAI\nなぜ重要か: 仕事の入口が変わる。'],
      linkInReply: true,
    );

    // Manual share (copy / X composer) must keep the product URL out of the
    // lead post — same contract as postToX's linkInReply path.
    expect(parts.leadText, isNot(contains(page.url)));
    expect(parts.leadText, contains('今日の注目'));
    expect(parts.replyTexts.first, contains('OpenAI'));
    expect(parts.replyTexts.last, contains(page.url));
  });

  test('buildManualShareParts keeps the URL inline when not linking in reply',
      () {
    final parts = UniversalXShareService.buildManualShareParts(
      context: page,
      text: 'ふつうの投稿\n${page.url}',
    );

    expect(parts.leadText, contains(page.url));
    expect(parts.replyTexts, isEmpty);
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
    'generateImage keeps text-only sharing available on provider failure',
    () async {
      String? capturedFunction;
      Map<String, dynamic>? capturedBody;
      final service = UniversalXShareService(
        functionInvoker: (functionName, body) async {
          capturedFunction = functionName;
          capturedBody = body;
          return {
            'success': false,
            'status': 'text_only_fallback',
            'canPostTextOnly': true,
            'errors': [
              {
                'model': 'gpt-image-1.5',
                'status': 400,
                'error': 'Billing hard limit has been reached.',
              },
            ],
          };
        },
      );

      final draft = UniversalXShareService.buildFallbackDraft(page);
      final result = await service.generateImage(context: page, draft: draft);

      expect(capturedFunction, 'media-hub');
      expect(capturedBody?['prompt'], contains('as the presenter'));
      // presenter はローテするが、未成年除外・非性的の安全ガードは全画像で必須。
      expect(capturedBody?['prompt'], contains('minors'));
      expect(capturedBody?['prompt'], contains('explicit sexualization'));
      expect(result.url, isNull);
      expect(result.status, 'text_only_fallback');
      expect(result.raw['canPostTextOnly'], isTrue);
    },
  );

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
      expect(capturedBody?['title'], 'My Finance');
      expect(capturedBody?['voice'], 'ja-JP');
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
    'generateVideo uses high-quality AI secretary site tour for general pages',
    () async {
      Map<String, dynamic>? capturedBody;
      final service = UniversalXShareService(
        functionInvoker: (functionName, body) async {
          capturedBody = body;
          return {'success': true, 'status': 'fallback_text'};
        },
      );

      final draft = UniversalXShareService.buildGrowthDraft(page);
      await service.generateVideo(
        context: page,
        draft: draft,
        imageUrl: 'https://example.com/secretary.png',
      );

      expect(capturedBody?['template'], 'ai_secretary_site_tour');
      expect(capturedBody?['voice'], 'ai_secretary_female');
      expect(capturedBody?['preferredModel'], 'seedance-2.0');
      expect(capturedBody?['creativePipeline'], const [
        'gpt-image-2',
        'gpt-5.5',
        'seedance-2.0',
      ]);
      // presenter は日替りローテ、声はそれに合わせた日本語ボイス。
      expect(capturedBody?['customPrompt'], contains('Presenter for today'));
      expect(capturedBody?['customPrompt'], contains('Japanese voice'));
      expect(capturedBody?['customPrompt'], contains('ElevenLabs'));
      expect(capturedBody?['customPrompt'], contains('Hedra'));
      // シーン/照明/カメラが日替りで変わる指示が入っていること。
      expect(capturedBody?['customPrompt'], contains('Setting for today'));
      // 安全ガード(未成年除外)が動画プロンプトにも入っていること。
      expect(capturedBody?['customPrompt'], contains('no minors'));
      final scriptLines = capturedBody?['customScript'] as List;
      final script = scriptLines.join('\n');
      // 動画スクリプトは固定ツアー定型文ではなく、日替りローテの導入 +
      // ニュース由来のブリーフィング本文 + ローテのCTA で毎回変化する。
      expect(script, isNot(contains('AI大学では主要AI企業'))); // 旧固定ツアー非含有
      expect(scriptLines.length, greaterThanOrEqualTo(3));
      expect(scriptLines.first, isNotEmpty); // 導入がある
      expect(script, isNot(contains('https://')));
      expect(script, isNot(contains(page.url)));
    },
  );

  test('video narration reflects today news and drops the fixed tour',
      () async {
    Map<String, dynamic>? capturedBody;
    final service = UniversalXShareService(
      functionInvoker: (functionName, body) async {
        capturedBody = body;
        return {'success': true, 'status': 'fallback_text'};
      },
    );

    final draft = UniversalXShareService.buildGrowthDraft(
      page,
      trendTopics: const [
        UniversalXTrendTopic(name: '九州北部で非常に激しい雨'),
        UniversalXTrendTopic(name: 'OpenAIが新モデルを発表'),
      ],
    );
    await service.generateVideo(
      context: page,
      draft: draft,
      imageUrl: 'https://example.com/secretary.png',
    );

    final scriptLines = (capturedBody?['customScript'] as List).cast<String>();
    final script = scriptLines.join('\n');
    // 当日ニュース(トレンド)が動画ナレーションに載ること。
    expect(script, contains('九州北部で非常に激しい雨'));
    // 固定のツアー定型文ではないこと。
    expect(script, isNot(contains('AI大学では主要AI企業')));
    expect(scriptLines.length, greaterThanOrEqualTo(3));
    expect(script, isNot(contains('https://')));
  });

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

  test('generateVideo prefers durable Supabase stored video URL', () async {
    final service = UniversalXShareService(
      functionInvoker: (functionName, body) async {
        return {
          'success': true,
          'videoStatus': 'complete',
          'storedVideoUrl': 'https://example.com/storage/video.mp4',
          'generatedDownloadUrl': 'https://temporary.example.com/video.mp4',
        };
      },
    );

    final draft = UniversalXShareService.buildFallbackDraft(page);
    final result = await service.generateVideo(context: page, draft: draft);

    expect(result.url, 'https://example.com/storage/video.mp4');
    expect(result.status, 'complete');
  });

  test(
    'generateVideo uses the public OGP image when no generated image exists',
    () async {
      Map<String, dynamic>? capturedBody;
      final service = UniversalXShareService(
        functionInvoker: (functionName, body) async {
          capturedBody = body;
          return {
            'success': true,
            'videoStatus': 'submitted',
            'hedraGenerationId': '123e4567-e89b-12d3-a456-426614174000',
          };
        },
      );

      final draft = UniversalXShareService.buildGrowthDraft(page);
      final result = await service.generateVideo(context: page, draft: draft);

      expect(result.status, 'submitted');
      expect(
        capturedBody?['imageUrl'],
        UniversalXShareService.defaultHedraStartImageUrl,
      );
      expect(capturedBody?['imageUrlSource'], 'page_ogp_fallback');
      expect(capturedBody?['type'], 'presenter_video');
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
