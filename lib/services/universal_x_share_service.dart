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
  static const int maxTweetLength = 280;
  static const String defaultHedraStartImageUrl =
      'https://my-web-app-b67f4.web.app/ogp-image-gen2-20260428.png';
  static const List<String> _creativePipeline = <String>[
    'gpt-image-2',
    'gpt-5.5',
    'seedance-2.0',
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
      'voice': _videoVoiceFor(context),
      'customPrompt': _videoPromptFor(context, draft),
      'customScript': _videoScriptFor(context, draft),
      'customHashtags': draft.hashtags,
      'preferredModel': 'seedance-2.0',
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
    final mainText = linkInReply
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
    return UniversalXShareDraft(
      text: sanitizeTweet(
        _growthTextFor(
          context,
          variant,
          url,
          trendTopics: trendTopics,
        ),
        url: url,
      ),
      imagePrompt:
          'A sophisticated adult AI executive secretary for "$title", intelligent and elegant, subtly glamorous but brand-safe, tasteful dark suit, premium futuristic office, holographic Flutter web app dashboards, AI assistant, AI University, notes, finance, work logs, English learning, cinematic lighting, no nudity, no explicit sexualization, 16:9, no text overlays.',
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
GPT image2 → GPT-5.5 → Seedance 2.0

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
          ? 'A 16:9 moving smartphone app UX validation key visual for "My Finance", Japanese personal finance app, asset dashboard, spending review, KPI cards, tap gestures, clean fintech UI, no text overlays.'
          : 'A clean 16:9 product screenshot style hero image for "$title", Flutter web app UI, crisp dashboard details, no text overlays, modern Japanese productivity app, bright and trustworthy.',
      videoPrompt: isFinanceUx
          ? 'A short moving smartphone app UX validation video for "My Finance", showing a Japanese mobile finance app flow with assets, spending, KGI/CSF/KPI, and an improvement loop. Creative pipeline: GPT image2 -> GPT-5.5 -> Seedance 2.0.'
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
    final topicLine = names.isEmpty
        ? 'AI仕事OS、学習、仕事ログ、情報整理'
        : names.map((name) => '「$name」').join(' ');
    return '''
デイリーブリーフィング — $date 朝
Xで伸びている論点を、AI仕事OS開発者の視点で整理します。

今日の入口: $topicLine
最後に、$title で試している「情報を残して使う」仕組みも共有します。
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
        ? '- For finance routes, frame this as 動くスマホアプリUX検証動画「マイファイナンス」 and mention GPT image2 -> GPT-5.5 -> Seedance 2.0 when natural.'
        : '';
    return '''
You are a Japanese build-in-public growth strategist.
Create one X sharing package for the current page of a Flutter Web app.
Primary goal: get one real first user from X to try the site and leave feedback.
Secondary goal: earn useful impressions without sounding like spam.

Return valid JSON only:
{
  "text": "Japanese X post under 280 chars, must include $shareUrl",
  "threadReplies": ["0 to 6 Japanese reply posts, each under 280 chars"],
  "imagePrompt": "English prompt for a 16:9 share image, no text overlay",
  "videoPrompt": "English prompt for a short presenter/share video",
  "hashtags": ["#buildinpublic", "#FlutterWeb", "#Supabase"]
}

Page:
- title: ${context.title}
- route: ${context.routePath}
- canonicalUrl: ${context.url}
- shareUrlWithUtm: $shareUrl

Current X trends from Japan:
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
- If using X trends, do not invent news facts. You may say a topic is trending, but only turn it into analysis, questions, and workflow implications unless source snippets are provided.
- Prefer conversation hooks and save-worthy analysis over hashtags.
- Keep the lead post under 280 chars. Use threadReplies for the briefing body.
- Treat the creative workflow as GPT image2 -> GPT-5.5 -> Seedance 2.0.
- Keep the post natural, concise, and credible.
$financeRule

Fallback style:
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

  static String _videoVoiceFor(UniversalSharePageContext context) {
    return _isMyFinanceUxContext(context) ? 'ja-JP' : 'ai_secretary_female';
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
    return '''
High-end 16:9 cinematic key visual for ${context.url}.
Main subject: an intelligent adult female AI executive secretary, refined feminine presence, confident warm expression, tasteful dark suit, premium SaaS cockpit, brand-safe.
Show concrete product context around her: Site Guide AI, AI secretary, AI University, notes, asset management, English reading dashboard, release notes, and supporter checkout as holographic UI panels.
Avoid generic landing-page mockups, random English marketing text, text overlays, nudity, explicit sexualization, or a masculine presenter.
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
      return '''
High-quality 16:9 product tour video for ${context.url}.
Presenter: an intelligent, elegant adult female AI executive secretary in a tasteful dark suit.
Voice: polished feminine Japanese voice, warm and professional, matching the secretary's face and lip movement.
Tone: premium, calm, confident, brand-safe, no nudity, no explicit sexualization.
Visual direction: image-gen2 creates a polished female secretary/key visual, GPT-5.5 structures the explanation, ElevenLabs provides the feminine voice, Hedra turns the secretary into a presenter, and Seedance 2.0 style motion adds refined UI cutaways.
Show concrete product surfaces: site guide AI, AI secretary, AI University, notes, asset management, English reading dashboard, release notes, and supporter checkout.
Make it feel like a smart SaaS concierge explaining the site in detail to a first-time visitor.
${draft.videoPrompt}
'''
          .trim();
    }
    return '''
Moving smartphone app UX validation video for "My Finance".
Use the actual product context from ${context.url}.
Show a Japanese mobile finance app flow: assets, spending, KGI/CSF/KPI, waste reduction, and an improvement loop.
Creative pipeline: GPT image2 -> GPT-5.5 -> Seedance 2.0.
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
    return [
      'はじめまして。知的で上品なAI秘書が、このサイトの使い方を案内します。',
      '最初に「サイト案内AI」へ聞けば、どの機能から開くべきか迷わず始められます。',
      'AI大学では、主要AI企業、最新ニュース、プロンプト活用を体系的に学べます。',
      'ノート、仕事ログ、資産管理、英語学習、リリースノートを1つの作業空間でつなぎます。',
      'GPT-5.5で説明を整え、image-gen2、Hedra、ElevenLabs、Seedance 2.0で動画として届けます。',
      '${context.url} を5分だけ触って、役に立つ点と迷った点を教えてください。',
    ];
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
