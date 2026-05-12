import 'package:supabase_flutter/supabase_flutter.dart';

import 'ai_hub_chat_service.dart';

typedef AiUniversityXPublisher = Future<Map<String, dynamic>> Function({
  required String text,
  required bool dryRun,
});

class AiUniversityXPostMetrics {
  final int correctAnswers;
  final int totalQuestions;
  final int providerCount;
  final int currentStreak;
  final String insight;
  final String url;

  const AiUniversityXPostMetrics({
    required this.correctAnswers,
    required this.totalQuestions,
    required this.providerCount,
    required this.currentStreak,
    this.insight = 'モデル間の設計思想の違い',
    this.url = AiUniversityXPostService.defaultUrl,
  });

  int get safeTotalQuestions {
    if (totalQuestions > 0) return totalQuestions;
    if (providerCount > 0) return providerCount;
    return AiUniversityXPostService.defaultQuestionTotal;
  }
}

class AiUniversityXPostResult {
  final String text;
  final bool posted;
  final bool fallbackUsed;
  final String source;
  final String? account;
  final String? tweetId;
  final Map<String, dynamic> raw;

  const AiUniversityXPostResult({
    required this.text,
    required this.posted,
    required this.fallbackUsed,
    required this.source,
    this.account,
    this.tweetId,
    this.raw = const {},
  });
}

class AiUniversityXPostService {
  static const String defaultUrl =
      'https://my-web-app-b67f4.web.app/gemini-university';
  static const int defaultQuestionTotal = 39;
  static const int maxTweetLength = 280;

  final SupabaseClient? _supabase;
  final AiHubChatService _chatService;
  final AiUniversityXPublisher? _publisher;

  AiUniversityXPostService({
    SupabaseClient? supabase,
    AiHubChatService? chatService,
    AiUniversityXPublisher? publisher,
  })  : _supabase = supabase,
        _chatService = chatService ?? AiHubChatService(supabase: supabase),
        _publisher = publisher;

  Future<AiUniversityXPostResult> generateAndPostLearningUpdate({
    required AiUniversityXPostMetrics metrics,
    bool dryRun = false,
  }) async {
    final generated = await generateLearningPost(metrics);
    final postData = await _postToX(text: generated.text, dryRun: dryRun);
    return AiUniversityXPostResult(
      text: generated.text,
      posted: postData['posted'] == true,
      fallbackUsed: generated.fallbackUsed,
      source: generated.source,
      account: postData['account']?.toString(),
      tweetId:
          postData['tweetId']?.toString() ?? postData['tweet_id']?.toString(),
      raw: postData,
    );
  }

  Future<({String text, bool fallbackUsed, String source})>
      generateLearningPost(AiUniversityXPostMetrics metrics) async {
    final fallback = buildFallbackLearningPost(metrics);
    try {
      final response = await _chatService.sendAutoChat(
        tier: 'free',
        sessionId: 'ai-university-x-post',
        message: _buildPrompt(metrics, fallback),
      );
      final normalized = sanitizeTweet(response.text);
      if (_isUsableTweet(normalized, metrics.url)) {
        return (text: normalized, fallbackUsed: false, source: response.source);
      }
    } catch (_) {
      // The button should still work when AI quota or provider routing fails.
    }
    return (text: fallback, fallbackUsed: true, source: 'fallback');
  }

  static String buildFallbackLearningPost(AiUniversityXPostMetrics metrics) {
    final total = metrics.safeTotalQuestions;
    final providerLine = metrics.providerCount > 0
        ? 'Google / OpenAI / Anthropic など ${metrics.providerCount}社を体系的に学習中。'
        : 'Google / OpenAI / Anthropic を体系的に学習中。';
    final streakLine = metrics.currentStreak > 0
        ? '\n${metrics.currentStreak}日連続で学習ログを更新中。'
        : '';

    return sanitizeTweet('''AI大学で ${metrics.correctAnswers}/$total 問正解
$providerLine
今日は「${metrics.insight}」が一番の気づきでした。

Flutter Webで自作した学習ポータルもアップデート中
${metrics.url}$streakLine

学ぶ → まとめる → プロダクト化 → 公開する。
#AILearning #buildinpublic #FlutterWeb''');
  }

  static String sanitizeTweet(String raw) {
    var text = raw
        .replaceAll(
          RegExp(r'```(?:text|markdown|json)?', caseSensitive: false),
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
    if (text.length <= maxTweetLength) return text;

    const tags = '#AILearning #buildinpublic #FlutterWeb';
    const url = defaultUrl;
    const mustKeep = '\n$url\n$tags';
    const budget = maxTweetLength - mustKeep.length - 1;
    if (budget <= 0) return text.substring(0, maxTweetLength);

    final withoutKeep = text
        .replaceAll(url, '')
        .replaceAll(tags, '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    final head = withoutKeep.length <= budget
        ? withoutKeep
        : '${withoutKeep.substring(0, budget - 1).trimRight()}…';
    return '$head$mustKeep';
  }

  Future<Map<String, dynamic>> _postToX({
    required String text,
    required bool dryRun,
  }) async {
    final publisher = _publisher;
    if (publisher != null) {
      return publisher(text: text, dryRun: dryRun);
    }

    final client = _supabase ?? Supabase.instance.client;
    final response = await client.functions.invoke(
      'growth-hub',
      body: {
        'action': 'x.post',
        'text': text,
        'dryRun': dryRun,
        'source': 'ai_university',
      },
    );
    final data = response.data;
    final map = data is Map<String, dynamic>
        ? data
        : data is Map
            ? Map<String, dynamic>.from(data)
            : <String, dynamic>{'success': false, 'message': data?.toString()};
    if (map['success'] != true) {
      throw Exception(_buildXPostFailureMessage(map));
    }
    return map;
  }

  static String _buildXPostFailureMessage(Map<String, dynamic> data) {
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

  static bool _isUsableTweet(String text, String url) {
    return text.isNotEmpty &&
        text.length <= maxTweetLength &&
        text.contains(url) &&
        !text.contains('/#/') &&
        !text.contains('#/gemini-university');
  }

  static String _buildPrompt(
    AiUniversityXPostMetrics metrics,
    String fallback,
  ) {
    final total = metrics.safeTotalQuestions;
    return '''
あなたはbuild in publicが得意な日本語X投稿エディターです。
AI大学の学習ログ投稿を1件だけ作ってください。

条件:
- 280文字以内
- 日本語
- 誇張しすぎず、学習曲線と次の改善が伝わる
- URLは必ず ${metrics.url}
- URLに # や /#/ を入れない
- ハッシュタグは #AILearning #buildinpublic #FlutterWeb を使う
- 投稿文だけを返す

実績:
- 正解数: ${metrics.correctAnswers}/$total
- 学習対象: Google / OpenAI / Anthropic など ${metrics.providerCount}社
- 連続学習: ${metrics.currentStreak}日
- 今日の気づき: ${metrics.insight}

参考文体:
$fallback
''';
  }
}
