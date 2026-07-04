import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'ai_hub_chat_service.dart';

typedef UniversalShareFunctionInvoker = Future<Map<String, dynamic>> Function(
  String functionName,
  Map<String, dynamic> body,
);

class UniversalSharePageContext {
  final String routePath;
  final String title;
  final String url;

  const UniversalSharePageContext({
    required this.routePath,
    required this.title,
    required this.url,
  });

  factory UniversalSharePageContext.fromRouteName(String? routeName) {
    final raw = (routeName == null || routeName.trim().isEmpty)
        ? '/'
        : routeName.trim();
    final parsed = Uri.tryParse(raw);
    final path = parsed?.path.isNotEmpty == true ? parsed!.path : '/';
    final query = parsed?.query.isNotEmpty == true ? '?${parsed!.query}' : '';
    final url = 'https://my-web-app-b67f4.web.app$path$query';
    return UniversalSharePageContext(
      routePath: path,
      title: _titleFromPath(path),
      url: url,
    );
  }

  static String _titleFromPath(String path) {
    if (path == '/') return 'Home';
    final last = path.split('/').where((part) => part.isNotEmpty).lastOrNull;
    if (last == null) return 'Home';
    return last
        .split('-')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }
}

class UniversalXShareDraft {
  final String text;
  final String imagePrompt;
  final String videoPrompt;
  final List<String> hashtags;
  final List<String> threadReplies;
  final bool fallbackUsed;
  final String source;

  const UniversalXShareDraft({
    required this.text,
    required this.imagePrompt,
    required this.videoPrompt,
    required this.hashtags,
    this.threadReplies = const [],
    required this.fallbackUsed,
    required this.source,
  });

  UniversalXShareDraft copyWith({
    String? text,
    String? imagePrompt,
    String? videoPrompt,
    List<String>? hashtags,
    List<String>? threadReplies,
    bool? fallbackUsed,
    String? source,
  }) {
    return UniversalXShareDraft(
      text: text ?? this.text,
      imagePrompt: imagePrompt ?? this.imagePrompt,
      videoPrompt: videoPrompt ?? this.videoPrompt,
      hashtags: hashtags ?? this.hashtags,
      threadReplies: threadReplies ?? this.threadReplies,
      fallbackUsed: fallbackUsed ?? this.fallbackUsed,
      source: source ?? this.source,
    );
  }
}

enum UniversalXGrowthShareVariant {
  dailyBriefing,
  pinnedPost,
  problemPost,
  featurePost,
  questionPost,
  usefulReply,
}

class UniversalXMediaResult {
  final String? url;
  final String status;
  final Map<String, dynamic> raw;

  const UniversalXMediaResult({
    required this.url,
    required this.status,
    required this.raw,
  });
}

class UniversalXPostResult {
  final bool posted;
  final String? account;
  final String? tweetId;
  final String? replyTweetId;
  final List<String> replyTweetIds;
  final Map<String, dynamic> raw;

  const UniversalXPostResult({
    required this.posted,
    this.account,
    this.tweetId,
    this.replyTweetId,
    this.replyTweetIds = const [],
    this.raw = const {},
  });
}

class UniversalXTrendTopic {
  final String name;
  final int? tweetCount;

  const UniversalXTrendTopic({required this.name, this.tweetCount});
}

class UniversalXShareService {
  // X Premium(認証済みアカウント)は最大25,000字の長文ポストが可能。280字で切らない。
  static const int maxTweetLength = 25000;
  static const String defaultHedraStartImageUrl =
      'https://my-web-app-b67f4.web.app/ogp-image-gen2-20260428.png';
  // 実際に使うツール(嘘のパイプラインにしない): 文章=GPT-5.5 / 画像=GPT image /
  // 音声=ElevenLabs / 動画=Hedra。
  static const List<String> _creativePipeline = <String>[
    'gpt-5.5',
    'gpt-image',
    'elevenlabs',
    'hedra',
  ];

  final SupabaseClient? _supabase;
  final AiHubChatService _chatService;
  final UniversalShareFunctionInvoker? _functionInvoker;

  UniversalXShareService({
    SupabaseClient? supabase,
    AiHubChatService? chatService,
    UniversalShareFunctionInvoker? functionInvoker,
  })  : _supabase = supabase,
        _chatService = chatService ?? AiHubChatService(supabase: supabase),
        _functionInvoker = functionInvoker;

  Future<UniversalXShareDraft> generateDraft(
    UniversalSharePageContext context,
  ) async {
    final trends = await _fetchXTrendTopics();
    final performanceContext = await _fetchXPerformanceContext();
    final shareContent = _recommendedShareContent(trends, performanceContext);
    final fallback = buildFallbackDraft(context, trendTopics: trends);
    final shareUrl = acquisitionUrlFor(context, content: shareContent);
    try {
      final response = await _chatService.sendAutoChat(
        tier: 'free',
        sessionId: 'universal-x-share',
        message: _buildDraftPrompt(
          context,
          fallback,
          trendTopics: trends,
          performanceContext: performanceContext,
          shareUrlOverride: shareUrl,
        ),
      );
      final parsed = _parseDraft(
        response.text,
        context,
        fallback,
        shareUrl: shareUrl,
      );
      if (_isUsableText(parsed.text, shareUrl)) {
        return parsed.copyWith(fallbackUsed: false, source: response.source);
      }
    } catch (_) {
      // The global share button must remain usable even when AI routing fails.
    }
    return fallback;
  }

  Future<UniversalXMediaResult> generateImage({
    required UniversalSharePageContext context,
    required UniversalXShareDraft draft,
  }) async {
    final data = await _invoke('media-hub', {
      'action': 'image.generate',
      'prompt': _imagePromptFor(context, draft),
      'size': '1792x1024',
      'style': 'vivid',
      'preferredModel': 'gpt-image-2',
      'creativePipeline': _creativePipeline,
      'source': 'universal_x_share',
      'route': context.routePath,
    });
    return UniversalXMediaResult(
      url: _extractNestedUrl(data),
      status: data['status']?.toString() ??
          (data['success'] == true ? 'ready' : 'text_only_fallback'),
      raw: data,
    );
  }

  Future<UniversalXMediaResult> generateVideo({
    required UniversalSharePageContext context,
    required UniversalXShareDraft draft,
    String? imageUrl,
    String? hedraGenerationId,
  }) async {
    final normalizedImageUrl = _emptyToNull(imageUrl);
    if (normalizedImageUrl != null && !_isPublicHttpUrl(normalizedImageUrl)) {
      return const UniversalXMediaResult(
        url: null,
        status: 'fallback_text',
        raw: {
          'videoReason':
              'Hedra avatar image must be a public URL. Regenerate the share image so it can be stored before video generation.',
        },
      );
    }
    final hedraStartImageUrl =
        normalizedImageUrl ?? hedraStartImageUrlFor(context);
    final requestBody = <String, dynamic>{
      'type': 'presenter_video',
      'template': _videoTemplateFor(context),
      'lang': 'ja',
      'title': _shareTitleFor(context),
      'voice': _videoVoiceFor(context, draft),
      'customPrompt': _videoPromptFor(context, draft),
      'customScript': _videoScriptFor(context, draft),
      'customHashtags': draft.hashtags,
      'preferredModel': 'hedra',
      'creativePipeline': _creativePipeline,
      'source': 'universal_x_share',
      'route': context.routePath,
      'imageUrl': hedraStartImageUrl,
      'imageUrlSource':
          normalizedImageUrl == null ? 'page_ogp_fallback' : 'generated_image',
    };
    final normalizedGenerationId = _emptyToNull(hedraGenerationId);
    if (normalizedGenerationId != null) {
      requestBody['hedraGenerationId'] = normalizedGenerationId;
    }
    final data = await _invoke('viral-video-ad-generator', requestBody);
    final url = data['storedVideoUrl']?.toString() ??
        data['generatedVideoUrl']?.toString() ??
        data['generatedDownloadUrl']?.toString() ??
        data['generatedPreviewUrl']?.toString() ??
        data['videoUrl']?.toString() ??
        data['downloadUrl']?.toString() ??
        data['url']?.toString();
    return UniversalXMediaResult(
      url: _emptyToNull(url),
      status: data['videoStatus']?.toString() ??
          data['status']?.toString() ??
          'unknown',
      raw: data,
    );
  }

  Future<UniversalXPostResult> postToX({
    required UniversalSharePageContext context,
    required String text,
    String? mediaUrl,
    List<String> threadReplies = const [],
    bool linkInReply = false,
    bool dryRun = false,
  }) async {
    final normalizedMediaUrl = _emptyToNull(mediaUrl);
    final parts = buildManualShareParts(
      context: context,
      text: text,
      threadReplies: threadReplies,
      linkInReply: linkInReply,
    );
    final mainText = parts.leadText;
    final textUrl = parts.textUrl;
    final replyTexts = parts.replyTexts;
    final data = await _invoke('growth-hub', {
      'action': 'x.post',
      'text': mainText,
      if (replyTexts.isNotEmpty) 'replyTexts': replyTexts,
      'mediaUrl':
          normalizedMediaUrl != null && _isPublicHttpUrl(normalizedMediaUrl)
              ? normalizedMediaUrl
              : null,
      'dryRun': dryRun,
      'source': 'universal_x_share',
      'route': context.routePath,
      'experimentKey': 'x_first_user_growth_10k',
      'variant': _utmContentFromUrl(textUrl) ?? 'post_to_x',
      'promptProfile': 'performance_context_v1',
      'contentKind': normalizedMediaUrl == null ? 'text' : 'media',
      'linkInReply': linkInReply,
    });
    if (data['success'] != true) {
      throw Exception(buildXPostFailureMessage(data));
    }
    return UniversalXPostResult(
      posted: data['posted'] == true,
      account: data['account']?.toString(),
      tweetId: data['tweetId']?.toString() ?? data['tweet_id']?.toString(),
      replyTweetId: data['replyTweetId']?.toString() ??
          data['reply_tweet_id']?.toString(),
      replyTweetIds: (data['replyTweetIds'] is List)
          ? (data['replyTweetIds'] as List)
              .map((entry) => entry.toString())
              .where((entry) => entry.isNotEmpty)
              .toList(growable: false)
          : const [],
      raw: data,
    );
  }

  /// Builds the lead post + reply chain exactly like [postToX] does, so the
  /// manual share paths (X web intent button, copy button, API-failure
  /// fallback) keep the product URL out of the lead post and move it to the
  /// final reply whenever [linkInReply] is true. Without this, manual posts
  /// leak the URL into the lead post and lose X impressions.
  static ({String leadText, List<String> replyTexts, String textUrl})
      buildManualShareParts({
    required UniversalSharePageContext context,
    required String text,
    List<String> threadReplies = const [],
    bool linkInReply = false,
  }) {
    final existingUrl = _firstHttpUrl(text);
    final existingUrlHasUtm = existingUrl != null &&
        existingUrl.contains(context.url) &&
        existingUrl.contains('utm_campaign=first_user_growth');
    final textUrl = existingUrlHasUtm
        ? existingUrl
        : acquisitionUrlFor(context, content: 'post_to_x');
    final baseText = existingUrl != null && existingUrl != textUrl
        ? _removeUrl(text, existingUrl)
        : text;
    final leadText = linkInReply
        ? sanitizeTweet(
            _removeUrl(baseText, textUrl),
            url: textUrl,
            requireUrl: false,
          )
        : sanitizeTweet(baseText, url: textUrl);
    final replyTexts = <String>[
      ...threadReplies
          .map((entry) => sanitizeTweet(entry, url: textUrl, requireUrl: false))
          .where((entry) => entry.trim().isNotEmpty),
      if (linkInReply)
        sanitizeTweet(
          '試せるURLはこちらです。5分だけ触って、A/B/Cか一言で返信ください。\n$textUrl',
          url: textUrl,
        ),
    ];
    return (leadText: leadText, replyTexts: replyTexts, textUrl: textUrl);
  }

  Future<List<UniversalXTrendTopic>> _fetchXTrendTopics() async {
    try {
      final data = await _invoke('growth-hub', {
        'action': 'x.trends',
        'woeid': 23424856,
        'limit': 8,
        'source': 'universal_x_share',
      });
      final rawTrends = data['trends'];
      if (data['success'] != true || rawTrends is! List) {
        return const [];
      }
      return rawTrends
          .whereType<Map>()
          .map((entry) {
            final name = entry['name']?.toString().trim() ?? '';
            final countRaw = entry['tweetCount'] ?? entry['tweet_count'];
            final count = countRaw is int
                ? countRaw
                : int.tryParse(countRaw?.toString() ?? '');
            return name.isEmpty
                ? null
                : UniversalXTrendTopic(name: name, tweetCount: count);
          })
          .whereType<UniversalXTrendTopic>()
          .take(8)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<String> _fetchXPerformanceContext() async {
    try {
      final data = await _invoke('growth-hub', {
        'action': 'x.performance_context',
        'limit': 50,
      });
      if (data['success'] == true) {
        final promptContext = data['promptContext']?.toString().trim() ?? '';
        if (promptContext.isNotEmpty) {
          return promptContext;
        }
      }
    } catch (_) {
      // Analytics should improve sharing, not block drafting.
    }
    return 'No X performance data is available yet. Start with Daily Briefing vs question-post A/B tests, then collect metrics after posting.';
  }

  static String buildXPostFailureMessage(Map<String, dynamic> data) {
    final error = data['error']?.toString().trim();
    final actionRequired = data['actionRequired']?.toString().trim();
    final registrationUrl = data['registrationUrl']?.toString().trim();
    final parts = <String>[
      if (error != null && error.isNotEmpty) error else 'X post failed',
      if (actionRequired != null && actionRequired.isNotEmpty) actionRequired,
      if (registrationUrl != null && registrationUrl.isNotEmpty)
        'Developer Portal: $registrationUrl',
    ];
    return parts.join('\n');
  }

  static String acquisitionUrlFor(
    UniversalSharePageContext context, {
    String content = 'share_dialog',
  }) {
    final uri = Uri.tryParse(context.url);
    if (uri == null || uri.scheme.isEmpty || uri.host.isEmpty) {
      return context.url;
    }
    final params = Map<String, String>.from(uri.queryParameters)
      ..['utm_source'] = 'x'
      ..['utm_medium'] = 'ai_share'
      ..['utm_campaign'] = 'first_user_growth'
      ..['utm_content'] = _utmContent(content);
    return uri.replace(queryParameters: params).removeFragment().toString();
  }

  static String hedraStartImageUrlFor(UniversalSharePageContext context) {
    return defaultHedraStartImageUrl;
  }

  static UniversalXShareDraft buildGrowthDraft(
    UniversalSharePageContext context, {
    UniversalXGrowthShareVariant variant =
        UniversalXGrowthShareVariant.dailyBriefing,
    List<UniversalXTrendTopic> trendTopics = const [],
  }) {
    final title = _shareTitleFor(context);
    final url = acquisitionUrlFor(
      context,
      content: _growthVariantContent(variant),
    );
    final text = sanitizeTweet(
      _growthTextFor(context, variant, url, trendTopics: trendTopics),
      url: url,
    );
    // 動画の主視覚(=この share 画像)が毎回同じ「AI秘書＋同じオフィス」で固定に
    // 見える問題を解消するため、presenter(人物)と舞台/照明/構図を大きくローテする。
    // seed は text.hashCode(当日ニュース/生成毎で変わる)なので、動画側 _videoPromptFor
    // と同一人物・同一舞台に揃い、生成毎に見た目が劇的に変化する。
    final scene = _dailyImageScene(text.hashCode);
    final character = _dailyPresenterCharacter(text.hashCode);
    return UniversalXShareDraft(
      text: text,
      imagePrompt:
          'Key visual with $character as the friendly presenter for "$title", in the setting of $scene, with holographic Flutter web app dashboards (site guide AI, AI University, notes, finance, work logs, English learning) as subtle background panels, cinematic lighting, adult, brand-safe, tasteful appropriate attire, no minors, no nudity, no explicit sexualization, 16:9, no text overlays. ${_dailyImageAccent(trendTopics)}',
      videoPrompt:
          'A concise presenter video inviting one real X user to try "$title", give first-user feedback, and explain where the app helps or confuses them.',
      hashtags: const ['#buildinpublic'],
      threadReplies: _growthThreadRepliesFor(
        context,
        variant,
        url,
        trendTopics: trendTopics,
      ),
      fallbackUsed: true,
      source: 'growth-fallback',
    );
  }

  static UniversalXShareDraft buildFallbackDraft(
    UniversalSharePageContext context, {
    List<UniversalXTrendTopic> trendTopics = const [],
  }) {
    if (context.url.trim().isNotEmpty) {
      return buildGrowthDraft(context, trendTopics: trendTopics);
    }
    final title = _shareTitleFor(context);
    final isFinanceUx = _isMyFinanceUxContext(context);
    final text = isFinanceUx
        ? sanitizeTweet(
            '''動くスマホアプリUX検証動画「マイファイナンス」
お金の浪費を減らすため、資産・支出・KGI/CSF/KPIを一画面で検証します。
GPT image → GPT-5.5 → ElevenLabs → Hedra

${context.url}

#AI動画 #FlutterWeb #資産管理''',
            url: context.url,
          )
        : sanitizeTweet(
            '''$title をアップデートしました。
自分株式会社の中で、今日の改善をそのまま使える形にしています。

${context.url}

#buildinpublic #FlutterWeb #Supabase''',
            url: context.url,
          );
    return UniversalXShareDraft(
      text: text,
      imagePrompt: isFinanceUx
          ? 'A 16:9 moving smartphone app UX validation key visual for "My Finance", Japanese personal finance app, asset dashboard, spending review, KPI cards, tap gestures, clean fintech UI, no text overlays. ${_dailyImageAccent(trendTopics)}'
          : 'A clean 16:9 product screenshot style hero image for "$title", Flutter web app UI, crisp dashboard details, no text overlays, modern Japanese productivity app, bright and trustworthy. ${_dailyImageAccent(trendTopics)}',
      videoPrompt: isFinanceUx
          ? 'A short moving smartphone app UX validation video for "My Finance", showing a Japanese mobile finance app flow with assets, spending, KGI/CSF/KPI, and an improvement loop. Creative pipeline: GPT image -> GPT-5.5 -> ElevenLabs -> Hedra.'
          : 'A short 16:9 presenter video concept introducing "$title" as a practical improvement in a Flutter web life-management app.',
      hashtags: isFinanceUx
          ? const ['#AI動画', '#FlutterWeb', '#資産管理']
          : const ['#buildinpublic', '#FlutterWeb', '#Supabase'],
      fallbackUsed: true,
      source: 'fallback',
    );
  }

  static String _growthTextFor(
    UniversalSharePageContext context,
    UniversalXGrowthShareVariant variant,
    String url, {
    List<UniversalXTrendTopic> trendTopics = const [],
  }) {
    final title = _shareTitleFor(context);
    if (variant == UniversalXGrowthShareVariant.dailyBriefing) {
      return _dailyBriefingLead(title: title, url: url, trends: trendTopics);
    }
    final trend = _selectTrendTopic(trendTopics);
    if (trend != null) {
      return _trendAwareGrowthText(title: title, url: url, trend: trend);
    }
    return switch (variant) {
      UniversalXGrowthShareVariant.dailyBriefing => _dailyBriefingLead(
          title: title,
          url: url,
          trends: trendTopics,
        ),
      UniversalXGrowthShareVariant.pinnedPost => '''
最初の実ユーザーを探しています。
AIツール、学習、仕事ログを1つにまとめる個人向けAI仕事OSを作っています。
5分だけ触って、何に使えそうか/どこで迷ったか教えてください。
$url''',
      UniversalXGrowthShareVariant.problemPost => '''
AIツールが増えるほど「今日どれを何に使うか」が散らかる。
学習メモ、仕事ログ、判断材料を1画面に戻す個人向けAI仕事OSを作っています。
最初の利用者として触って感想ください。
$url''',
      UniversalXGrowthShareVariant.featurePost => '''
$title を改善中です。
学習、タスク、判断ログを1つの導線で試せる個人向けAI仕事OSです。
X経由の最初の実ユーザーを探しています。5分だけ触ってください。
$url''',
      UniversalXGrowthShareVariant.questionPost => '''
質問です。
AIツールを毎日使う人にとって、1つのダッシュボードにまとまると助かるものは何ですか？
学習ログ、仕事メモ、タスク、判断材料。試作を触って一言もらえると助かります。
$url''',
      UniversalXGrowthShareVariant.usefulReply => '''
その観点、かなり近いです。
AIツールは単体機能より「毎日どこで使うか」が散らかりがちなので、学習/仕事/判断ログを1つに戻す個人向けAI仕事OSを試作しています。
$url''',
    };
  }

  static String _dailyBriefingLead({
    required String title,
    required String url,
    required List<UniversalXTrendTopic> trends,
  }) {
    final date = _jstDateLabel();
    final names = trends
        .take(3)
        .map((trend) => trend.name)
        .where((name) => name.trim().isNotEmpty)
        .toList(growable: false);
    // Real news headlines run 40-60 chars, so keep only the single top headline
    // (clipped) in the <=280 char lead post; the rest go to thread replies.
    String clip(String value, int max) =>
        value.length <= max ? value : '${value.substring(0, max)}…';
    if (names.isEmpty) {
      return '''
デイリーブリーフィング — $date 朝
Xで伸びている論点を、AI仕事OS開発者の視点で整理します。

今日の入口: AI仕事OS、学習、仕事ログ、情報整理
最後に、$title で試している「情報を残して使う」仕組みも共有します。
$url''';
    }
    return '''
デイリーブリーフィング — $date 朝
今日の注目:「${clip(names.first, 42)}」
この話題も、$title で情報を残して使う視点から整理します。
$url''';
  }

  static List<String> _growthThreadRepliesFor(
    UniversalSharePageContext context,
    UniversalXGrowthShareVariant variant,
    String url, {
    List<UniversalXTrendTopic> trendTopics = const [],
  }) {
    if (variant != UniversalXGrowthShareVariant.dailyBriefing) {
      return const [];
    }
    final selected = trendTopics.isEmpty
        ? const <UniversalXTrendTopic>[
            UniversalXTrendTopic(name: 'AIツール'),
            UniversalXTrendTopic(name: '学習ログ'),
            UniversalXTrendTopic(name: '仕事メモ'),
          ]
        : trendTopics.take(5).toList(growable: false);
    final replies = <String>[];
    for (var index = 0; index < selected.length && index < 5; index += 1) {
      replies.add(_dailyBriefingItem(index + 1, selected[index]));
    }
    replies.add('''
なぜこの型にしているか:
単なる宣伝より、ニュースやトレンドを「後で使える判断材料」に変える投稿の方が保存・返信されやすいからです。

試作中の ${_shareTitleFor(context)} では、この整理をAI秘書/AI大学/メモに戻す導線を作っています。''');
    return replies
        .map((reply) => sanitizeTweet(reply, url: url, requireUrl: false))
        .toList(growable: false);
  }

  static String _dailyBriefingItem(int index, UniversalXTrendTopic trend) {
    final name = trend.name;
    final volume = trend.tweetCount == null
        ? ''
        : '（約${_compactCount(trend.tweetCount!)}件）';
    final category = _trendCategory(name);
    final lower = name.toLowerCase();
    if (lower.contains('worldcup') ||
        lower.contains('world cup') ||
        name.contains('ワールドカップ') ||
        name.contains('W杯') ||
        name.contains('サッカー')) {
      return '''
$index. 【$category】$name$volume
なぜ重要か: 試合中は速報、戦術、感想が一気に流れ、見返せる整理場所の差が出ます。
見通し: 試合後は「要点まとめ」「保存したい解説」「次戦の論点」が伸びやすいです。''';
    }
    if (lower.contains('ai') ||
        lower.contains('openai') ||
        lower.contains('gemini') ||
        lower.contains('claude')) {
      return '''
$index. 【$category】$name$volume
なぜ重要か: AIの話題はモデル名より「仕事で何が変わるか」に落とすと読まれます。
見通し: 次はプロンプト、権限管理、レビュー品質、課金の話に関心が移ります。''';
    }
    return '''
$index. 【$category】$name$volume
なぜ重要か: いま人が集まっている話題は、感情だけでなく次の行動や判断材料になります。
見通し: 事実、論点、生活への影響を分けて整理した投稿ほど保存されやすいです。''';
  }

  static String _trendCategory(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('worldcup') ||
        lower.contains('world cup') ||
        name.contains('ワールドカップ') ||
        name.contains('W杯') ||
        name.contains('サッカー')) {
      return 'スポーツ/国際';
    }
    if (lower.contains('ai') ||
        lower.contains('openai') ||
        lower.contains('gemini') ||
        lower.contains('claude')) {
      return 'AI・テック';
    }
    if (name.contains('選挙') ||
        name.contains('政権') ||
        name.contains('国会') ||
        name.contains('首相')) {
      return '日本政治';
    }
    if (name.contains('円') ||
        name.contains('株') ||
        name.contains('日経') ||
        name.contains('ドル')) {
      return '経済・市場';
    }
    return 'トレンド';
  }

  static String _jstDateLabel() {
    final now = DateTime.now().toUtc().add(const Duration(hours: 9));
    return '${now.year}/${now.month}/${now.day}';
  }

  /// 動画/画像の「舞台」を劇的にローテするための設定候補。presenter(女性AI秘書)は
  /// 維持しつつ、環境・照明・時間帯・構図を大きく変えることで、静止画も動画も毎回
  /// 見た目が大きく変わる。Hedra は顔を必要とするため人物シーンに限定している。
  static const List<String> _presenterScenes = <String>[
    'a sleek dawn broadcast news desk with soft sunrise light and floating holographic headline panels',
    'a modern glass studio at night with cool blue holographic panels and distant city lights',
    'a warm minimalist evening study with a single desk lamp, wooden shelves, and cozy amber tones',
    'a bright airy daytime co-working space with green plants, large windows, and a relaxed mood',
    'a premium rooftop lounge at golden hour overlooking a glowing city skyline',
    'a dynamic control room with several large live dashboards and energetic cinematic composition',
  ];

  /// [seed]（通常は draft.text.hashCode = 当日ニュースで変化）から舞台を1つ選ぶ。
  /// 画像側と動画側で同じ seed を使うことで、静止画と動画のシーンが一致する。
  static String _dailyImageScene(int seed) {
    return _presenterScenes[seed.abs() % _presenterScenes.length];
  }

  /// presenter(動画に登場する人物)をランダムに大きく変えるための候補。動画が毎回
  /// 同じ「女性AI秘書」で固定に見える問題を解消するため、ファッション/職業/創作/
  /// スポーツ/ファンタジー系の多様な人物へローテする。
  /// 安全方針: **成人のみ**(未成年は一切含めない)、ブランド安全、適切な服装、
  /// 非性的。夜職/グラビア系など性的文脈になりやすい類型は含めない。
  /// Hedra は顔を必要とするため、いずれも「顔のある人物」に限定している。
  static const List<String> _presenterCharacters = <String>[
    'a poised adult female AI executive secretary in a tasteful suit',
    'a cheerful adult gyaru-style woman with bright trendy fashion',
    'an elegant adult onee-san woman in a refined modern outfit',
    'a graceful adult ojou-sama lady in a classic tasteful dress',
    'a natural mori-girl style adult woman in soft earth-tone layers',
    'a chic adult woman in Korean-style minimal fashion',
    'a cool adult woman in sharp monochrome mode fashion',
    'a boyish short-haired adult woman in casual streetwear',
    'an adult woman in a tasteful gothic-lolita style dress',
    'a professional adult female news anchor in a smart blazer',
    'a warm adult female nurse in clean scrubs',
    'a calm adult female librarian with glasses and a cardigan',
    'a dignified adult female CEO in a tailored suit',
    'a friendly adult female cafe barista in an apron',
    'an adult female flight attendant in a neat uniform',
    'a bright adult idol-style woman in tasteful stage fashion',
    'a cool adult female rock guitarist in stylish stage attire',
    'a trendy adult K-pop-style female dancer',
    'an adult female ballet dancer in an elegant practice outfit',
    'a sporty adult female runner in athletic wear',
    'an adult female martial artist in a clean karate gi',
    'an adult female shrine maiden in traditional miko attire',
    'an adult woman in a graceful kimono',
    'a fantasy adult female knight in ornate armor',
    'a magical-girl style adult woman in a colorful brand-safe costume',
    'an adult female elf ranger with pointed ears in a woodland outfit',
    'a friendly adult android-style woman with subtle sci-fi styling',
    'a wise elderly woman with silver hair and a kind expression',
    'a fresh clean-cut adult young man with a friendly look',
    'a dandy adult gentleman in a refined suit',
    'a rugged adult man with a confident outdoorsy style',
    'a trendy adult male K-pop idol in stage fashion',
    'a cool adult male rock bandman with an edgy style',
    'an adult male chef in a crisp white uniform',
    'a professional adult male news anchor in a sharp suit',
    'a fantasy adult male knight in shining armor',
    'a mysterious adult male detective in a long coat',
    'a fit adult male athlete in sportswear',
    'a distinguished elderly man with silver hair and a warm smile',
  ];

  /// [seed]（通常は draft.text.hashCode = 当日ニュース/生成毎で変化）から presenter
  /// を1人選ぶ。画像側と動画側で同じ seed を使い、静止画と動画の人物を一致させる。
  static String _dailyPresenterCharacter(int seed) {
    return _presenterCharacters[seed.abs() % _presenterCharacters.length];
  }

  /// 当日の日付と（あれば）当日の実ニュース見出しを、画像プロンプトへ
  /// "視覚テーマのアクセント" として織り込む。固定キービジュアルが毎回ほぼ同一に
  /// なり、X アルゴリズムへ重複アカウント信号を送っていた問題を解消し、日替りで
  /// 画像が変わるようにする（テキスト側の [_trendAwareGrowthText] と同じ発想）。
  /// 見出しは文言の範囲でムード・配色に反映するのみで、ニュース事実の捏造や、
  /// 見出しを画像内テキスト／実シーンとして描画させることはしない。
  /// 見出しが無い日でも日付だけで最低限の日替り変化を保証する。
  static String _dailyImageAccent(List<UniversalXTrendTopic> trendTopics) {
    final date = _jstDateLabel();
    final names = trendTopics
        .map((trend) => trend.name.trim())
        .where((name) => name.isNotEmpty)
        .take(3)
        .toList(growable: false);
    if (names.isEmpty) {
      return 'Daily edition $date: refresh the mood for today through lighting, '
          'a seasonal color palette, and subtle composition changes, without '
          'rendering any date, headline, or text on the image.';
    }
    return 'Daily edition $date, today\'s news mood: ${names.join(' / ')}. '
        'Reflect only the general atmosphere of these topics as background '
        'palette, lighting, and abstract holographic motifs — never as literal '
        'news scenes, logos, headlines, or any on-image text, and do not invent '
        'facts beyond these words.';
  }

  static String _compactCount(int value) {
    if (value >= 10000) {
      final fixed = (value / 10000).toStringAsFixed(value >= 100000 ? 0 : 1);
      return '${fixed.replaceAll(RegExp(r'\.0$'), '')}万';
    }
    return value.toString();
  }

  static UniversalXTrendTopic? _selectTrendTopic(
    List<UniversalXTrendTopic> trends,
  ) {
    if (trends.isEmpty) return null;
    final preferred = trends.where((trend) {
      final key = trend.name.toLowerCase();
      return key.contains('worldcup') ||
          key.contains('world cup') ||
          key.contains('ワールドカップ') ||
          key.contains('w杯') ||
          key.contains('サッカー') ||
          key.contains('ai') ||
          key.contains('openai') ||
          key.contains('gemini') ||
          key.contains('claude') ||
          key.contains('notion') ||
          key.contains('仕事') ||
          key.contains('学習');
    }).toList();
    return preferred.isNotEmpty ? preferred.first : trends.first;
  }

  static String _trendAwareGrowthText({
    required String title,
    required String url,
    required UniversalXTrendTopic trend,
  }) {
    final name = trend.name;
    final lower = name.toLowerCase();
    if (lower.contains('worldcup') ||
        lower.contains('world cup') ||
        name.contains('ワールドカップ') ||
        name.contains('W杯') ||
        name.contains('サッカー')) {
      return '''
$name みたいに情報が一気に増える時、試合・ニュース・メモをどこで整理していますか？
個人用AI仕事OSで「探す/残す/見返す」を1画面に戻す実験をしています。
欲しいのは A 要約 B メモ C 後で探す どれ？
$url''';
    }
    if (lower.contains('ai') ||
        lower.contains('openai') ||
        lower.contains('gemini') ||
        lower.contains('claude')) {
      return '''
$name が話題ですが、AIツールって増えるほど「今日どれを開くか」が散らかりませんか？
個人用AI仕事OSで、学習・仕事ログ・メモを1つの入口に戻す実験をしています。
A 学習 B ログ C メモ どれから欲しい？
$url''';
    }
    return '''
$name が流れている今、情報を見たあとに「残して使う」場所が欲しくなります。
個人用AI仕事OSで、学習・仕事ログ・メモを1つの入口に戻す実験中です。
5分触るなら最初に見るのは A AI秘書 B AI大学 C メモ？
$url''';
  }

  static String _growthVariantContent(UniversalXGrowthShareVariant variant) {
    return switch (variant) {
      UniversalXGrowthShareVariant.dailyBriefing => 'daily_briefing',
      UniversalXGrowthShareVariant.pinnedPost => 'pinned_post',
      UniversalXGrowthShareVariant.problemPost => 'problem_post',
      UniversalXGrowthShareVariant.featurePost => 'feature_post',
      UniversalXGrowthShareVariant.questionPost => 'question_post',
      UniversalXGrowthShareVariant.usefulReply => 'useful_reply',
    };
  }

  static String _utmContent(String value) {
    final normalized = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return normalized.isEmpty ? 'share_dialog' : normalized;
  }

  static String? _utmContentFromUrl(String url) {
    final uri = Uri.tryParse(url);
    final value = uri?.queryParameters['utm_content']?.trim();
    return value == null || value.isEmpty ? null : _utmContent(value);
  }

  static String? _firstHttpUrl(String text) {
    final match = RegExp(r'https?://[^\s]+').firstMatch(text);
    if (match == null) return null;
    return match.group(0)?.replaceAll(RegExp(r'[.,;!?)）】」]+$'), '');
  }

  static String sanitizeTweet(
    String raw, {
    required String url,
    bool requireUrl = true,
  }) {
    var text = raw
        .replaceAll(
          RegExp(r'```(?:json|text|markdown)?', caseSensitive: false),
          '',
        )
        .replaceAll('```', '')
        .trim();
    text = text
        .split('\n')
        .map((line) => line.trimRight())
        .join('\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    text = text.replaceAll('/#/', '/').replaceAll('#/', '');
    if (requireUrl && !text.contains(url)) {
      text = '$text\n$url';
    }
    if (text.length <= maxTweetLength) return text;
    if (!requireUrl) {
      return '${text.substring(0, maxTweetLength - 1).trimRight()}…';
    }
    final tail = '\n$url';
    final budget = maxTweetLength - tail.length - 1;
    if (budget <= 0) return text.substring(0, maxTweetLength);
    final withoutUrl = text.replaceAll(url, '').trim();
    final head = withoutUrl.length <= budget
        ? withoutUrl
        : '${withoutUrl.substring(0, budget - 1).trimRight()}…';
    return '$head$tail';
  }

  static String _removeUrl(String text, String url) {
    var next = text.replaceAll(url, '').trim();
    final embeddedUrl = _firstHttpUrl(next);
    if (embeddedUrl != null &&
        embeddedUrl.contains('my-web-app-b67f4.web.app')) {
      next = next.replaceAll(embeddedUrl, '').trim();
    }
    return next.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }

  Future<Map<String, dynamic>> _invoke(
    String functionName,
    Map<String, dynamic> body,
  ) async {
    final invoker = _functionInvoker;
    if (invoker != null) {
      return invoker(functionName, body);
    }
    final client = _supabase ?? Supabase.instance.client;
    final response = await client.functions.invoke(functionName, body: body);
    final data = response.data;
    return data is Map<String, dynamic>
        ? data
        : data is Map
            ? Map<String, dynamic>.from(data)
            : <String, dynamic>{'success': false, 'message': data?.toString()};
  }

  static UniversalXShareDraft _parseDraft(
    String raw,
    UniversalSharePageContext context,
    UniversalXShareDraft fallback, {
    required String shareUrl,
  }) {
    final jsonText = raw
        .replaceAll(RegExp(r'```json', caseSensitive: false), '')
        .replaceAll('```', '')
        .trim();
    try {
      final decoded = jsonDecode(jsonText);
      if (decoded is Map<String, dynamic>) {
        final text = sanitizeTweet(
          decoded['text']?.toString() ?? fallback.text,
          url: shareUrl,
        );
        final hashtags = decoded['hashtags'] is List
            ? (decoded['hashtags'] as List)
                .map((entry) => entry.toString().trim())
                .where((entry) => entry.isNotEmpty)
                .toList()
            : fallback.hashtags;
        final rawThreadReplies = decoded['threadReplies'] is List
            ? decoded['threadReplies'] as List
            : decoded['thread'] is List
                ? decoded['thread'] as List
                : const [];
        final threadReplies = rawThreadReplies
            .map(
              (entry) => sanitizeTweet(
                entry.toString(),
                url: shareUrl,
                requireUrl: false,
              ),
            )
            .where((entry) => entry.trim().isNotEmpty)
            .take(6)
            .toList(growable: false);
        return UniversalXShareDraft(
          text: text,
          imagePrompt:
              decoded['imagePrompt']?.toString().trim().isNotEmpty == true
                  ? decoded['imagePrompt'].toString().trim()
                  : fallback.imagePrompt,
          videoPrompt:
              decoded['videoPrompt']?.toString().trim().isNotEmpty == true
                  ? decoded['videoPrompt'].toString().trim()
                  : fallback.videoPrompt,
          hashtags: hashtags,
          threadReplies:
              threadReplies.isNotEmpty ? threadReplies : fallback.threadReplies,
          fallbackUsed: true,
          source: 'ai-json',
        );
      }
    } catch (_) {
      // Fall through to treating the response as a tweet body.
    }
    return fallback.copyWith(text: sanitizeTweet(raw, url: shareUrl));
  }

  static bool _isUsableText(String text, String url) {
    return text.isNotEmpty &&
        text.length <= maxTweetLength &&
        text.contains(url) &&
        !text.contains('/#/');
  }

  static String _buildDraftPrompt(
    UniversalSharePageContext context,
    UniversalXShareDraft fallback, {
    List<UniversalXTrendTopic> trendTopics = const [],
    String performanceContext = '',
    String? shareUrlOverride,
  }) {
    final shareUrl = shareUrlOverride ?? acquisitionUrlFor(context);
    final trendContext = _formatTrendContext(trendTopics);
    final financeRule = _isMyFinanceUxContext(context)
        ? '- For finance routes, frame this as 動くスマホアプリUX検証動画「マイファイナンス」 and mention GPT image -> GPT-5.5 -> ElevenLabs -> Hedra when natural.'
        : '';
    return '''
You are a Japanese build-in-public growth strategist.
Create one X sharing package for the current page of a Flutter Web app.
Primary goal: get one real first user from X to try the site and leave feedback.
Secondary goal: earn useful impressions without sounding like spam.

Return valid JSON only:
{
  "text": "Japanese X post, a rich 400-900 char long-form lead (this account has X Premium so it is NOT limited to 280 chars), must include $shareUrl",
  "threadReplies": ["4 to 8 substantive Japanese reply posts, each 150-500 chars, forming a full briefing thread"],
  "imagePrompt": "English prompt for a 16:9 share image, no text overlay",
  "videoPrompt": "English prompt for a short presenter/share video",
  "hashtags": ["#buildinpublic", "#FlutterWeb", "#Supabase"]
}

Page:
- title: ${context.title}
- route: ${context.routePath}
- canonicalUrl: ${context.url}
- shareUrlWithUtm: $shareUrl

Today's real Japanese news headlines (verbatim from NHK / ITmedia news RSS; these are sourced snippets you MAY quote or paraphrase as today's news):
$trendContext

Recent X analytics and A/B test feedback:
${performanceContext.trim().isEmpty ? 'No measured performance context yet.' : performanceContext}

Rules:
- Do not use hash routing. The URL must not contain # or /#/.
- Make the copy specific to this page and useful for a stranger on X.
- Ask for a low-friction first action: try for 5 minutes and say what helped or confused them.
- Do not ask for payment, promise revenue, or imply Stripe payout readiness.
- Prefer concrete pain, feature, or question hooks over generic app promotion.
- Target 10K impressions by using the user's proven Daily Briefing style when trend context is strong: numbered items, headline, why it matters, outlook.
- Use the measured performance context above. Prefer winning variants and avoid losing hook styles.
- A/B test only one major variable at a time: hook style, link placement, media/no-media, or thread length.
- If past results say a link in the first post underperforms, put the product URL in the final reply.
- Put information value first and product CTA last. Avoid looking like an ad in the lead post.
- The headline list above is REAL, sourced news (verbatim from NHK / ITmedia RSS). You MAY quote or paraphrase a headline as today's news. Do NOT add facts beyond the headline wording, and do NOT invent numbers, quotes, or outcomes.
- When headlines are present, OPEN the lead post by tying today's single most relevant headline to this app's angle (information organization / AI work OS), so the post visibly changes every day. Do not lead with a generic app description.
- Every day's post must read as fresh and specific: pick a different concrete headline or angle rather than repeating yesterday's template.
- Prefer conversation hooks and save-worthy analysis over hashtags.
- This X account has X Premium, so the lead post is NOT limited to 280 chars. Write a rich long-form lead of roughly 400-900 chars: a headline, 2-4 concrete news points with brief analysis, and a low-friction CTA. Do not compress it into one short sentence.
- Provide a FULL briefing thread: 5-8 substantive threadReplies that each add real analysis (状況/背景/なぜ重要か/仕事への活かし方/次の一手), not one-liners.
- Treat the creative workflow as GPT image -> GPT-5.5 -> ElevenLabs -> Hedra.
- Keep the post natural, concise, and credible.
$financeRule

Emergency fallback only (DO NOT copy this verbatim; write fresh copy that leads with today's news. Use it only as a rough tone/length reference):
${fallback.text}
''';
  }

  static String _formatTrendContext(List<UniversalXTrendTopic> trends) {
    if (trends.isEmpty) {
      return '- No X trend data available. Use evergreen AI/work/productivity briefing angles.';
    }
    return trends.take(8).map((trend) {
      final count = trend.tweetCount == null
          ? ''
          : ' (${_compactCount(trend.tweetCount!)} posts)';
      return '- ${trend.name}$count';
    }).join('\n');
  }

  static String _recommendedShareContent(
    List<UniversalXTrendTopic> trends,
    String performanceContext,
  ) {
    final bestMatch = RegExp(
      r'Current best variant:\s*([a-z0-9_-]+)',
      caseSensitive: false,
    ).firstMatch(performanceContext);
    final bestVariant = bestMatch?.group(1)?.trim();
    if (bestVariant != null && bestVariant.isNotEmpty) {
      return _utmContent(bestVariant);
    }
    final lower = performanceContext.toLowerCase();
    for (final candidate in const [
      'daily_briefing',
      'question_post',
      'problem_post',
      'feature_post',
      'pinned_post',
      'useful_reply',
    ]) {
      if (lower.contains(candidate)) return candidate;
    }
    if (trends.isNotEmpty) return 'daily_briefing';
    return 'share_dialog';
  }

  static bool _isMyFinanceUxContext(UniversalSharePageContext context) {
    final key = '${context.routePath} ${context.title}'.toLowerCase();
    return key.contains('asset-management') ||
        key.contains('money-forward') ||
        key.contains('cfo-office') ||
        key.contains('finance') ||
        context.title.contains('資産') ||
        context.title.contains('財務') ||
        context.title.contains('家計');
  }

  static String _shareTitleFor(UniversalSharePageContext context) {
    if (_isMyFinanceUxContext(context)) return 'My Finance';
    return context.title;
  }

  static String _videoTemplateFor(UniversalSharePageContext context) {
    return _isMyFinanceUxContext(context)
        ? 'mobile_ux_validation'
        : 'ai_secretary_site_tour';
  }

  static String _videoVoiceFor(
    UniversalSharePageContext context,
    UniversalXShareDraft draft,
  ) {
    if (_isMyFinanceUxContext(context)) return 'ja-JP';
    // 動画の presenter(人物)が男女ローテするので、ナレーション音声もその性別に
    // 合わせる(男性キャラなのに女性の声、という不一致を解消)。画像/動画と同一 seed。
    final character = _dailyPresenterCharacter(draft.text.hashCode);
    return _isMalePresenter(character) ? 'male_narrator' : 'female_narrator';
  }

  /// presenter キャラ文字列から男性かどうかを判定する。プールの女性エントリは
  /// 必ず female / woman / lady のいずれかを含み、男性エントリは含まない。
  static bool _isMalePresenter(String character) {
    final c = character.toLowerCase();
    final isFemale =
        c.contains('female') || c.contains('woman') || c.contains('lady');
    return !isFemale;
  }

  static String _imagePromptFor(
    UniversalSharePageContext context,
    UniversalXShareDraft draft,
  ) {
    if (_isMyFinanceUxContext(context)) {
      return '''
High-quality 16:9 moving-app key visual for ${context.url}.
Subject: a clean Japanese personal finance product surface, asset dashboard, spending review, KPI cards, and tap gestures.
Style: crisp fintech SaaS UI, trustworthy, premium, realistic app details, no text overlays.
Supporting prompt:
${draft.imagePrompt}
'''
          .trim();
    }
    final scene = _dailyImageScene(draft.text.hashCode);
    final character = _dailyPresenterCharacter(draft.text.hashCode);
    return '''
High-end 16:9 cinematic key visual for ${context.url}.
Main subject: $character as the presenter, adult, brand-safe, tasteful appropriate attire, confident warm expression, in the setting of $scene.
Rotate the character, setting, lighting, wardrobe, and camera angle so each day's key visual looks dramatically different.
Show concrete product context around them as subtle holographic UI panels: Site Guide AI, AI secretary, AI University, notes, asset management, English reading dashboard, release notes, and supporter checkout.
Strictly avoid minors, nudity, explicit sexualization, text overlays, and random English marketing text.
Supporting prompt:
${draft.imagePrompt}
'''
        .trim();
  }

  static String _videoPromptFor(
    UniversalSharePageContext context,
    UniversalXShareDraft draft,
  ) {
    if (!_isMyFinanceUxContext(context)) {
      // シーン/照明/カメラを日替りローテし、当日の話題も差し込むことで、Hedra の
      // enhance_prompt が毎回異なる背景・動きの動画を生成する(=見た目も劇的に変化)。
      // 舞台は開始画像(share画像)と同一 seed(draft.text.hashCode)で選ぶため、
      // 静止画と動画のシーンが一致し、全体として一貫して大きく変わる。
      final scene = _dailyImageScene(draft.text.hashCode);
      final character = _dailyPresenterCharacter(draft.text.hashCode);
      final topic = _topNewsTopicFor(draft);
      final topicLine = topic.isEmpty
          ? ''
          : 'Weave in a subtle visual nod to today\'s topic: "$topic".';
      return '''
High-quality 16:9 product tour video for ${context.url}.
Setting for today: $scene. Change the composition, lighting, and camera movement so each day's video looks visibly different.
$topicLine
Presenter for today: $character, adult, brand-safe, tasteful appropriate attire (the same presenter as the key visual).
Voice: a warm, professional Japanese voice that matches the presenter's face and lip movement.
Tone: premium, calm, confident, brand-safe, no minors, no nudity, no explicit sexualization.
Visual direction: GPT image creates the key visual, GPT-5.5 structures the explanation, ElevenLabs provides the voice, and Hedra turns the character into a talking presenter with refined UI cutaways.
Show concrete product surfaces: site guide AI, AI secretary, AI University, notes, asset management, English reading dashboard, release notes, and supporter checkout.
${draft.videoPrompt}
'''
          .trim();
    }
    return '''
Moving smartphone app UX validation video for "My Finance".
Use the actual product context from ${context.url}.
Show a Japanese mobile finance app flow: assets, spending, KGI/CSF/KPI, waste reduction, and an improvement loop.
Creative pipeline: GPT image -> GPT-5.5 -> ElevenLabs -> Hedra.
${draft.videoPrompt}
'''
        .trim();
  }

  static List<String> _videoScriptFor(
    UniversalSharePageContext context,
    UniversalXShareDraft draft,
  ) {
    if (_isMyFinanceUxContext(context)) {
      return _scriptLinesFromText(draft.text);
    }
    // 動画ナレーションを毎回「劇的に」変える。①導入(型)を draft 由来 seed で日替り
    // ローテ＋当日ニュースの話題を差し込み ②本文は LLM が当日ニュースから作った
    // threadReplies(現状/課題/解決策)を読み上げ ③締めも複数から選ぶ。固定のツアー
    // 定型文は使わない。ニュースが変われば draft.text の hashCode が変わり、導入・締め
    // も連動して変わるので、動画の印象が日替りで大きく変化する。
    final bodyLines = <String>[
      for (final reply in draft.threadReplies)
        if (_narrationLineFromReply(reply).isNotEmpty)
          _narrationLineFromReply(reply),
    ];
    final hookLines = _scriptLinesFromText(draft.text);
    final body = bodyLines.isNotEmpty ? bodyLines : hookLines;
    final topic = _topNewsTopicFor(draft);
    final seed = draft.text.hashCode.abs();

    const openings = <String>[
      '今日のニュースを、AI仕事OSの視点で手短に整理します。',
      'おはようございます。今朝の気になる話題を、仕事の段取りに引きつけて読み解きます。',
      'ニュースは追うだけで終わりがち。今日の話題を「後で使える形」に整理します。',
      '話題が多い日ほど、情報の置き場所で差が出ます。今日の要点です。',
      '今日の注目トピックを、AI仕事OS開発者の視点でまとめました。',
      '流れてくるニュースを、判断材料に変えるコツを紹介します。',
    ];
    const closings = <String>[
      '5分だけ試して、役に立った点と迷った点を教えてください。',
      'まず触ってみて、どこで役立ちそうか一言もらえると嬉しいです。',
      '気になった方は、5分だけ触って感想を返信してください。',
      '今日の情報整理、ここから始めてみませんか。',
    ];
    final opening = topic.isEmpty
        ? openings[seed % openings.length]
        : '${openings[seed % openings.length]} 今日の話題は「$topic」です。';
    final closing = closings[(seed ~/ openings.length) % closings.length];

    // ナレーションを大幅に長く・充実させる。各トピックに「なぜ重要か/どう整理するか」
    // の解説を添え、導入・締めも厚くして、短い読み上げにならないようにする。
    const commentaries = <String>[
      'この話題は、その場で眺めるだけだと流れて消えてしまいます。ノートや仕事ログに残し、AI秘書に要点を聞ける形にしておくと、明日の判断材料としてそのまま使えます。',
      'ポイントは、事実と自分への影響を分けて書き留めておくことです。AI仕事OSなら、関連するメモやタスクにその場でひも付けられます。',
      'こうしたニュースは、後から「なぜそう動いたか」を振り返れるように残しておくと、学びが積み上がっていきます。',
      '気になった論点は、AI大学の最新ニュースや主要AI企業の動きと合わせて見ると、仕事への応用先が具体的に見えてきます。',
      '情報を集めるより、集めた情報を「いつ・どこで使うか」を決めておくことが大切です。デイリー判定とAI秘書が、その一手を後押しします。',
    ];
    if (body.isNotEmpty) {
      final items = body.take(6).toList(growable: false);
      final lines = <String>[
        opening,
        'このデイリーブリーフィングでは、今日の主な話題を取り上げ、それぞれをAI仕事OSでどう整理し、明日の段取りや判断へどうつなげるかまでご紹介します。',
      ];
      for (var i = 0; i < items.length; i += 1) {
        lines.add('${i + 1}つ目のトピックです。${items[i]}');
        lines.add(commentaries[(seed + i) % commentaries.length]);
      }
      lines.addAll(<String>[
        'ニュースはその場で消費すると忘れてしまいますが、ノート、仕事ログ、資産管理、英語学習をひとつの作業空間に残しておくと、後からAI秘書に要点を聞いて、そのまま仕事の材料に変えられます。',
        'AI大学では、主要なAI企業の動きや最新ニュース、プロンプトの活用法を体系的に学べるので、こうした話題を自分の仕事にどう応用するかまで踏み込めます。',
        'サイト案内AIに「今日はどこから始めればいい?」と聞けば、迷わず必要な機能へ進めます。まずは軽く触ってみてください。',
        closing,
      ]);
      return lines;
    }
    return <String>[
      opening,
      'AI仕事OSは、学習、仕事ログ、資産管理、英語学習、メモを、ひとつの作業空間にまとめて整理できるツールです。',
      'バラバラのアプリを行き来する代わりに、必要な情報を一か所に残し、AI秘書に要点を聞ける形にしておけます。',
      'AI大学では最新のAIニュースや主要企業の動き、プロンプト活用を体系的に学べます。',
      'サイト案内AIに聞けば、どの機能から始めればいいか迷いません。',
      closing,
    ];
  }

  /// draft から動画で強調する「今日の話題」を短く1つ取り出す。
  /// リード文の「…:「見出し」」やトレンド名を優先。
  static String _topNewsTopicFor(UniversalXShareDraft draft) {
    final quoted = RegExp(r'「([^」]{2,40})」').firstMatch(draft.text);
    if (quoted != null) {
      final topic = quoted.group(1)!.trim();
      if (!topic.contains('情報を残して使う')) return topic;
    }
    for (final reply in draft.threadReplies) {
      final line = _narrationLineFromReply(reply);
      if (line.length >= 6) {
        return line.length > 34 ? '${line.substring(0, 34)}…' : line;
      }
    }
    return '';
  }

  /// スレッド返信(例: "1. 現在の状況: 九州北部で激しい雨…" や
  /// "1. 【AI】OpenAI\nなぜ重要か:…")を、読み上げやすい1行の話し言葉に整形する。
  /// 番号/カテゴリ接頭辞を除き、URL 行はナレーションに載せない。
  static String _narrationLineFromReply(String reply) {
    final firstLine = reply
        .split('\n')
        .map((line) => line.trim())
        .firstWhere((line) => line.isNotEmpty, orElse: () => '');
    if (firstLine.isEmpty || firstLine.startsWith('http')) return '';
    return firstLine
        .replaceFirst(RegExp(r'^\d+[.)]\s*'), '')
        .replaceFirst(RegExp(r'^【[^】]*】\s*'), '')
        .trim();
  }

  static List<String> _scriptLinesFromText(String text) {
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.startsWith('#'))
        .where((line) => !line.startsWith('https://'))
        .take(5)
        .toList();
    return lines.isEmpty ? const ['ページの改善内容を紹介します。'] : lines;
  }

  static Map<String, dynamic> _asMap(Object? value) {
    return value is Map<String, dynamic>
        ? value
        : value is Map
            ? Map<String, dynamic>.from(value)
            : <String, dynamic>{};
  }

  static String? _extractNestedUrl(Map<String, dynamic> data) {
    final image = _asMap(data['image']);
    final metadata = _asMap(image['metadata']);
    return _emptyToNull(
      data['url']?.toString() ??
          metadata['url']?.toString() ??
          image['url']?.toString(),
    );
  }

  static String? _emptyToNull(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  static bool isEmbeddedDataUrl(String? value) {
    return value?.trimLeft().toLowerCase().startsWith('data:') == true;
  }

  static bool _isPublicHttpUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty &&
        value.length <= 2083;
  }
}
