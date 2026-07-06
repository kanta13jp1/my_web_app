import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'ai_hub_chat_service.dart';

typedef UniversalShareFunctionInvoker = Future<Map<String, dynamic>> Function(
  String functionName,
  Map<String, dynamic> body,
);

/// GET ?view=history 用の注入可能フェッチャ(テストシーム)。既存の POST 専用
/// [UniversalShareFunctionInvoker] とそのモック群を変更しないための追加シーム。
typedef UniversalShareHistoryFetcher = Future<List<Map<String, dynamic>>>
    Function();

/// 静止画降格の代わりに再利用する過去生成動画。
class ReusableShareVideo {
  final String url;
  final DateTime createdAtJst;
  final bool captioned;
  final bool sameDay;

  const ReusableShareVideo({
    required this.url,
    required this.createdAtJst,
    required this.captioned,
    required this.sameDay,
  });

  String get dateLabel => '${createdAtJst.month}/${createdAtJst.day}';
}

class _ReusableVideoCandidate {
  final String url;
  final DateTime createdAtJst;
  final bool captioned;
  final bool sameDay;
  final bool templateMatch;
  final bool hasExplicitDate;

  const _ReusableVideoCandidate({
    required this.url,
    required this.createdAtJst,
    required this.captioned,
    required this.sameDay,
    required this.templateMatch,
    required this.hasExplicitDate,
  });

  // 同日 > 字幕焼き込み済 > 同テンプレ > 日付入り台本でない、の優先度。
  int get score =>
      (sameDay ? 8 : 0) +
      (captioned ? 4 : 0) +
      (templateMatch ? 2 : 0) +
      (hasExplicitDate ? 0 : 1);
}

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

/// ネイティブ X 投票(H7 / impressions ブースター)。
/// [question] は投票を載せる最初のリプライ本文になり、[options] は 2〜4 個・
/// 各<=25 文字、[durationMinutes] は 5〜10080 分。null のドラフトは従来と完全に
/// 同一の投稿になる(additive / default-off)。
class UniversalXPoll {
  final String question;
  final List<String> options;
  final int durationMinutes;

  const UniversalXPoll({
    required this.question,
    required this.options,
    this.durationMinutes = 1440,
  });
}

class UniversalXShareDraft {
  final String text;
  final String imagePrompt;
  final String videoPrompt;
  final List<String> hashtags;
  final List<String> threadReplies;
  final UniversalXPoll? poll;
  final bool fallbackUsed;
  final String source;

  const UniversalXShareDraft({
    required this.text,
    required this.imagePrompt,
    required this.videoPrompt,
    required this.hashtags,
    this.threadReplies = const [],
    this.poll,
    required this.fallbackUsed,
    required this.source,
  });

  UniversalXShareDraft copyWith({
    String? text,
    String? imagePrompt,
    String? videoPrompt,
    List<String>? hashtags,
    List<String>? threadReplies,
    UniversalXPoll? poll,
    bool? fallbackUsed,
    String? source,
  }) {
    return UniversalXShareDraft(
      text: text ?? this.text,
      imagePrompt: imagePrompt ?? this.imagePrompt,
      videoPrompt: videoPrompt ?? this.videoPrompt,
      hashtags: hashtags ?? this.hashtags,
      threadReplies: threadReplies ?? this.threadReplies,
      poll: poll ?? this.poll,
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
  // LLM ドラフトのリード文の妥当上限。プロンプト仕様は 400-900 字(2 倍超の
  // ヘッドルーム)。これを超える「リード」は JSON ダンプや暴走テキストの兆候
  // なので不採用にして retry/fallback へ回す。
  static const int maxLeadDraftLength = 2000;
  static const String defaultHedraStartImageUrl =
      'https://my-web-app-b67f4.web.app/ogp-image-gen2-20260428.png';
  static const String firstUserGrowthCampaign = 'first_user_growth';
  static const String aiShareMedium = 'ai_share';
  static const String profileMedium = 'profile';
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
  final UniversalShareHistoryFetcher? _historyFetcher;

  UniversalXShareService({
    SupabaseClient? supabase,
    AiHubChatService? chatService,
    UniversalShareFunctionInvoker? functionInvoker,
    UniversalShareHistoryFetcher? historyFetcher,
  })  : _supabase = supabase,
        _chatService = chatService ?? AiHubChatService(supabase: supabase),
        _functionInvoker = functionInvoker,
        _historyFetcher = historyFetcher;

  // ── 過去生成メディアの再利用 (media library reuse) ──────────────────────
  // Hedra クレジット枯渇などで新規動画が作れないとき、静止画へ降格する代わりに
  // Storage へ永続化済みの過去動画を再利用する(動画 >> 静止画 for dwell)。

  /// 再利用候補の鮮度上限。これより古い動画は舞台/UI が陳腐化しうるので静止画へ。
  static const int kVideoReuseFreshnessDays = 7;

  /// この時間内の Hedra クレジット不足失敗(以後成功なし)を検出したら、
  /// ElevenLabs TTS を含む生成経路を丸ごとスキップして再利用へ直行する。
  /// 日次ケイデンス(前回失敗が ~24h 前)を捕捉するため 24h。
  static const int kBillingPreflightTtlHours = 24;

  /// edge が永続化する日本語クレジット不足文言の安定接頭辞。
  static const String kHedraCreditsFailurePrefix = 'Hedra のクレジットが不足';

  /// Storage 永続化済み(=durable)動画 URL の判定。永続化失敗行は
  /// 期限切れしうる Hedra 一時 URL のままなので再利用しない。
  static const String kDurableVideoPathMarker = '/viral-ad-videos/';

  /// viral-video-ad-generator の GET ?view=history(最新20件・失敗行含む)を取得。
  Future<List<Map<String, dynamic>>> fetchShareVideoHistory() async {
    final fetcher = _historyFetcher;
    if (fetcher != null) return fetcher();
    final client = _supabase ?? Supabase.instance.client;
    final response = await client.functions.invoke(
      'viral-video-ad-generator',
      method: HttpMethod.get,
      queryParameters: {'view': 'history'},
    );
    final data = response.data;
    final history = data is Map ? data['history'] : null;
    if (history is! List) return const [];
    return history
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  /// 静止画降格の代わりに使う過去動画を選ぶ(候補なしなら null=従来の静止画)。
  Future<ReusableShareVideo?> fetchReusableVideo({
    required UniversalSharePageContext context,
    List<Map<String, dynamic>>? history,
    DateTime? nowUtc,
  }) async {
    try {
      final rows = history ?? await fetchShareVideoHistory();
      return selectReusableVideo(
        rows,
        nowJst:
            (nowUtc ?? DateTime.now().toUtc()).add(const Duration(hours: 9)),
        templateKey: _videoTemplateFor(context),
      );
    } catch (_) {
      return null; // ライブラリ障害時は従来の静止画フォールバックを維持。
    }
  }

  /// 再利用候補の選択(純関数)。フィルタ: video_ready / ja / durable URL /
  /// [kVideoReuseFreshnessDays] 以内。優先: 同日 > 字幕済 > 同テンプレ >
  /// 台本に明示日付なし > 新しい順。
  static ReusableShareVideo? selectReusableVideo(
    List<Map<String, dynamic>> rows, {
    required DateTime nowJst,
    required String templateKey,
  }) {
    final candidates = <_ReusableVideoCandidate>[];
    for (final row in rows) {
      if (row['status']?.toString() != 'video_ready') continue;
      if ((row['lang']?.toString() ?? 'ja') != 'ja') continue;
      final url = row['generated_video_url']?.toString() ?? '';
      if (!url.startsWith('https://')) continue;
      if (!url.contains(kDurableVideoPathMarker)) continue;
      final created = DateTime.tryParse(row['created_at']?.toString() ?? '');
      if (created == null) continue;
      final createdJst = created.toUtc().add(const Duration(hours: 9));
      final age = nowJst.difference(createdJst);
      if (age.isNegative || age.inDays >= kVideoReuseFreshnessDays) continue;
      final script = row['script']?.toString() ?? '';
      candidates.add(
        _ReusableVideoCandidate(
          url: url,
          createdAtJst: createdJst,
          captioned: url.contains('-captioned'),
          sameDay: createdJst.year == nowJst.year &&
              createdJst.month == nowJst.month &&
              createdJst.day == nowJst.day,
          templateMatch: row['template_key']?.toString() == templateKey,
          hasExplicitDate: RegExp(r'\d+月\d+日').hasMatch(script),
        ),
      );
    }
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) {
      final byScore = b.score - a.score;
      if (byScore != 0) return byScore;
      return b.createdAtJst.compareTo(a.createdAtJst);
    });
    final best = candidates.first;
    return ReusableShareVideo(
      url: best.url,
      createdAtJst: best.createdAtJst,
      captioned: best.captioned,
      sameDay: best.sameDay,
    );
  }

  /// 直近の presenter_video 試行が [kHedraCreditsFailurePrefix] を含む失敗で、
  /// [kBillingPreflightTtlHours] 以内、かつそれより新しい成功が無いとき true。
  /// true のときは生成(TTS 課金含む)を丸ごとスキップして再利用へ直行する。
  static bool shouldSkipVideoGeneration(
    List<Map<String, dynamic>> rows, {
    required DateTime nowUtc,
  }) {
    DateTime? lastBillingFail;
    DateTime? lastSuccess;
    for (final row in rows) {
      if (row['type']?.toString() != 'presenter_video') continue;
      final created =
          DateTime.tryParse(row['created_at']?.toString() ?? '')?.toUtc();
      if (created == null) continue;
      if (row['status']?.toString() == 'video_ready') {
        if (lastSuccess == null || created.isAfter(lastSuccess)) {
          lastSuccess = created;
        }
      }
      final reason = row['video_reason']?.toString() ?? '';
      if (reason.contains(kHedraCreditsFailurePrefix)) {
        if (lastBillingFail == null || created.isAfter(lastBillingFail)) {
          lastBillingFail = created;
        }
      }
    }
    if (lastBillingFail == null) return false;
    if (nowUtc.difference(lastBillingFail).inHours >=
        kBillingPreflightTtlHours) {
      return false;
    }
    if (lastSuccess != null && lastSuccess.isAfter(lastBillingFail)) {
      return false;
    }
    return true;
  }

  Future<UniversalXShareDraft> generateDraft(
    UniversalSharePageContext context,
  ) async {
    final trends = await _fetchXTrendTopics();
    final performanceContext = await _fetchXPerformanceContext();
    final shareContent = _recommendedShareContent(trends, performanceContext);
    final fallback = buildFallbackDraft(context, trendTopics: trends);
    final shareUrl = acquisitionUrlFor(context, content: shareContent);
    // 実障害(2026-07-06): ai-hub が 66 秒後に 502 → 1 回きりの試行が失敗し
    // 定型文フォールバック(スレッド定型・投票なし)へ劣化した。45 秒 timeout で
    // 失敗を早期検知し 1 回だけ再試行して LLM 経路(長文リード+多様リプ+投票)の
    // 成功率を上げる。traceId で ai_hub_chat_logs と attempt 単位の相関が可能。
    // 注意: .timeout は実行中の edge 呼び出し自体は中断しない(重複実行は許容)。
    // ai-hub 側のプロバイダ timeout 変更時はこの 45s も見直す。
    //
    // 実障害2(2026-07-07 / 2連続503の真因): ①maxTokens 未指定だと edge 既定の
    // max_tokens=512 で 2,000+ トークンの JSON が途中切断され、健全なプロバイダ
    // 応答まで finish_reason=length で全滅していた → 8192(サーバ上限)を明示。
    // ②free ティア先頭の遅延プロバイダが 45 秒予算を焼き尽くす → 収益直結の
    // この呼び出しは budget ティア開始・リトライは performance ティアへ昇格
    // (サーバ側でさらに上位ティアへの自動フォールバックが続く)。コストは
    // テキストのみ数円/投稿で、動画(Hedra)コストとは無関係。
    final traceId = 'uxs-${DateTime.now().microsecondsSinceEpoch}';
    for (var attempt = 0; attempt < 2; attempt += 1) {
      try {
        final response = await _chatService
            .sendAutoChat(
              tier: attempt == 0 ? 'budget' : 'performance',
              maxTokens: 8192,
              sessionId: 'universal-x-share',
              traceId: traceId,
              message: _buildDraftPrompt(
                context,
                fallback,
                trendTopics: trends,
                performanceContext: performanceContext,
                shareUrlOverride: shareUrl,
              ),
            )
            .timeout(const Duration(seconds: 45));
        final parsed = _parseDraft(
          response.text,
          context,
          fallback,
          shareUrl: shareUrl,
        );
        // _parseDraft は JSON ダンプを検知すると fallback インスタンスその
        // ものを返す。それを LLM 成功(fallbackUsed:false)と誤ラベルせず、
        // retry(次 attempt)へ回すため identical で除外する。
        if (!identical(parsed, fallback) &&
            _isUsableText(parsed.text, shareUrl)) {
          return parsed.copyWith(fallbackUsed: false, source: response.source);
        }
      } on Object catch (error) {
        // quota cooldown 中の再試行は確定失敗なので打ち切る。
        if (error is AiHubChatException &&
            error.message.contains('AI quota cooldown')) {
          break;
        }
        // The global share button must remain usable even when AI routing
        // fails — fall through to the retry / fallback.
      }
      if (attempt == 0) {
        await Future<void>.delayed(const Duration(seconds: 2));
      }
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
    String? altText,
    UniversalXPoll? poll,
    // 定型文フォールバックで生成した投稿かどうか。perf 計測ループが LLM 投稿と
    // フォールバック投稿を分離できるように growth-hub へ明示的に渡す。
    bool fallbackUsed = false,
  }) async {
    final normalizedMediaUrl = _emptyToNull(mediaUrl);
    final hasMedia =
        normalizedMediaUrl != null && _isPublicHttpUrl(normalizedMediaUrl);
    // アクセシビリティ用 alt text。画像がある時のみ、未指定ならページ題から既定生成。
    final String? resolvedAltText = hasMedia
        ? (_emptyToNull(altText) ?? _defaultShareAltText(context))
        : null;
    final parts = buildManualShareParts(
      context: context,
      text: text,
      threadReplies: threadReplies,
      linkInReply: linkInReply,
    );
    final mainText = parts.leadText;
    final textUrl = parts.textUrl;
    // ネイティブ投票(H7)は media を持たない最初のリプライにのみ載せられる
    // (X は poll と media の同居を禁止)。投票の質問文をスレッド先頭のリプライへ
    // 前置し、edge 側でその最初のリプライに poll を添付する。poll が無い/不正な
    // ときは replyTexts も payload も従来と完全に同一(byte-identical)にする。
    final pollPayload = _xPollPayload(poll);
    final pollQuestion = pollPayload == null || poll == null
        ? ''
        : sanitizeTweet(poll.question, url: textUrl, requireUrl: false).trim();
    final hasPoll = pollPayload != null && pollQuestion.isNotEmpty;
    final replyTexts = assembleReplyTexts(
      partsReplyTexts: parts.replyTexts,
      pollQuestion: pollQuestion,
      hasPoll: hasPoll,
      linkInReply: linkInReply,
    );
    final data = await _invoke('growth-hub', {
      'action': 'x.post',
      'text': mainText,
      if (replyTexts.isNotEmpty) 'replyTexts': replyTexts,
      'mediaUrl': hasMedia ? normalizedMediaUrl : null,
      if (resolvedAltText != null) 'altText': resolvedAltText,
      'dryRun': dryRun,
      'source': 'universal_x_share',
      'route': context.routePath,
      'experimentKey': 'x_first_user_growth_10k',
      'variant': _utmContentFromUrl(textUrl) ?? 'post_to_x',
      'promptProfile':
          fallbackUsed ? 'fallback_template_v1' : 'performance_context_v1',
      'fallbackUsed': fallbackUsed,
      'contentKind': normalizedMediaUrl == null ? 'text' : 'media',
      'linkInReply': linkInReply,
      if (hasPoll) 'poll': pollPayload,
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

  /// growth-hub x.post は replyTexts を slice(0, 8) で切り捨てる。poll 質問の
  /// 前置(+1)と URL 入り最終 CTA(+1)で 8 を超えると、サーバ側が末尾 = CTA
  /// (link-in-reply 時は投稿全体で唯一の商品 URL)を黙って落とす。クライアント
  /// 側で同じ上限を適用しつつ、溢れは末尾側の分析リプライから落として CTA を
  /// 必ず残す。合計 8 件以下のときは従来と同一のパススルー。
  static const int _serverReplyCap = 8; // growth-hub の slice(0, 8) と一致

  static List<String> assembleReplyTexts({
    required List<String> partsReplyTexts,
    required String pollQuestion,
    required bool hasPoll,
    required bool linkInReply,
  }) {
    final base = <String>[if (hasPoll) pollQuestion, ...partsReplyTexts];
    if (base.length <= _serverReplyCap) return base;
    if (linkInReply && partsReplyTexts.isNotEmpty) {
      // buildManualShareParts は linkInReply=true のとき URL 入り CTA を必ず
      // 末尾に置くので .last が CTA。溢れた分は CTA 直前の分析リプを落とす。
      final budget = _serverReplyCap - (hasPoll ? 1 : 0);
      final analysis = partsReplyTexts.sublist(0, partsReplyTexts.length - 1);
      final cta = partsReplyTexts.last;
      return <String>[
        if (hasPoll) pollQuestion,
        ...analysis.take(budget - 1),
        cta,
      ];
    }
    return base.take(_serverReplyCap).toList(growable: false);
  }

  /// Normalizes an optional [UniversalXPoll] into the growth-hub wire shape
  /// `{ options, durationMinutes }`, or null when it does not qualify as a real
  /// poll (fewer than 2 non-empty options). Options are trimmed, de-duplicated
  /// (X rejects duplicate options), capped at 4 and <=25 chars each; duration is
  /// clamped to X's 5〜10080 minute range. Returning null keeps posts
  /// byte-identical to the no-poll path.
  static Map<String, dynamic>? _xPollPayload(UniversalXPoll? poll) {
    if (poll == null) return null;
    final seen = <String>{};
    final options = <String>[];
    for (final entry in poll.options) {
      var option = entry.trim();
      if (option.isEmpty) continue;
      if (option.runes.length > 25) {
        option = String.fromCharCodes(option.runes.take(25));
      }
      if (seen.add(option)) options.add(option);
      if (options.length == 4) break;
    }
    if (options.length < 2) return null;
    var duration = poll.durationMinutes;
    if (duration < 5) duration = 5;
    if (duration > 10080) duration = 10080;
    return {'options': options, 'durationMinutes': duration};
  }

  /// URL を載せる最終リプライの CTA 文面プール。毎回同一文だと近似重複として
  /// スパム降格されやすい(=リプライも独自にインプレッションを稼ぐ)ため、
  /// text.hashCode で日替りローテする。いずれも「5分試して一言返信」の低摩擦
  /// アクションと link-in-reply を保つ。
  static const List<String> _ctaFinalReplies = <String>[
    '試せるURLはこちらです。5分だけ触って、A/B/Cか一言で返信ください。',
    '触ってみたい方はこちらへ。5分で気づいた点を一言もらえると助かります。',
    'ここから試せます。最初の1画面で迷った所があれば教えてください。',
    '実際に開けます。役に立ちそう/そうでない、どちらでも返信歓迎です。',
    'デモはこちら。5分だけ使って、続けたいと思ったか教えてください。',
    '要点は後で使えるので保存推奨。触ったら一言だけ感想ください。',
    'この投稿は保存しておくと後で効きます。使えたか一言返信歓迎です。',
  ];

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
      // linkInReply では URL を最終 CTA リプライだけに載せる。LLM が自リプへ
      // 製品 URL を含めると OG カードが複数リプで重複表示されるため剥がす。
      ...threadReplies
          .map(
            (entry) => sanitizeTweet(
              linkInReply ? _removeUrl(entry, textUrl) : entry,
              url: textUrl,
              requireUrl: false,
            ),
          )
          .where((entry) => entry.trim().isNotEmpty),
      if (linkInReply)
        sanitizeTweet(
          '${_ctaFinalReplies[text.hashCode.abs() % _ctaFinalReplies.length]}\n$textUrl',
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
    String medium = aiShareMedium,
  }) {
    final uri = Uri.tryParse(context.url);
    if (uri == null || uri.scheme.isEmpty || uri.host.isEmpty) {
      return context.url;
    }
    final params = Map<String, String>.from(uri.queryParameters)
      ..['utm_source'] = 'x'
      ..['utm_medium'] = _utmMedium(medium)
      ..['utm_campaign'] = firstUserGrowthCampaign
      ..['utm_content'] = _utmContent(content);
    return uri.replace(queryParameters: params).removeFragment().toString();
  }

  static String profileAcquisitionUrlFor(
    UniversalSharePageContext context, {
    String content = 'profile_bio',
  }) {
    return acquisitionUrlFor(context, content: content, medium: profileMedium);
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
      // LLM 失敗時のフォールバックでも投票(エンゲージメントブースター)を落と
      // さない。当日トップトレンド由来の決定論的な質問+選択肢を seed ローテ。
      poll: variant == UniversalXGrowthShareVariant.dailyBriefing
          ? _fallbackPollFor(trendTopics, text.hashCode)
          : null,
      fallbackUsed: true,
      source: 'growth-fallback',
    );
  }

  /// フォールバック用の決定論的な投票。トレンドが無い日は null(投票なし)。
  /// 質問はトップトレンド由来(~20 runes に clip)、選択肢セットは seed ローテ。
  /// 全選択肢は 25 runes 以下で `_xPollPayload` の検証を素通りする設計。
  static UniversalXPoll? _fallbackPollFor(
    List<UniversalXTrendTopic> trends,
    int seed,
  ) {
    if (trends.isEmpty) return null;
    final rawName = trends.first.name.trim();
    if (rawName.isEmpty) return null;
    final runes = rawName.runes.toList(growable: false);
    final topic = runes.length <= 20
        ? rawName
        : '${String.fromCharCodes(runes.take(20))}…';
    const optionSets = <List<String>>[
      <String>['詳しく知りたい', '様子見', '仕事に関係あり', '関係なし'],
      <String>['もう追っている', 'いま知った', '後で調べる'],
      <String>['影響ありそう', '影響なさそう', 'まだ分からない'],
      <String>['保存して整理する', '流し読みで十分', '人と話したい'],
    ];
    return UniversalXPoll(
      question: '今日の注目「$topic」、あなたは？',
      options: optionSets[seed.abs() % optionSets.length],
      durationMinutes: 1440,
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
    final names = trends
        .take(3)
        .map((trend) => trend.name)
        .where((name) => name.trim().isNotEmpty)
        .toList(growable: false);
    // Real news headlines run 40-60 chars, so keep only the single top headline
    // (clipped) in the lead post; the rest go to thread replies.
    String clip(String value, int max) =>
        value.length <= max ? value : '${value.substring(0, max)}…';
    // 1 行目は「デイリーブリーフィング — 日付 朝」のラベルではなく、フォールドより上で
    // スクロールを止める具体フックにする(=X はリード 1 行目でリーチが決まる)。日付は
    // 載せない(LLM 経路の年ハルシネーション回避 + テンプレ感低減)。
    if (names.isEmpty) {
      return '''
AIツールが増えるほど「今日どれを何に使うか」が散らかります。学習・仕事ログ・情報整理を1画面に戻す視点で整理します。

今日の入口: AI仕事OS、学習、仕事ログ、情報整理
最後に、$title で試している「情報を残して使う」仕組みも共有します。
$url''';
    }
    return '''
今日いちばん動いた話題:「${clip(names.first, 42)}」— これを「後で使える判断材料」に変える視点で整理します。
$title で情報を残して使う仕組みと一緒に、今日の論点をまとめます。
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
    // seed はスレッド全体で 1 回だけ計算して渡す(トレンド毎の seed だと同一
    // カテゴリの解説が同じ変種に揃い、リプ同士の重複が再発する)。
    final seed = selected.map((trend) => trend.name).join('|').hashCode.abs();
    final replies = <String>[];
    for (var index = 0; index < selected.length && index < 5; index += 1) {
      replies.add(_dailyBriefingItem(index + 1, selected[index], seed));
    }
    replies.add('''
なぜこの型にしているか:
単なる宣伝より、ニュースやトレンドを「後で使える判断材料」に変える投稿の方が保存・返信されやすいからです。

試作中の ${_shareTitleFor(context)} では、この整理をAI秘書/AI大学/メモに戻す導線を作っています。''');
    return replies
        .map((reply) => sanitizeTweet(reply, url: url, requireUrl: false))
        .toList(growable: false);
  }

  /// カテゴリ別の解説プール。実障害(2026-07-06): 単一テンプレだったため同一
  /// カテゴリのトレンド3件でリプ本文が完全一致(near-duplicate=スパム降格リスク+
  /// 保存価値ゼロ)。5 変種 × (index + seed) ローテで、1 スレッド(最大5件)内の
  /// pairwise 重複をゼロにする。全変種は「なぜ重要か/見通し」の2行構造を保つ。
  static const List<String> _briefingSportsPool = <String>[
    'なぜ重要か: 試合中は速報、戦術、感想が一気に流れ、見返せる整理場所の差が出ます。\n見通し: 試合後は「要点まとめ」「保存したい解説」「次戦の論点」が伸びやすいです。',
    'なぜ重要か: 熱量が高い話題ほど、感想と事実を分けて残した人が後で強くなります。\n見通し: ハイライトよりも「何が決め手だったか」の一行整理が保存されやすいです。',
    'なぜ重要か: リアルタイムの盛り上がりは数時間で流れ、翌日に残る情報は一握りです。\n見通し: 選手・采配・数字の3点で整理したメモが次戦の観戦価値を上げます。',
    'なぜ重要か: 観戦の楽しさは「前回何を見たか」を思い出せるかで大きく変わります。\n見通し: 保存した論点が多い人ほど、次の試合の予想や会話が具体的になります。',
    'なぜ重要か: スポーツの話題は共通言語になりやすく、職場の雑談や商談にも効きます。\n見通し: 結果だけでなく「なぜ勝てたか」を一言添えた投稿が読まれ続けます。',
  ];
  static const List<String> _briefingAiPool = <String>[
    'なぜ重要か: AIの話題はモデル名より「仕事で何が変わるか」に落とすと読まれます。\n見通し: 次はプロンプト、権限管理、レビュー品質、課金の話に関心が移ります。',
    'なぜ重要か: 新モデルの発表は、自分の業務フローを見直す絶好のタイミングです。\n見通し: 発表直後の感想より、1週間後の「実際どう使ったか」が価値を持ちます。',
    'なぜ重要か: AIニュースは量が多く、要点を自分の言葉で残した人だけが活かせます。\n見通し: ツール比較より「この作業をこう置き換えた」という実例が保存されます。',
    'なぜ重要か: 話題のAIも、試して合わなければ捨てる判断材料として残す価値があります。\n見通し: 導入の成否より「どこで詰まったか」の記録が次の選定を速くします。',
    'なぜ重要か: AIの進化は速く、昨日の常識が今日の非効率になることがあります。\n見通し: 定点観測のメモを持つ人が、乗り換えどきを最初に察知できます。',
  ];
  static const List<String> _briefingDefaultPool = <String>[
    'なぜ重要か: いま人が集まっている話題は、感情だけでなく次の行動や判断材料になります。\n見通し: 事実、論点、生活への影響を分けて整理した投稿ほど保存されやすいです。',
    'なぜ重要か: 大きな話題ほど一次情報と感想が混ざり、整理した人の情報が引用されます。\n見通し: 「何が起きたか」と「自分にどう関わるか」を分けたメモが後で効きます。',
    'なぜ重要か: 流れの速い話題は、翌日には検索しづらくなり、残した人だけが使えます。\n見通し: 論点を3つに絞った要約が、1週間後も参照される投稿になります。',
    'なぜ重要か: 注目の話題は判断を急がせますが、急ぐほど整理の価値が上がります。\n見通し: 感情が落ち着いた頃に「事実だけのメモ」を見返せる人が正確に動けます。',
    'なぜ重要か: 話題の賞味期限は短く、学びに変換できるかは記録の仕方で決まります。\n見通し: 出来事→影響→自分の一手、の順で書いた整理が最も再利用されます。',
  ];

  static String _dailyBriefingItem(
    int index,
    UniversalXTrendTopic trend,
    int seed,
  ) {
    final name = trend.name;
    final volume = trend.tweetCount == null
        ? ''
        : '（約${_compactCount(trend.tweetCount!)}件）';
    final category = _trendCategory(name);
    final lower = name.toLowerCase();
    final List<String> pool;
    if (lower.contains('worldcup') ||
        lower.contains('world cup') ||
        name.contains('ワールドカップ') ||
        name.contains('W杯') ||
        name.contains('サッカー')) {
      pool = _briefingSportsPool;
    } else if (lower.contains('ai') ||
        lower.contains('openai') ||
        lower.contains('gemini') ||
        lower.contains('claude')) {
      pool = _briefingAiPool;
    } else {
      pool = _briefingDefaultPool;
    }
    final commentary = pool[(index - 1 + seed) % pool.length];
    return '''
$index. 【$category】$name$volume
$commentary''';
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
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}/$month/$day';
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
    return _presenterScenes[_mixedSeedIndex(seed, _presenterScenes.length)];
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
    final index = _mixedSeedIndex(seed, _presenterCharacters.length);
    return _presenterCharacters[index];
  }

  static int _mixedSeedIndex(int seed, int length) {
    var value = seed & 0x7fffffff;
    value ^= value >> 16;
    value = (value * 0x7feb352d) & 0x7fffffff;
    value ^= value >> 15;
    value = (value * 0x846ca68b) & 0x7fffffff;
    value ^= value >> 16;
    return value % length;
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

  static String _utmMedium(String value) {
    final normalized = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return normalized.isEmpty ? aiShareMedium : normalized;
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

  /// 全体がオブジェクト/配列リテラルの文字列(=二重エンコードされた JSON や
  /// Map/List.toString() のダンプ)かどうか。先頭と末尾の両方に括弧を要求する
  /// ので、「手順は {設定→実行→確認} の3段階」のような日本語散文は落ちない。
  static bool _looksLikeSerializedObject(String s) {
    final t = s.trim();
    return (t.startsWith('{') && t.endsWith('}')) ||
        (t.startsWith('[') && t.endsWith(']'));
  }

  /// 投稿本文にしてはならない「JSON ダンプ」の指紋。実障害(2026-07-06):
  /// LLM が文字列値内に生改行を含む不正 JSON を返し、decode 失敗の生テキスト
  /// (`{\n  "text": "…`)がそのままリード本文になった。sanitizeTweet が末尾へ
  /// URL を足すため末尾 `}` を要求する既存 helper では検知できない。先頭
  /// アンカーの `{"` / `["` 形のみを弾くので、日本語散文中の括弧は誤爆しない。
  static bool _looksLikeJsonDump(String s) {
    final t = s.trim();
    return _looksLikeSerializedObject(t) || RegExp(r'^[\{\[]\s*"').hasMatch(t);
  }

  /// 不正 JSON の最頻パターン=文字列リテラル内の生制御文字(改行/タブ等)を
  /// エスケープして修復する。引用符状態(バックスラッシュエスケープ考慮)を
  /// 1 パスで追跡し、文字列外は素通し。valid な JSON には無害。
  static String _repairJsonControlChars(String input) {
    final buffer = StringBuffer();
    var inString = false;
    var escaped = false;
    for (final code in input.codeUnits) {
      final ch = String.fromCharCode(code);
      if (escaped) {
        buffer.write(ch);
        escaped = false;
        continue;
      }
      if (inString) {
        if (ch == r'\') {
          buffer.write(ch);
          escaped = true;
          continue;
        }
        if (ch == '"') {
          inString = false;
          buffer.write(ch);
          continue;
        }
        if (code < 0x20) {
          switch (ch) {
            case '\n':
              buffer.write(r'\n');
            case '\r':
              buffer.write(r'\r');
            case '\t':
              buffer.write(r'\t');
            default:
              buffer.write('\\u${code.toRadixString(16).padLeft(4, '0')}');
          }
          continue;
        }
        buffer.write(ch);
        continue;
      }
      if (ch == '"') inString = true;
      buffer.write(ch);
    }
    return buffer.toString();
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
    // 実障害(2026-07-06): LLM が文字列値内に生改行を含む不正 JSON を返し
    // decode 失敗→生 JSON がリード本文に漏れた。valid ならそのまま(fast path
    // 無変更)、invalid なら制御文字を修復してから本パースする。
    var jsonInput = jsonText;
    try {
      jsonDecode(jsonText);
    } catch (_) {
      jsonInput = _repairJsonControlChars(jsonText);
    }
    try {
      final decoded = jsonDecode(jsonInput);
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
        // LLM が threadReplies の要素へ poll 等のオブジェクトを紛れ込ませることが
        // ある(実害: Map.toString() の生テキスト `{text: , poll: {...}}` がその
        // ままリプ投稿された)。文字列以外を無条件 toString() せず、Map からは
        // poll を回収してトップレベル poll 欠落時の代わりに使い、text は非空の
        // 文字列のときだけ採用する。その他の型は破棄する。
        UniversalXPoll? recoveredPoll;
        final threadReplies = <String>[];
        for (final entry in rawThreadReplies) {
          String? line;
          if (entry is String) {
            line = entry;
          } else if (entry is Map) {
            recoveredPoll ??= _parsePoll(entry['poll']);
            final text = entry['text'];
            if (text is String) line = text;
          }
          if (line == null) continue;
          final sanitized =
              sanitizeTweet(line, url: shareUrl, requireUrl: false);
          if (sanitized.trim().isEmpty) continue;
          // 二重エンコード({"text": …} を JSON 文字列として返す drift)対策:
          // 全体がオブジェクト/配列リテラルの文字列は散文ではないので捨てる。
          if (_looksLikeSerializedObject(sanitized)) continue;
          threadReplies.add(sanitized);
          // プロンプトは 5-8 リプライを要求。各リプライは独自にインプレッションを
          // 稼ぐので 6 で切らず 8 まで通す(サーバ側も slice(0,8))。
          if (threadReplies.length >= 8) break;
        }
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
          // トップレベル poll が正だが、threadReplies 内へ迷い込んだ poll も
          // 回収して native 投票を復元する(生テキスト漏出の再発防止とセット)。
          // LLM が投票を出さなかった成功ドラフトへ fallback のテンプレ投票を
          // 継承しない(毎日同じ投票が付き near-duplicate 降格を招くため)。
          poll: _parsePoll(decoded['poll']) ?? recoveredPoll,
          fallbackUsed: true,
          source: 'ai-json',
        );
      }
    } catch (_) {
      // Fall through to treating the response as a tweet body.
    }
    // 修復しても JSON として読めなかった生テキスト。JSON ダンプの指紋があれば
    // 本文には絶対に使わず、高品質化済みの真のフォールバックへ戻す。
    final rawTweet = sanitizeTweet(raw, url: shareUrl);
    if (_looksLikeJsonDump(rawTweet)) return fallback;
    return fallback.copyWith(text: rawTweet);
  }

  /// Parses an optional LLM-generated `poll` object into a [UniversalXPoll], or
  /// null when it is missing/malformed so the post stays byte-identical to the
  /// no-poll path. Requires a non-empty question and >=2 usable options; each
  /// option is trimmed, de-duplicated and truncated to X's 25-char limit;
  /// duration is clamped to X's 5〜10080 minute range (default 1440 = 1 day).
  static UniversalXPoll? _parsePoll(dynamic raw) {
    if (raw is! Map) return null;
    final rawQuestion = raw['question'] ?? raw['q'] ?? raw['title'] ?? '';
    final question = rawQuestion.toString().trim();
    final rawOptions = raw['options'] ?? raw['choices'];
    if (question.isEmpty || rawOptions is! List) return null;
    final seen = <String>{};
    final options = <String>[];
    for (final entry in rawOptions) {
      var option = entry.toString().trim();
      if (option.isEmpty) continue;
      if (option.runes.length > 25) {
        option = String.fromCharCodes(option.runes.take(25));
      }
      if (seen.add(option)) options.add(option);
      if (options.length == 4) break;
    }
    if (options.length < 2) return null;
    final durationRaw = raw['durationMinutes'] ?? raw['duration_minutes'];
    var duration = 1440;
    if (durationRaw is num) {
      duration = durationRaw.toInt();
    } else if (durationRaw is String) {
      duration = int.tryParse(durationRaw.trim()) ?? 1440;
    }
    if (duration < 5) duration = 5;
    if (duration > 10080) duration = 10080;
    return UniversalXPoll(
      question: question,
      options: options,
      durationMinutes: duration,
    );
  }

  static bool _isUsableText(String text, String url) {
    return text.isNotEmpty &&
        // 25000(X上限)でなくリード妥当上限で判定。超過は JSON ダンプ/暴走の
        // 兆候なので retry/fallback へ回す。
        text.length <= maxLeadDraftLength &&
        text.contains(url) &&
        !text.contains('/#/') &&
        // JSON ダンプをリード本文として絶対に採用しない。
        !_looksLikeJsonDump(text);
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

Return STRICT JSON only (RFC 8259). The raw response must parse with a standard JSON parser: (a) inside every string value, escape all line breaks as the two-character sequence \\n (blank line = \\n\\n) and NEVER emit a raw/literal newline inside a string value; (b) no markdown code fences, no comments, no trailing commas, no text before or after the JSON object. Schema:
{
  "text": "Japanese X post, a rich 400-900 char long-form lead (this account has X Premium so it is NOT limited to 280 chars), must include $shareUrl",
  "threadReplies": ["4 to 8 substantive Japanese reply posts, each 150-500 chars, forming a full briefing thread. PLAIN STRINGS ONLY - never JSON objects"],
  "imagePrompt": "English prompt for a 16:9 share image, no text overlay",
  "videoPrompt": "English prompt for a short presenter/share video",
  "hashtags": ["#buildinpublic", "#FlutterWeb", "#Supabase"],
  "poll": { "question": "<=100 char Japanese poll question tied to today's top headline>", "options": ["<=25 char option", "<=25 char option", "<=25 char option"], "durationMinutes": 1440 }
}

Page:
- title: ${context.title}
- route: ${context.routePath}
- canonicalUrl: ${context.url}
- shareUrlWithUtm: $shareUrl
- Today's real date (JST): ${_jstDateLabel()}

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
- Treat the "Variant ranking", "Structural lift", and "Top hook to emulate" lines (when present) as authoritative measured data: adopt the winning structure (media choice, link placement, thread length, hook shape) but never copy winning wording verbatim.
- A/B test only one major variable at a time: hook style, link placement, media/no-media, or thread length.
- If past results say a link in the first post underperforms, put the product URL in the final reply.
- Put information value first and product CTA last. Avoid looking like an ad in the lead post.
- The headline list above is REAL, sourced news (verbatim from NHK / ITmedia RSS). You MAY quote or paraphrase a headline as today's news. Do NOT add facts beyond the headline wording, and do NOT invent numbers, quotes, or outcomes.
- When headlines are present, OPEN the lead post by tying today's single most relevant headline to this app's angle (information organization / AI work OS), so the post visibly changes every day. Do not lead with a generic app description.
- The FIRST line (before the X "Show more" fold) must be a concrete curiosity/value/news hook that stops the scroll. Do NOT start with a label or date such as "デイリーブリーフィング — …朝"; do not prefix the post with the date. If you mention any date, use exactly today's real date (JST) given above and never invent another year (e.g. never write 2024).
- Every day's post must read as fresh and specific: pick a different concrete headline or angle rather than repeating yesterday's template.
- Prefer conversation hooks and save-worthy analysis over hashtags. When the thread genuinely helps later (a checklist, framework, or numbered briefing), add ONE natural save cue (e.g. "後で使えるよう保存を") — never on every post and never templated word-for-word.
- This X account has X Premium, so the lead post is NOT limited to 280 chars. Write a rich long-form lead of roughly 400-900 chars: a headline, 2-4 concrete news points with brief analysis, and a low-friction CTA. Do not compress it into one short sentence.
- Provide a FULL briefing thread: 5-8 substantive threadReplies that each add real analysis (状況/背景/なぜ重要か/仕事への活かし方/次の一手), not one-liners.
- Format for scannability: break the lead and each reply into short one-idea lines with a blank line between meaning-chunks (no wall-of-text paragraph). Put labels (なぜ重要か / 見通し / 次の一手 など) at the start of a line and continue the explanation on the next line, so a reader can skim in 2 seconds.
- The multi-line formatting above applies to the RENDERED post; inside the JSON string values you must still encode every line break as the two characters \\n, never a real newline.
- Cap emoji at 1-2 per post and do NOT decorate every line (emoji spam and full-line decoration trigger spam down-ranking). Number only replies 2 onward. Optionally add ONE short, non-templated thread-continuation cue (e.g. "🧵つづく") just before the lead's CTA/URL, varying the wording day to day so it is never identical.
- The FIRST reply must stand alone as its own scroll-stopping hook: one sharp claim + why it matters + a reply-provoking question, fully readable with zero context from the lead post. Do NOT repeat the lead hook verbatim, do NOT phrase it as "1つ目/item 1 of N", and do NOT begin it with a number or list marker (never start with "1."). Replies 2 onward then form the numbered briefing.
- Native poll (impressions booster): when today's top headline supports a crisp either/or, ranking, or opinion question, include a "poll" object with a short Japanese "question" and 3-4 "options" (prefer 4 when each option is genuinely distinct; never pad with filler; each <=25 chars). X natively boosts impressions and early engagement on poll tweets.
- Poll options must be 3-4 GRADED reader stances or next actions (例: もう追っている/いま知った/後で調べる/仕事に直結) — never a flat binary such as 興味がある/興味がない or 賛成/反対 (binary polls collect fewer votes and read as low-effort).
- The "poll" must be a TOP-LEVEL JSON key only. NEVER place a poll object (or any JSON object) inside the threadReplies array — every threadReplies element must be a plain Japanese string, or it will be posted as raw garbage text.
- DERIVE the poll question AND options from THE DAY'S single most relevant headline so the poll rotates daily and is specific — NEVER reuse a generic or hardcoded poll like "使ってみたい?はい/いいえ" (near-duplicate polls get down-ranked). Yesterday's poll must not be reusable today.
- The poll is posted as its own FIRST text-only thread reply (never on the media lead), so make the "question" self-contained. If no natural, honest poll fits today's news, OMIT the "poll" field entirely rather than forcing a weak one.
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

  /// 共有カード画像の既定 alt text (= ページ題ベース)。
  /// X の上限は 1000 字だが余裕を持って 900 字で切り詰める。
  static String _defaultShareAltText(UniversalSharePageContext context) {
    final base = '${_shareTitleFor(context)}の共有カード画像';
    return base.length > 900 ? base.substring(0, 900) : base;
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
    // 合わせる(男性キャラなのに女性の声、という不一致を解消)。さらにトーン
    // (energetic / calm)も反映する。画像/動画と同一 seed。
    final character = _dailyPresenterCharacter(draft.text.hashCode);
    return _voiceLabelForCharacter(character);
  }

  /// presenter キャラ文字列から男性かどうかを判定する。プールの女性エントリは
  /// 必ず female / woman / lady のいずれかを含み、男性エントリは含まない。
  static bool _isMalePresenter(String character) {
    final c = character.toLowerCase();
    final isFemale =
        c.contains('female') || c.contains('woman') || c.contains('lady');
    return !isFemale;
  }

  /// presenter の性別(_isMalePresenter)に加えトーン(energetic / calm)を判定し、
  /// 音声ラベルへ写像する。トーンが判定できない場合は中庸の
  /// male_narrator / female_narrator を返す(= 従来の性別のみ一致と同じ出力)。
  /// エッジ側はトーン別 secret が未設定なら性別ベース音声へフォールバックする。
  static String _voiceLabelForCharacter(String character) {
    final c = character.toLowerCase();
    final gender = _isMalePresenter(character) ? 'male' : 'female';
    const energeticMarkers = <String>[
      'gyaru',
      'idol',
      'k-pop',
      'kpop',
      'dancer',
      'rock',
      'guitarist',
      'bandman',
      'runner',
      'athlete',
      'martial artist',
    ];
    const calmMarkers = <String>[
      'librarian',
      'elderly',
      'onee-san',
      'ojou-sama',
      'kimono',
      'shrine maiden',
      'miko',
      'gentleman',
      'detective',
      'wise',
    ];
    if (energeticMarkers.any((marker) => c.contains(marker))) {
      return 'energetic_$gender';
    }
    if (calmMarkers.any((marker) => c.contains(marker))) {
      return 'calm_$gender';
    }
    return '${gender}_narrator';
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
          : 'Weave in a subtle visual nod to today\'s topic: "$topic". '
              'Open with a strong first beat: within the first second the '
              'presenter looks straight into camera and starts speaking '
              'immediately, with an eye-catching camera move (push-in or '
              'whip-pan), so the video hooks muted viewers in the first '
              '3 seconds.';
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
      // finance も draft.text(400-900字の長文リード)をそのまま読み上げると
      // 動画が長くなり静止画フォールバックになる。導入+2行(各60字上限)+締めに短縮。
      const financeOpening = 'マイファイナンスの動くスマホUXを短くご紹介します。';
      const financeClosing = '5分だけ触って、役立った点と迷った点を教えてください。';
      final financeBody = _scriptLinesFromText(draft.text)
          .take(2)
          .map((line) => _clipNarrationLine(line, 60));
      return _capNarration(
        <String>[financeOpening, ...financeBody, financeClosing],
      );
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
    // ミュート自動再生では最初の3秒が視聴継続を決める。話題がある日は前置きの
    // 定型文でなく、話題そのものを1文目に一度だけ話す(旧形式は2文の opening が
    // 字幕 cue の途中分割「た。今日の話題は…」も誘発していた)。
    const topicHooks = <String>[
      '「%T」、30秒で要点だけ。',
      '「%T」、いま押さえるべき点をひと言で。',
      '「%T」。仕事にどう効くか、30秒で。',
    ];
    final opening = topic.isEmpty
        ? openings[seed % openings.length]
        : topicHooks[seed % topicHooks.length].replaceFirst('%T', topic);
    final closing = closings[(seed ~/ openings.length) % closings.length];

    // 動画ナレーションは短尺(~40秒)に保つ。長い台本は Hedra の動画生成に数分以上
    // かかり、ワンボタン投稿のポーリング(最大5分)内に完成せず静止画で投稿されて
    // しまうため。ポスト本文(text/threadReplies)は長文のまま、読み上げる動画だけ簡潔に。
    if (body.isNotEmpty) {
      // body 各行(threadReplies 由来。1行150-500字になりうる)を60字にクリップし、
      // 総文字数も _capNarration で 450 字以内に抑えて短尺動画を保証する。
      return _capNarration(<String>[
        opening,
        ...body.take(2).map((line) => _clipNarrationLine(line, 60)),
        'こうした話題も、AI仕事OSに残しておけば、後で使える判断材料に変わります。',
        closing,
      ]);
    }
    return _capNarration(<String>[
      opening,
      'AI仕事OSは、学習・仕事ログ・資産管理・英語学習・メモをひとつに整理できるツールです。',
      closing,
    ]);
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

  /// 動画ナレーションの読み上げ総文字数を Hedra が 5 分ポーリング内に完成できる
  /// 範囲へ制限する。実測: 145 字は video_ready まで到達 / 685 字は processing
  /// 滞留→クライアントが打ち切り静止画。450 字なら余裕を持って窓内に収まる。
  /// edge 側の `MAX_SPOKEN_CHARS` (viral-video-ad-generator) と同値。
  static const int _maxNarrationChars = 450;

  /// 1 行を最大 [max] 文字(runes 基準 / 日本語の結合文字割れを避ける)へクリップ。
  static String _clipNarrationLine(String line, int max) {
    final runes = line.runes.toList(growable: false);
    if (runes.length <= max) return line;
    return '${String.fromCharCodes(runes.take(max))}…';
  }

  /// ナレーション行群を総 [_maxNarrationChars] 文字以内へ切り詰める。どの分岐
  /// (finance / 一般 / 空 body フォールバック)も必ずこれを通し、将来の分岐追加でも
  /// 長尺化=静止画フォールバックが再発しないようにするための最終ガード。
  static List<String> _capNarration(List<String> lines) {
    final out = <String>[];
    var total = 0;
    for (final line in lines) {
      if (line.isEmpty) continue;
      final runes = line.runes.length;
      if (total + runes > _maxNarrationChars) {
        final remaining = _maxNarrationChars - total;
        if (remaining > 8) {
          out.add(_clipNarrationLine(line, remaining - 1));
        }
        break;
      }
      out.add(line);
      total += runes;
    }
    return out.isEmpty ? lines.take(1).toList() : out;
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
