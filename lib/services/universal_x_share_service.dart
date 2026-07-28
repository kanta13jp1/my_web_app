import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'ai_hub_chat_service.dart';
import 'ai_share_button_preferences_service.dart';
import 'x_copy_guardrails.dart';

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
  // LLM ドラフトのリード文の妥当上限。プロンプト仕様は通常 400-900 字、
  // データレポート型の日のみ内訳込みで最大 1500 字(いずれも 2 倍のヘッド
  // ルーム)。これを超える「リード」は JSON ダンプや暴走テキストの兆候
  // なので不採用にして retry/fallback へ回す。
  static const int maxLeadDraftLength = 3000;
  static const String defaultHedraStartImageUrl =
      'https://my-web-app-b67f4.web.app/ogp-image-gen2-20260428.png';
  static const String firstUserGrowthCampaign = 'first_user_growth';
  static const String aiShareMedium = 'ai_share';
  static const String profileMedium = 'profile';
  static const List<String> _shareableProjectPlanLabels = <String>[
    '短期計画',
    '中期計画',
    '長期計画',
  ];
  // 実際に使うツール(嘘のパイプラインにしない): 文章=GPT-5.5 / 画像=GPT image /
  // 音声=ElevenLabs / 動画=Hedra。
  static const List<String> _creativePipeline = <String>[
    'gpt-5.5',
    'gpt-image',
    'elevenlabs',
    'hedra',
  ];
  // シネマティック動画エンジン(fal.ai text-to-video)のパイプライン。顔画像・
  // TTS を使わないので image/elevenlabs は含めない。
  static const List<String> _cinematicCreativePipeline = <String>[
    'gpt-5.5',
    'fal-text-to-video',
  ];

  /// シネマティック動画の固定アートディレクション。LLM が毎回生成する
  /// [UniversalXShareDraft.videoPrompt] に後置し、日々の話題は変わっても
  /// ブランドの見た目(和紙ペーパークラフト×藍/朱)が一貫するようにする。
  static const String kCinematicStyleDirective =
      'Handcrafted washi paper-craft diorama style, layered paper textures, '
      'indigo and vermilion color palette, soft studio lighting, gentle '
      'cinematic camera movement, 16:9 short video, consistent art direction, '
      'no on-screen text, no watermark, no logos.';

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
        nowJst: (nowUtc ?? DateTime.now().toUtc()).add(
          const Duration(hours: 9),
        ),
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
      final created = DateTime.tryParse(
        row['created_at']?.toString() ?? '',
      )?.toUtc();
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
    // 独立した3 enrichment を直列待ちしない。各 fetcher は fail-open なので、
    // どれかが不調でも残りの事実と従来 fallback で下書き生成を続けられる。
    final enrichment = await Future.wait<dynamic>([
      _fetchXTrendTopics(),
      _fetchXPerformanceContext(),
      supportsProjectStatsContext(context)
          ? _fetchProjectStatsContext()
          : Future<String>.value(''),
    ]);
    final trends = enrichment[0] as List<UniversalXTrendTopic>;
    final performanceContext = enrichment[1] as String;
    final projectStatsContext = enrichment[2] as String;
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
                projectStatsContext: projectStatsContext,
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
    String? falRequestId,
    AiShareVideoEngine engine = AiShareVideoEngine.presenter,
  }) async {
    // シネマティック動画(fal.ai text-to-video)。Hedra と違い顔画像を
    // 必要としないため、imageUrl 検証や開始画像の指定は行わない。
    if (engine == AiShareVideoEngine.cinematic) {
      final requestBody = <String, dynamic>{
        'type': 'cinematic_video',
        'template': _videoTemplateFor(context),
        'lang': 'ja',
        'title': _shareTitleFor(context),
        'customPrompt': cinematicVideoPromptFor(context, draft),
        'customScript': _videoScriptFor(context, draft),
        'customHashtags': draft.hashtags,
        'preferredModel': 'fal-text-to-video',
        'creativePipeline': _cinematicCreativePipeline,
        'source': 'universal_x_share',
        'route': context.routePath,
      };
      final normalizedFalRequestId = _emptyToNull(falRequestId);
      if (normalizedFalRequestId != null) {
        requestBody['falRequestId'] = normalizedFalRequestId;
      }
      final data = await _invoke('viral-video-ad-generator', requestBody);
      return UniversalXMediaResult(
        url: _emptyToNull(_extractVideoUrl(data)),
        status: data['videoStatus']?.toString() ??
            data['status']?.toString() ??
            'unknown',
        raw: data,
      );
    }
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
    return UniversalXMediaResult(
      url: _emptyToNull(_extractVideoUrl(data)),
      status: data['videoStatus']?.toString() ??
          data['status']?.toString() ??
          'unknown',
      raw: data,
    );
  }

  static String? _extractVideoUrl(Map<String, dynamic> data) {
    return data['storedVideoUrl']?.toString() ??
        data['generatedVideoUrl']?.toString() ??
        data['generatedDownloadUrl']?.toString() ??
        data['generatedPreviewUrl']?.toString() ??
        data['videoUrl']?.toString() ??
        data['downloadUrl']?.toString() ??
        data['url']?.toString();
  }

  /// シネマティック動画のプロンプト(公開 static / テスト可能)。LLM ドラフトの
  /// videoPrompt(当日の話題入り)に固定アートディレクションを後置する。
  static String cinematicVideoPromptFor(
    UniversalSharePageContext context,
    UniversalXShareDraft draft,
  ) {
    final base = draft.videoPrompt.trim().isNotEmpty
        ? draft.videoPrompt.trim()
        : 'A short cinematic teaser video introducing '
            '"${_shareTitleFor(context)}", a Japanese life-management web app.';
    final separator = base.endsWith('.') ? ' ' : '. ';
    return '$base$separator$kCinematicStyleDirective';
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
  /// 実在する具体機能の一次事実。LLM は _buildDraftPrompt でこの一覧を渡され、
  /// 今日の見出しに最も直結する 1 つを名前で挙げるよう求められる。これが無いと
  /// モデルは製品を語る具体材料を持たず「強力なツール」等の一般名詞に堕ちる
  /// (R11 実測: 実投稿の product mention が全て generic だった真因)。
  // R21: 実体は x_copy_guardrails.dart の共有定数へ byte-identical に移動
  // (CmoPage と両参照して語彙ドリフトを防ぐ)。private alias 経由なので参照箇所
  // (_buildDraftPrompt 内)は一切変更しない。
  static const List<String> _appFeatureFacts = kAppFeatureFacts;

  static const List<String> _ctaFinalReplies = <String>[
    '試せるURLはこちらです。5分だけ触って、A/B/Cか一言で返信ください。',
    '触ってみたい方はこちらへ。5分で気づいた点を一言もらえると助かります。',
    'ここから試せます。最初の1画面で迷った所があれば教えてください。',
    '実際に開けます。役に立ちそう/そうでない、どちらでも返信歓迎です。',
    'デモはこちら。5分だけ使って、続けたいと思ったか教えてください。',
    '要点は後で使えるので保存推奨。触ったら一言だけ感想ください。',
    'この投稿は保存しておくと後で効きます。使えたか一言返信歓迎です。',
    // フォロー変換バリアント: 毎日この形式で発信している事実を添え、スレッド
    // 読者をプロフィール経由のフォローへ導く(全体の ~1/9 出現でスパム化しない)。
    '毎日この形式で自分株式会社の開発を発信しています。役立ったらプロフィールからフォローどうぞ。試すURLはこちら。',
    'この続きは毎日ここで出しています。よければプロフィールを覗いてみてください。試すURLはこちら。',
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

  /// R26: 管理者限定 growth-hub roadmap.share_stats の自社実データ(登録アカウント
  /// 総数・開発ログ件数・公開可能な計画進捗/期日)を、データレポート型リードの
  /// 数字源(d)となる
  /// "Own project data" ブロックへ整形して返す。失敗・未ログイン・実数不足は
  /// '' を返し、プロンプト側で数字源(d)が DISABLED と明示される
  /// (= 実データは共有を良くするためで、下書き生成を絶対に止めない)。
  Future<String> _fetchProjectStatsContext() async {
    try {
      final data = await _invoke('growth-hub', {
        'action': 'roadmap.share_stats',
      });
      if (data['success'] == true) {
        return buildProjectStatsContext(data);
      }
    } catch (_) {
      // Real-data enrichment must never block drafting.
    }
    return '';
  }

  /// 全体の登録/開発進捗が現在ページの主題になり得る route だけで source (d) を
  /// 有効化する。利用可能な数字があるだけで、学習・家計・選挙など無関係なページを
  /// 汎用ロードマップ投稿へ変えてしまわないための relevance gate。
  static bool supportsProjectStatsContext(UniversalSharePageContext context) {
    final path = context.routePath.trim().toLowerCase();
    return path == '/' ||
        path == '/cmo' ||
        path == '/cmo-office' ||
        path == '/admin' ||
        path.startsWith('/admin/') ||
        path.startsWith('/growth-');
  }

  /// roadmap.share_stats 応答を "Own project data" ブロックへ整形する純関数。
  /// 実測 97K ポスト(集計ヘッダ→差分→残り→期日カウントダウン)の数字骨格を、
  /// 実在する自社データだけで再現するための供給源。差分・残り・あとN日 は
  /// LLM に計算させず、ここで確定した値のみをプロンプトへ渡す(捏造/計算ミス
  /// 防止)。公開可能な実数が 2 つ未満の日は '' を返し、データレポート型を
  /// 自動無効化する(数字の乏しい日に無理に集計風を作らせない)。
  static String buildProjectStatsContext(
    Map<String, dynamic> progress, {
    DateTime? nowJst,
  }) {
    // roadmap.share_stats は運営者限定かつ3系統の取得成功後だけ verified=true を
    // 返す。通常 roadmap.progress や部分レスポンスを publishable と誤認しない。
    if (progress['verified'] != true ||
        progress['source']?.toString() != 'roadmap.share_stats') {
      return '';
    }
    final now = nowJst ?? DateTime.now().toUtc().add(const Duration(hours: 9));
    var realNumbers = 0;
    final lines = <String>[];

    final statParts = <String>[];
    final userCount = progress['userCount'];
    int? registeredAccounts;
    if (userCount is num && userCount >= 0) {
      // Supabase Auth の総レコード数であり、アクティブ/外部の「実ユーザー」ではない。
      registeredAccounts = userCount.toInt();
      statParts.add('registered-accounts(total)=$registeredAccounts');
      realNumbers += 1;
    }
    final achievementsCount = progress['achievementsCount'];
    if (achievementsCount is num && achievementsCount >= 0) {
      // development_achievements の行数。全件がユーザー向け出荷機能とは限らない。
      statParts.add(
        'development-log-entries(total)=${achievementsCount.toInt()}',
      );
      realNumbers += 1;
    }
    if (statParts.isNotEmpty) {
      lines.add('- ${statParts.join(', ')}');
    }

    final plans = progress['plans'];
    if (plans is List) {
      final planByLabel = <String, Map<dynamic, dynamic>>{};
      for (final raw in plans.whereType<Map>()) {
        final label = raw['label']?.toString().trim() ?? '';
        if (_shareableProjectPlanLabels.contains(label)) {
          planByLabel[label] = raw;
        }
      }
      for (final allowedLabel in _shareableProjectPlanLabels) {
        final raw = planByLabel[allowedLabel];
        if (raw == null) continue;
        final label = raw['label']?.toString().trim() ?? '';
        final parts = <String>[];
        int? remaining;
        int? accountGap;
        int? daysLeft;
        final done = raw['features_done'];
        final total = raw['features_total'];
        if (done is num && total is num && total > 0) {
          final doneInt = done.toInt();
          final totalInt = total.toInt();
          remaining = (totalInt - doneInt) < 0 ? 0 : totalInt - doneInt;
          // 短/中/長期計画の値は growth-hub が development_achievements 行数を
          // 50/200/500 の閾値へ当てたもの。出荷機能数とは呼ばない。
          parts.add(
            'development-log threshold $doneInt/$totalInt, '
            '閾値まで残り$remaining件',
          );
          realNumbers += 2;
        }
        final target = raw['target'];
        if (target is num && target > 0) {
          final targetInt = target.toInt();
          parts.add('登録アカウント目標 $targetInt件');
          if (registeredAccounts != null) {
            final gap = targetInt - registeredAccounts;
            accountGap = gap;
            parts.add(gap > 0 ? '目標まで残り$gap件' : '目標達成 +${-gap}件');
            realNumbers += 2;
          } else {
            realNumbers += 1;
          }
        }
        final deadline = raw['deadline']?.toString().trim() ?? '';
        if (deadline.isNotEmpty) {
          daysLeft = _daysUntilDeadline(deadline, now);
          if (daysLeft == null) {
            parts.add('期日 $deadline');
          } else if (daysLeft < 0) {
            // 過去期日を「あと0日」と表示すると、まだ期限内だと誤読される。
            // 経過日数は投稿価値が低く日々変わるため、更新が必要な状態だけ示す。
            parts.add('期日 $deadline = 終了・更新必要');
            realNumbers += 1;
          } else if (daysLeft == 0) {
            parts.add('期日 $deadline = 本日期日');
            realNumbers += 1;
          } else {
            parts.add('期日 $deadline = あと$daysLeft日');
            realNumbers += 1;
          }
        }
        if (parts.isEmpty) continue;
        // 97K 集計の赤黄アラートを「モデルに考えさせる」のではなく実データから
        // 確定する。未完了かつ期日超過=赤、30日以内=黄。それ以外は無印。
        final hasOpenGap = (remaining != null && remaining > 0) ||
            (accountGap != null && accountGap > 0);
        final marker = hasOpenGap && daysLeft != null
            ? (daysLeft < 0 ? '🔴 ' : (daysLeft <= 30 ? '🟡 ' : ''))
            : '';
        lines.add('- ${marker}Goal gap ($label): ${parts.join('; ')}');
      }
    }

    if (realNumbers < 2 || lines.isEmpty) return '';
    final stamp = '${now.year}-${_pad2(now.month)}-${_pad2(now.day)} '
        '${_pad2(now.hour)}:${_pad2(now.minute)} JST';
    return [
      'Own project data (source=growth-hub roadmap.share_stats; 取得日時 $stamp '
          '— REAL numbers you MAY publish first-person as build-in-public stats):',
      ...lines,
    ].join('\n');
  }

  /// 'yyyy年M月d日' か ISO 'yyyy-MM-dd' の期日を JST 今日からの残日数に変換
  /// する。期日超過は負値のまま返し、呼び出し側が「終了・更新必要」と表示して
  /// 偽の「あと0日」を避ける。未知形式は null(期日は文字列のまま渡す)。
  static int? _daysUntilDeadline(String deadline, DateTime nowJst) {
    final jp = RegExp(r'^(\d{4})年(\d{1,2})月(\d{1,2})日$').firstMatch(deadline);
    final date = jp != null
        ? DateTime(
            int.parse(jp.group(1)!),
            int.parse(jp.group(2)!),
            int.parse(jp.group(3)!),
          )
        : DateTime.tryParse(deadline);
    if (date == null) return null;
    // 日付だけの差分は UTC midnight 同士で計算し、実行環境の DST による
    // 23/25時間日の `.inDays` 丸め誤差を避ける。
    final today = DateTime.utc(nowJst.year, nowJst.month, nowJst.day);
    final due = DateTime.utc(date.year, date.month, date.day);
    return due.difference(today).inDays;
  }

  static String _pad2(int value) => value.toString().padLeft(2, '0');

  static String buildXPostFailureMessage(Map<String, dynamic> data) {
    final error = data['error']?.toString().trim();
    final actionRequired = data['actionRequired']?.toString().trim();
    final registrationUrl = data['registrationUrl']?.toString().trim();
    final candidates = <String>[
      if (error != null && error.isNotEmpty) error else 'X post failed',
      if (actionRequired != null && actionRequired.isNotEmpty) actionRequired,
      if (registrationUrl != null && registrationUrl.isNotEmpty)
        'Developer Portal: $registrationUrl',
    ];
    // 実障害(2026-07-08): edge が error 本文にガイダンスを埋め込み、同文が
    // actionRequired としても返るため、連結すると同じ段落が二重表示された。
    // 既に採用済みの部分に substring として含まれる部分は落とす(コード非依存
    // = 旧 edge デプロイや他コードパスの同型二重化にも効く)。
    final parts = <String>[];
    for (final candidate in candidates) {
      if (parts.any((existing) => existing.contains(candidate))) continue;
      parts.add(candidate);
    }
    return parts.join('\n');
  }

  /// R15: 投稿前の spend-cap preflight。growth-hub の read-only
  /// `x.post_preflight`(X API 非呼出・直近ログ判定)を呼び、ブロック中なら
  /// 高価な画像/音声/動画生成と投稿試行を丸ごとスキップさせる。
  /// preflight 自体の失敗で本流を止めない(never-throw / fail-open)。
  Future<({bool blocked, String? resetAt})> checkXPostPreflight() async {
    try {
      final data = await _invoke('growth-hub', {'action': 'x.post_preflight'});
      return (
        blocked: data['blocked'] == true,
        resetAt: data['resetAt']?.toString(),
      );
    } catch (_) {
      return (blocked: false, resetAt: null);
    }
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

  /// フォールバック用の決定論的な投票(R13b / #3872)。この経路は
  /// [_buildDraftPrompt] を通らないため R12 で入れた poll の主題ロック/現在状態
  /// ルールが効かず、旧実装は「今日の注目『$topic』、あなたは？」+「詳しく知りたい
  /// /様子見/仕事に関係あり/関係なし」という R12 で潰した 0 票型(関心度 stem +
  /// 意見サーベイ)を復活させていた。対策として、スレッド本文が実際に扱う
  /// カテゴリ([_trendCategory])に一致する一人称・現在状態 poll だけを出し、
  /// カテゴリを特定できない汎用トレンドは poll を省略する(本文主題ズレ/0票を回避)。
  /// トレンドが無い日も null(投票なし)。全選択肢は 25 runes 以下で
  /// [_xPollPayload] の検証を素通りする。
  static UniversalXPoll? _fallbackPollFor(
    List<UniversalXTrendTopic> trends,
    int seed,
  ) {
    if (trends.isEmpty) return null;
    final rawName = trends.first.name.trim();
    if (rawName.isEmpty) return null;
    final variants = _fallbackStatePollsFor(_trendCategory(rawName));
    if (variants.isEmpty) return null;
    return variants[seed.abs() % variants.length];
  }

  /// カテゴリ別の一人称・現在状態 poll 候補(R13b)。質問は意見/関心度の度合いでは
  /// なく「今どうしているか(状態/行動)」を問い、選択肢もすべて現在の状態/行動。
  /// 本文主題に一致するカテゴリのみ定義し、特定不能な 'トレンド' は空 = poll を
  /// 出さない。複数候補は seed で日替りローテし近似重複の降格を避ける。
  static const Map<String, List<UniversalXPoll>> _fallbackStatePolls = {
    'AI・テック': [
      UniversalXPoll(
        question: '新しいAIの話題、あなたは今どこ？',
        options: ['もう業務で使ってる', '試している', '情報だけ追ってる', 'まだ触ってない'],
      ),
      UniversalXPoll(
        question: '話題のAIツール、あなたの今の使い方は？',
        options: ['毎日の仕事で常用', 'たまに試す', '様子を見て記録', '導入は未定'],
      ),
    ],
    '経済・市場': [
      UniversalXPoll(
        question: 'お金の動き、あなたは今どう見てる？',
        options: ['給料日基準で見てる', '月初〜月末で見てる', '把握できてない', '見直したい'],
      ),
      UniversalXPoll(
        question: '家計の把握、あなたの今のやり方は？',
        options: ['アプリで自動集計', '手動で記録', '通帳を時々確認', 'ほぼ見ていない'],
      ),
    ],
    'スポーツ/国際': [
      UniversalXPoll(
        question: 'その試合・話題、あなたは今？',
        options: ['リアルタイムで追ってる', '結果だけ見た', 'あとで振り返る', '追っていない'],
      ),
    ],
    '日本政治': [
      UniversalXPoll(
        question: 'この政治の動き、あなたは今？',
        options: ['一次情報を追ってる', 'ニュースで把握', 'あとで調べる', '追っていない'],
      ),
    ],
  };

  static List<UniversalXPoll> _fallbackStatePollsFor(String category) {
    // 'トレンド' 等の特定不能カテゴリは空 = poll を省略(R12: 主題ズレ/0票回避)。
    return _fallbackStatePolls[category] ?? const <UniversalXPoll>[];
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
    // ラベルと解説プールを同じ分類([_trendCategory])で選び、両者を一致させる
    // (R13b で _trendCategory の AI 判定を拡張したため、旧インライン判定との
    // 二重管理を解消 = ChatGPT 等も 【AI・テック】ラベルと AI 解説が揃う)。
    final pool = switch (category) {
      'スポーツ/国際' => _briefingSportsPool,
      'AI・テック' => _briefingAiPool,
      _ => _briefingDefaultPool,
    };
    final commentary = pool[(index - 1 + seed) % pool.length];
    return '''
$index. 【$category】$name$volume
$commentary''';
  }

  /// 「AI」を独立トークンとして判定する(前後が英字でない)。単純な部分一致だと
  /// 大文字 UKRAINE/TAIWAN/DUBAI や小文字 Ukraine/campaign 等、"ai" を含む長い
  /// 英単語へ誤爆する。AI技術 / 生成AI / 単体 AI には一致する。
  static final RegExp _aiTokenPattern = RegExp(
    r'(?:^|[^A-Za-z])AI(?:[^A-Za-z]|$)',
  );

  /// 経済・市場カテゴリの具体キーワード(#3872 R13b)。bare 円/ドル/株 の部分一致は
  /// 公園・アイドル・株式会社 等へ誤爆するため使わず、家計アプリの主題に直結する
  /// 具体語で拾う(物価/給料/家計 等の false-negative も同時に解消して、当該日は
  /// 家計の現在状態 poll が正しく発火するようにする)。
  static const List<String> _financeKeywords = <String>[
    '日経',
    '株価',
    '株式市場',
    '株主',
    '円安',
    '円高',
    '為替',
    '米ドル',
    'ドル円',
    '物価',
    'インフレ',
    'デフレ',
    '家計',
    '給料',
    '給与',
    '賃上げ',
    '節約',
    '投資',
    '年金',
    '増税',
    '減税',
    '値上げ',
    '金利',
    '日銀',
    '景気',
    '住宅ローン',
    '貯金',
    '貯蓄',
    '確定申告',
    'NISA',
  ];

  static String _trendCategory(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('worldcup') ||
        lower.contains('world cup') ||
        name.contains('ワールドカップ') ||
        name.contains('W杯') ||
        name.contains('サッカー')) {
      return 'スポーツ/国際';
    }
    if (_aiTokenPattern.hasMatch(name) ||
        lower.contains('gpt') ||
        lower.contains('llm') ||
        lower.contains('openai') ||
        lower.contains('gemini') ||
        lower.contains('claude') ||
        lower.contains('anthropic') ||
        lower.contains('copilot') ||
        name.contains('人工知能') ||
        name.contains('生成モデル')) {
      return 'AI・テック';
    }
    if (name.contains('選挙') ||
        name.contains('政権') ||
        name.contains('国会') ||
        name.contains('首相')) {
      return '日本政治';
    }
    if (_financeKeywords.any(name.contains)) {
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
          final sanitized = sanitizeTweet(
            line,
            url: shareUrl,
            requireUrl: false,
          );
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
    String projectStatsContext = '',
    String? shareUrlOverride,
  }) {
    final shareUrl = shareUrlOverride ?? acquisitionUrlFor(context);
    final trendContext = _formatTrendContext(trendTopics);
    final featureFacts = _appFeatureFacts.map((f) => '- $f').join('\n');
    final financeRule = _isMyFinanceUxContext(context)
        ? '- For finance routes, frame this as 動くスマホアプリUX検証動画「マイファイナンス」 and mention GPT image -> GPT-5.5 -> ElevenLabs -> Hedra when natural.'
        : '';
    return '''
You are the solo developer who personally runs the one-person company 「自分株式会社」. Write build-in-public copy in the FIRST PERSON as yourself (自分が作った/実測した/つまずいた), NOT as a third-party marketer describing someone else's product.
Create one X sharing package for the current page of your Flutter Web app.
Primary goal: get one real first user from X to try the site and leave feedback.
Secondary goal: earn useful impressions without sounding like spam.

Return STRICT JSON only (RFC 8259). The raw response must parse with a standard JSON parser: (a) inside every string value, escape all line breaks as the two-character sequence \\n (blank line = \\n\\n) and NEVER emit a raw/literal newline inside a string value; (b) no markdown code fences, no comments, no trailing commas, no text before or after the JSON object. Schema:
{
  "text": "Japanese X post, normally 400-900 chars; only a supported data-report breakdown may be 900-1500 chars (this account has X Premium), must include $shareUrl",
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

${projectStatsContext.trim().isEmpty ? 'Own project data: none available today. Number source (d) below is DISABLED — do not invent registered-account counts, development-log totals, goal gaps, or deadline countdowns.' : projectStatsContext}

App の実在する具体機能 (今日の見出しに最も直結する 1 つを名前で挙げ、それが何を数値/画面/具体で解決するかを書く。アプリを一般名詞「ウェブアプリ」「ツール」「強力なツール」で呼ぶな):
$featureFacts

Rules:
- Do not use hash routing. The URL must not contain # or /#/.
- Make the copy specific to this page and useful for a stranger on X.
- Ask for a low-friction first action: try for 5 minutes and say what helped or confused them.
- Do not ask for payment, promise revenue, or imply Stripe payout readiness.
- Prefer concrete pain, feature, or question hooks over generic app promotion.
- 一人称の実体験で書け: 運営者本人が実際にやったこと・作ったこと・実測したこと・つまずいたことを最低1つ具体で入れる(数値・固有機能名・失敗を歓迎)。三人称のブランド口調(「私たちの新しいウェブアプリは」「企業がAIを取り入れると」等の伝聞・一般論)を禁止する。
- 一人称は《検証可能な範囲》に限れ: (A)アプリを作った/実装した/直した(実在の機能・意図)や、(B)機能が何をする/読者が何をできるか(FEATURE-FACTに基づく現在形の能力)は書いてよい。だが payload に無い個人的実績(「先月○○に気づいた」「家計が健全になった」式の、日付・金額・生活改善の作り話)を事実として書くな。具体を出したいときは機能の仕組みか、明示ヘッジ付きの1例(「例えば給料日サイクルで見ると〜という形で出る」)にせよ。
- 捏造実績の文法テンプレートも禁止(言い換えでも不可): 一人称+過去形の《体験→成果》構文(「〜してみたところ/〜したら/〜した結果/〜を使ってみて」+「できました/なりました/楽になりました/解消しました/気づくことができました」)は、その成果が上の実在機能リストに明記されている場合を除き全面禁止。許可形は (A)構築行為の過去形(作った/実装した/直した) (B)機能の現在形 (C)明示ヘッジ付き仮例 のみ。出力前に各文を検査: 過去形の成果主張があれば実在機能リストに根拠があるか確認し、なければ(C)のヘッジ形へ書き直せ。
- 禁止フレーズ(これらを含む文は削除して書き直せ): 「可能性があります」「影響を及ぼすでしょう」「ますます激化」「激化しています」「強力なツール」「重要性を認識」「効率よく整理」「活用するためのサポート」「注目のニュース」「〜と言えるでしょう」「ぜひ試して」「ぜひ使ってみて」。英語の game-changer / powerful tool / the future of も禁止。さらに作り話の個人的実績の型も禁止: 「〜に気づきました」「〜が劇的に変わりました」「家計が健全になりました」。
- 程度を誇張する副詞で改善・変化を主張するな: 「劇的に」「大幅に」「格段に」「飛躍的に」「圧倒的に」「一気に」およびこれらに類する副詞すべて。改善の大きさは具体的な数値か仕組み(何がどう動いて何が消えるか)でのみ語れ。BAD「家計の把握が格段に楽になりました」 GOOD「給料日起点に窓を切ると月初またぎの支払いが二重計上されない=支出が実額になる」。
- 「〜が…する中、」「〜が…される中、」「〜が進む中、」型の一般論→自アプリ転換ブリッジを禁止(「〜化が加速する中」を含む全変種)。見出しとの接続は関連性ゲートの因果1文形のみ許可。BAD「企業の定型業務が効率化される中、私のウェブアプリでは…」。
- 自分のアプリを一般名詞で呼ぶ型も禁止(所有格を付けても不可): 「ウェブアプリ」「私のアプリでは」「このツール」「私のサービス」。アプリ自体に言及するときは必ず固有機能名(給料日サイクル 等、上の実在機能リストの名前)か「自分株式会社」で呼べ(「このアプリ」は既出文脈の照応としてのみ可)。BAD「私のウェブアプリでは『給料日サイクル』機能を実装しました」 GOOD「『給料日サイクル』は支出窓を給料日起点に切る機能。作った狙いは月初またぎ支払いの二重計上をなくすこと。」
- threadReplies のどのリプも poll の question 文をそのまま繰り返すな(poll は独立したリプとして自動投稿されるため、同文で始まるリプは連続重複に見える)。このプロンプト内の例文(GOOD例・保存版の良い例)を一言一句コピーするのも禁止=型だけ真似て今日の内容で必ず書き直せ。
- 各文ルール: 断定・具体・数字・一次体験(自分が実際にやったこと)のいずれかを含まない文は入れるな。誰でも書ける当てずっぽうの一般予測を禁止。
- 具体性の下限: 少なくとも3つのリプはそれぞれ固有アンカー(具体的な数字 / 見出し以外の固有名詞 / このアプリを作って分かった一次体験)を1つ以上持つこと。
- アプリに触れるときはリードで今日の見出しに最も直結する1機能を主役にしつつ、リプでは他の機能も名前を挙げて具体で出す。いずれも上の「App の実在する具体機能」から選び、それが何を数値/画面/具体で解決するかを書く。一般名詞で濁すな。
- 機能カバレッジ配分: 同じ機能名とその成果アンカー(例: 給料日サイクル/二重控除)を、スレッド全体で3投稿以上の主眼にするな(リード=1投稿と数える)。スレッドが5投稿以上のときは、上の実在機能リストから異なる機能を最低2つ、それぞれ少なくとも1つのリプの主眼にせよ。ただし今日の見出しに本当に直結する機能が1つしかないなら、無関係な機能を無理に挿入するより、その1機能の別々の具体面(別の画面/別の数字/別の一次体験)を各リプで扱え。substanceを軸で散らせ: (1)数字/実測 (2)リードとは別の機能 (3)その機能が内部でどう動く仕組み1点 (4)このアプリが今できない/やらないことを正直に1つ(「まだ○○は無い」の形)。同じ軸を2連続で使うな。
- 例(リプの実質・BAD→GOOD、この差を真似て今日の内容で書け): BAD「AI技術の競争がますます激化しています。今後、業界全体に影響を及ぼすでしょう。」 GOOD「今日の見出しは3分でこのアプリの検索できる判断メモに放り込んだ。自分は毎朝これで前日の見出しを整理してる。」 / BAD「私たちの新しいウェブアプリは情報整理を強力にサポートします。」 GOOD「給料日サイクル機能を実装した狙いはこれ: 窓を給料日起点に切ると、月初にまたぐ支払いが二重計上されず支出が実額になる。」
- Reach goal: beat 10K consistently and test toward the historical 97K-class benchmark without promising a specific result. The numbered analysis REPLIES keep the Daily Briefing structure when trend context is strong (numbered items, headline, why it matters, outlook), but the LEAD's shape follows the measured archetype guidance above: data-report style (real numbers first) when the allowed number sources supply enough real numbers, news-hook style otherwise. The briefing style is NOT the measured winner for the lead (news-briefing measured 517 vs data-report 3.2K on 2026-07-12).
- Use the measured performance context above. Prefer winning variants and avoid losing hook styles.
- Treat the "Variant ranking", "Structural lift", "Media lift", and "Top hook to emulate" lines (when present) as authoritative measured data: adopt the winning structure (media choice, link placement, thread length, hook shape) but never copy winning wording verbatim.
- If a "Media lift (by type)" line recommends a winning media type (動画/画像/テキスト) with enough samples, invest the strongest hook in that media: when video wins, front-load the first ~3 seconds of videoPrompt with the day's concrete hook; when image wins, make imagePrompt carry the single sharpest visual. If it says samples are insufficient, do NOT change media strategy — keep今日の既定(動画優先)。
- $kDataReportArchetypeLesson
- The historical 97K value above is STRATEGY EVIDENCE ONLY, never a number source for today's copy. Do not print 97K as today's impressions, target progress, or product result unless an "Own measured data" payload explicitly supplies that value for the current report.
- 上の教訓の実行形: 使ってよい実数が2つ以上あるなら、リードを「データレポート型」で構成せよ=冒頭1行目に今日の具体的な実数を1つ置き、差分→内訳→次の節目 の順に短行で並べる。使ってよい数字は次の系統のみ: (a)上の見出しに実際に書かれている数字 (b)上の "Own measured data" 行の実測値(このアカウント自身の実測インプレッションなので、一人称の build-in-public 実数として公開してよい) (c)機能の仕組みが定義する数(例: 給料日起点で支出の窓を切る) (d)上の "Own project data" ブロックに実際に書かれている実数(登録アカウント総数・開発ログ件数・残り件数・あとN日。ブロックが DISABLED の日は (d) を使うな)。それ以外の数字・集計値を作るな。差分・残り・残日数も payload に書かれた値だけを使い、自分で計算・再集計するな。実数が足りない日はデータレポート型を無理に作らず、ニュースフック型のリードに落とせ。
- データレポート型の日の骨格(97K実測ポストの構造): 集計ヘッダ(実数入り)→内訳の短行リスト を常置とし、取得日時・基準/目標との差分・残り・あとN日・アラート(🔴/🟡)の各要素は "Own project data" ブロックに実際に書かれている日だけ、その値・マーカーの再掲として置け。ブロックが DISABLED の日はこれらの要素を省き、集計ヘッダ→内訳→次の節目 の縮約骨格((a)(b)(c)の実数のみ)で構成せよ。内訳の列挙はリードでは上位5行までにとどめ、続きや全量は threadReplies 側で出せ。
- source (d) を使えるのは、この prompt に管理者検証済みの "Own project data" ブロックがある日だけ。その登録アカウント数を「実ユーザー/アクティブユーザー」、開発ログ件数を「出荷済み機能」と言い換えるな。🔴/🟡 はブロックに既に付いた行だけそのまま使い、モデル自身で重大度や件数を作るな。出典行は payload どおり「データ元: growth-hub roadmap.share_stats」とし、公式統計を装うな。
- Treat the "Archetype lift (by content archetype)" line (when present) as authoritative measured data too: when data_report is winning with enough samples, structure the lead as a data report (dense real numbers, deltas, named specifics); when it says samples are insufficient, do not force an archetype.
- A/B test only one major variable at a time: hook style, link placement, media/no-media, or thread length.
- Follow the measured "Structural lift (link placement)" line in BOTH directions: if link-in-reply wins, put the product URL in the final reply; if link-in-lead wins, keep the URL at the end of the lead post itself. Never assume one placement is safer than the other. Measured default (X analytics 2026-04-27..07-25, 350 posts): 94% of all url clicks came from posts carrying the URL in the lead, while the link-in-reply CTA reply reached only 30 impressions — so link-in-lead is the current default until new measurement overturns it.
- Put information value first and product CTA last WITHIN the lead post. Avoid looking like an ad, but do not strip the URL out of a lead that is otherwise useful — a post nobody can click did not acquire anyone.
- The headline list above is REAL, sourced news (verbatim from NHK / ITmedia RSS). You MAY quote or paraphrase a headline as today's news. Do NOT add facts beyond the headline wording, and do NOT invent numbers, quotes, or outcomes.
- データレポート型のリードには出典明示として「取得日時」行を1行入れよ。使ってよい日時は "Own project data" ブロックの取得日時と Today's real date のみ(日時の捏造禁止)。ブロックが DISABLED の日は「YYYY/MM/DD時点」(Today's real date)だけを使い、時刻を書き足すな。固有名詞の列挙は payload(見出し・Own project data・実在機能リスト)に実名で書かれているものだけ。payload に無い人名・企業名・製品名のリスト化を禁止する。
- 見出しの使い方(関連性ゲート): まず注入した見出しの中に、このアプリのドメイン(家計・資産・給与・負債・支出・節約・投資・AIによる仕事効率化/情報整理)と《具体的な因果でつながる》見出しが1つでもあるか判定せよ。(A)ある場合のみ、その見出しをフックにし1文でドメインへ橋を架ける。橋は必ず同じ1文の中で因果を通す=「(見出しの事象)→お金/仕事にこう効く→だから(FEATURE-FACT)でこう対処」の形。(B)真につながる見出しが1つも無い日は、見出しに一切触れず、上の『App の実在する具体機能』の1つから始まる運営者の実体験ストーリーをリードにせよ(一般名詞のアプリ紹介は禁止=必ず固有機能名で始める)。無関係なトレンド語(モデル名・製品名)をフックとして貼り付けることを禁止する。例外(データレポート型の日のみ): (B)の日でも使ってよい実数が2つ以上あるなら、この実体験ストーリー指示よりデータレポート型指示を優先し、1行目は集計ヘッダにせよ(その日も見出しには一切触れるな)。固有機能名はリードの内訳行か threadReplies で最低1回名前を挙げれば足りる。
- 橋渡しの禁止形: 話題名を出すだけで内容的に捨てる逆接ブリッジ(「◯◯が気になる方も多いですが、私の△△機能は」「◯◯の話題ですが、それはさておき」「◯◯が話題ですが、」)を禁止する。1文で自然に因果が書けないなら、その見出しとアプリは本当につながっていない→別の見出し/角度を選ぶか、上記(B)へ切り替えて見出しに触れず書け。BAD「Fable 5が気になる方も多いですが、給料日サイクル機能は…」 GOOD「AIの月額サブスクが乱立する今、固定費が見えにくい。給料日サイクルで見ると、月初をまたぐ引き落としが二重計上されずに実額で出る。」
- The FIRST line (before the X "Show more" fold) must be a concrete curiosity/value/news hook that stops the scroll. Do NOT start with a label or date such as "デイリーブリーフィング — …朝"; do not prefix the post with the date. If you mention any date, use exactly today's real date (JST) given above and never invent another year (e.g. never write 2024). 例外(データレポート型の日のみ): 1行目を「<シリーズ名> <主要実数1つ> (YYYY/MM/DD時点)」形式の集計ヘッダにしてよい(97K実測ポストの型。実数を必ず1行目に含める。日付は Today's real date のみ)。実数を含まないラベル/日付だけの1行目は引き続き禁止。「デイリーブリーフィング」をシリーズ名に使うな(実測の負けラベル)。
- Every day's post must read as fresh and specific: pick a different concrete headline or angle rather than repeating yesterday's template. 例外(データレポート型の日のみ): 同名シリーズの集計ヘッダ+当日日付+更新された実数の組は「昨日のテンプレの繰り返し」とみなさない(数字の更新こそがシリーズ物の価値=読者が差分を追える)。ただしヘッダと数字以外の本文文言は毎日書き替えろ。
- Keep the LEAD post strictly hashtag-free (the news hook must stay above the fold). Append 2-3 natural Japanese discovery hashtags on a trailing line of exactly ONE mid-thread reply (never the lead, never every reply), chosen from {#AI活用, #個人開発, #buildinpublic} plus at most one topic-specific tag — 3 tags max total, no stuffing.
- This X account has X Premium, so the lead post is NOT limited to 280 chars. Write a rich long-form lead of roughly 400-900 chars. On data-report days (see the archetype rules above), structure it as 実数→差分→内訳→次の節目, and when the lead includes a short-line breakdown list you may extend it to 900-1500 chars (long dense data = dwell time; never pad with prose to reach length); otherwise as a headline, 2-4 concrete news points with brief analysis, and a low-friction CTA. Do not compress it into one short sentence.
- Provide a FULL briefing thread: 5-8 substantive threadReplies that each add real analysis (状況/背景/なぜ重要か/仕事への活かし方/次の一手), not one-liners.
- Make the thread SAVE-worthy: turn the LAST analysis reply (the one just before the final URL/CTA reply) into a self-contained "保存版まとめ" — a numbered 3-4 point 使えるチェックリスト that stands alone as a single screenshot. This IS the bookmark anchor. Write it fresh each day (never templated), at most once, and NEVER put it on the final URL/CTA reply. Do NOT add any other separate "保存を" save cue — this まとめ is the single save mechanism per thread.
- 保存版まとめの各行は「動詞で始まる、アプリ無しでも即実行できる具体手順」にせよ。今日のニュースから得た固有の学び(数字・固有名詞・具体行動のいずれか)を最低1つ含める。「理解する」「認識する」「意識する」「重要性を〜」等の内省・抽象動詞をポイントの主眼にするのを禁止(そういう行は無効=具体的にやることへ置換)。悪い例(禁止): 1.AI技術の進化を理解する 2.情報整理の重要性を認識する 3.フィードバックを提供する / 良い例(この型を真似て今日の内容で作り直す): 1.今日の注目ニュースの要点だけ3行で自分のメモに残す(所要3分) 2.『事実』と『自分の考え』を1行ずつ分けて書く=後で判断材料に引ける 3.週末に今週保存したメモを見返し、仕事で使える1件だけタグ付けする
- Format for scannability: break the lead and each reply into short one-idea lines with a blank line between meaning-chunks (no wall-of-text paragraph). Put labels (なぜ重要か / 見通し / 次の一手 など) at the start of a line and continue the explanation on the next line, so a reader can skim in 2 seconds.
- The multi-line formatting above applies to the RENDERED post; inside the JSON string values you must still encode every line break as the two characters \\n, never a real newline.
- Cap emoji at 1-2 per post and do NOT decorate every line (emoji spam and full-line decoration trigger spam down-ranking). Number only replies 2 onward. Optionally add ONE short, non-templated thread-continuation cue (e.g. "🧵つづく") just before the lead's CTA/URL, varying the wording day to day so it is never identical. 例外(データレポート型の日のみ): アラート行の行頭に置く 🔴/🟡 の重要度マーカーは装飾と数えない(97K実測ポストの走査性の要。リード全体で最大5行まで。アラート行以外の装飾は引き続き禁止、他の絵文字は従来通り1-2個まで)。
- The FIRST reply must stand alone as its own scroll-stopping hook: one sharp claim + why it matters + a reply-provoking question, fully readable with zero context from the lead post. Do NOT repeat the lead hook verbatim, do NOT phrase it as "1つ目/item 1 of N", and do NOT begin it with a number or list marker (never start with "1."). Replies 2 onward then form the numbered briefing.
- Native poll (impressions booster): when the thread's subject supports a crisp either/or, ranking, or first-person current-state question, include a "poll" object with a short Japanese "question" and 3-4 "options" (prefer 4 when each option is genuinely distinct; never pad with filler; each <=25 chars). X natively boosts impressions and early engagement on poll tweets.
- 投票の選択肢は、回答者が1秒で自分を位置づけられる一人称の《現在の状態/行動》を3-4個にせよ(意見や関心度の度合いではなく、既に取っている状態)。良い例(家計): 給料日基準で支出を見ている / 月初〜月末で見ている / 支出は把握していない / 見直したい。フラットな二択(興味がある/ない・賛成/反対)は不可(票が集まらず低品質に読まれる)。
- The "poll" must be a TOP-LEVEL JSON key only. NEVER place a poll object (or any JSON object) inside the threadReplies array — every threadReplies element must be a plain Japanese string, or it will be posted as raw garbage text.
- 投票の主題は、スレッドが実際に扱っている内容(=リードのフック主題)から導け。リードが製品ストーリー(給料日サイクル等の機能・家計行動)を主題にしたなら投票もその機能/行動を主題にする。スレッド本文で一度も掘り下げていない見出し語(モデル名・時事トピック)を投票の主題にしてはならない — 来た読者が答えられず0票になる(実際に「Fable 5の活用法について、どの程度追ってますか?」が0票だった)。上記(B)の日(=ドメイン直結の見出しが無い日)は見出し由来のpollを作るな。汎用・ハードコードのpoll("使ってみたい?はい/いいえ"等)も禁止(近似重複は降格)。昨日のpollは今日再利用不可。
- 禁止する投票の型(この語尾/形は書き直せ): 「どう感じますか」「どの程度〜ていますか」「どの程度追ってますか」、および答えが意見・関心度の度合いになるstem。GOOD例: 「あなたの支出、いつ基準で見てる?」+ 上の現在状態の選択肢。
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
      final financeBody = _scriptLinesFromText(
        draft.text,
      ).take(2).map((line) => _clipNarrationLine(line, 60));
      return _capNarration(<String>[
        financeOpening,
        ...financeBody,
        financeClosing,
      ]);
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
