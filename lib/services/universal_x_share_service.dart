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
  final bool fallbackUsed;
  final String source;

  const UniversalXShareDraft({
    required this.text,
    required this.imagePrompt,
    required this.videoPrompt,
    required this.hashtags,
    required this.fallbackUsed,
    required this.source,
  });

  UniversalXShareDraft copyWith({
    String? text,
    String? imagePrompt,
    String? videoPrompt,
    List<String>? hashtags,
    bool? fallbackUsed,
    String? source,
  }) {
    return UniversalXShareDraft(
      text: text ?? this.text,
      imagePrompt: imagePrompt ?? this.imagePrompt,
      videoPrompt: videoPrompt ?? this.videoPrompt,
      hashtags: hashtags ?? this.hashtags,
      fallbackUsed: fallbackUsed ?? this.fallbackUsed,
      source: source ?? this.source,
    );
  }
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
  final Map<String, dynamic> raw;

  const UniversalXPostResult({
    required this.posted,
    this.account,
    this.tweetId,
    this.raw = const {},
  });
}

class UniversalXShareService {
  static const int maxTweetLength = 280;

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
    final fallback = buildFallbackDraft(context);
    try {
      final response = await _chatService.sendAutoChat(
        tier: 'free',
        sessionId: 'universal-x-share',
        message: _buildDraftPrompt(context, fallback),
      );
      final parsed = _parseDraft(response.text, context, fallback);
      if (_isUsableText(parsed.text, context.url)) {
        return parsed.copyWith(
          fallbackUsed: false,
          source: response.source,
        );
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
      'prompt': draft.imagePrompt,
      'size': '1792x1024',
      'style': 'vivid',
      'source': 'universal_x_share',
      'route': context.routePath,
    });
    return UniversalXMediaResult(
      url: _extractNestedUrl(data),
      status: data['success'] == true ? 'ready' : 'failed',
      raw: data,
    );
  }

  Future<UniversalXMediaResult> generateVideo({
    required UniversalSharePageContext context,
    required UniversalXShareDraft draft,
  }) async {
    final data = await _invoke('viral-video-ad-generator', {
      'type': 'presenter_video',
      'template': 'feature_highlight',
      'lang': 'ja',
      'title': context.title,
      'customPrompt': draft.videoPrompt,
      'customScript': _scriptLinesFromText(draft.text),
      'customHashtags': draft.hashtags,
      'source': 'universal_x_share',
      'route': context.routePath,
    });
    final url = data['generatedVideoUrl']?.toString() ??
        data['generatedDownloadUrl']?.toString() ??
        data['generatedPreviewUrl']?.toString();
    return UniversalXMediaResult(
      url: _emptyToNull(url),
      status: data['status']?.toString() ?? 'unknown',
      raw: data,
    );
  }

  Future<UniversalXPostResult> postToX({
    required UniversalSharePageContext context,
    required String text,
    String? mediaUrl,
    bool dryRun = false,
  }) async {
    final data = await _invoke('growth-hub', {
      'action': 'x.post',
      'text': sanitizeTweet(text, url: context.url),
      'mediaUrl': mediaUrl,
      'dryRun': dryRun,
      'source': 'universal_x_share',
      'route': context.routePath,
    });
    if (data['success'] != true) {
      throw Exception(data['error']?.toString() ?? 'X post failed');
    }
    return UniversalXPostResult(
      posted: data['posted'] == true,
      account: data['account']?.toString(),
      tweetId: data['tweetId']?.toString() ?? data['tweet_id']?.toString(),
      raw: data,
    );
  }

  static UniversalXShareDraft buildFallbackDraft(
    UniversalSharePageContext context,
  ) {
    final title = context.title;
    final text = sanitizeTweet(
      '''$title をアップデートしました。
自分株式会社の中で、今日の改善をそのまま使える形にしています。

${context.url}

#buildinpublic #FlutterWeb #Supabase''',
      url: context.url,
    );
    return UniversalXShareDraft(
      text: text,
      imagePrompt:
          'A clean 16:9 product screenshot style hero image for "$title", Flutter web app UI, crisp dashboard details, no text overlays, modern Japanese productivity app, bright and trustworthy.',
      videoPrompt:
          'A short 16:9 presenter video concept introducing "$title" as a practical improvement in a Flutter web life-management app.',
      hashtags: const ['#buildinpublic', '#FlutterWeb', '#Supabase'],
      fallbackUsed: true,
      source: 'fallback',
    );
  }

  static String sanitizeTweet(String raw, {required String url}) {
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
    if (!text.contains(url)) {
      text = '$text\n$url';
    }
    if (text.length <= maxTweetLength) return text;
    final tail = '\n$url';
    final budget = maxTweetLength - tail.length - 1;
    if (budget <= 0) return text.substring(0, maxTweetLength);
    final withoutUrl = text.replaceAll(url, '').trim();
    final head = withoutUrl.length <= budget
        ? withoutUrl
        : '${withoutUrl.substring(0, budget - 1).trimRight()}…';
    return '$head$tail';
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
    UniversalXShareDraft fallback,
  ) {
    final jsonText = raw
        .replaceAll(RegExp(r'```json', caseSensitive: false), '')
        .replaceAll('```', '')
        .trim();
    try {
      final decoded = jsonDecode(jsonText);
      if (decoded is Map<String, dynamic>) {
        final text = sanitizeTweet(
          decoded['text']?.toString() ?? fallback.text,
          url: context.url,
        );
        final hashtags = decoded['hashtags'] is List
            ? (decoded['hashtags'] as List)
                .map((entry) => entry.toString().trim())
                .where((entry) => entry.isNotEmpty)
                .toList()
            : fallback.hashtags;
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
          fallbackUsed: true,
          source: 'ai-json',
        );
      }
    } catch (_) {
      // Fall through to treating the response as a tweet body.
    }
    return fallback.copyWith(text: sanitizeTweet(raw, url: context.url));
  }

  static bool _isUsableText(String text, String url) {
    return text.isNotEmpty &&
        text.length <= maxTweetLength &&
        text.contains(url) &&
        !text.contains('/#/');
  }

  static String _buildDraftPrompt(
    UniversalSharePageContext context,
    UniversalXShareDraft fallback,
  ) {
    return '''
You are a Japanese build-in-public social media strategist.
Create one X sharing package for the current page of a Flutter Web app.

Return valid JSON only:
{
  "text": "Japanese X post under 280 chars, must include ${context.url}",
  "imagePrompt": "English prompt for a 16:9 share image, no text overlay",
  "videoPrompt": "English prompt for a short presenter/share video",
  "hashtags": ["#buildinpublic", "#FlutterWeb", "#Supabase"]
}

Page:
- title: ${context.title}
- route: ${context.routePath}
- url: ${context.url}

Rules:
- Do not use hash routing. The URL must not contain # or /#/.
- Make the copy specific to this page, not generic app promotion.
- Emphasize what changed, what users can do, and why it matters.
- Keep the post natural, concise, and credible.

Fallback style:
${fallback.text}
''';
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
}
