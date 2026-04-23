class AiUniversityVideoLessonTopic {
  const AiUniversityVideoLessonTopic({
    required this.provider,
    required this.category,
    required this.title,
    required this.content,
    this.sourceUrl,
  });

  final String provider;
  final String category;
  final String title;
  final String content;
  final String? sourceUrl;

  String get id => '$provider::$category::$title';
}

class AiUniversityVideoLessonService {
  static const int _maxPromptContentChars = 1800;

  static const Map<String, String> _providerLabels = {
    'google': 'Google',
    'openai': 'OpenAI',
    'anthropic': 'Anthropic',
    'microsoft': 'Microsoft',
    'meta': 'Meta',
    'x': 'xAI',
    'deepseek': 'DeepSeek',
    'mistral': 'Mistral',
    'perplexity': 'Perplexity',
    'groq': 'Groq',
    'hedra': 'Hedra AI',
    'heygen': 'HeyGen',
    'runway': 'Runway',
    'luma': 'Luma AI',
    'kling': 'Kling AI',
    'pika': 'Pika',
  };

  static List<AiUniversityVideoLessonTopic> topicsFromRows(
    List<Map<String, dynamic>> rows,
  ) {
    final topics = rows
        .map(
          (row) => AiUniversityVideoLessonTopic(
            provider: (row['provider'] as String? ?? '').trim(),
            category: (row['category'] as String? ?? '').trim(),
            title: (row['title'] as String? ?? '').trim(),
            content: (row['content'] as String? ?? '').trim(),
            sourceUrl: (row['source_url'] as String?)?.trim(),
          ),
        )
        .where(
          (topic) =>
              topic.provider.isNotEmpty &&
              topic.title.isNotEmpty &&
              topic.content.isNotEmpty,
        )
        .toList();

    topics.sort((a, b) {
      final categoryCompare =
          _categoryRank(a.category).compareTo(_categoryRank(b.category));
      if (categoryCompare != 0) return categoryCompare;
      return a.title.compareTo(b.title);
    });
    return topics;
  }

  static AiUniversityVideoLessonTopic? pickInitialTopic(
    List<AiUniversityVideoLessonTopic> topics, {
    String? preferredCategory,
  }) {
    if (topics.isEmpty) return null;
    if (preferredCategory != null && preferredCategory.trim().isNotEmpty) {
      for (final topic in topics) {
        if (topic.category == preferredCategory.trim()) return topic;
      }
    }
    for (final topic in topics) {
      if (topic.category == 'overview') return topic;
    }
    return topics.first;
  }

  static String providerLabel(String provider) =>
      _providerLabels[provider] ?? provider.toUpperCase();

  static String categoryLabel(String category) {
    switch (category) {
      case 'overview':
        return '概要';
      case 'models':
        return 'モデル';
      case 'api':
        return 'API';
      case 'use_cases':
        return 'ユースケース';
      case 'pricing':
        return '料金';
      case 'news':
        return '最新動向';
      default:
        return category.isEmpty ? '教材' : category;
    }
  }

  static String previewText(String content, {int maxChars = 220}) {
    final normalized = _normalizeSource(content);
    if (normalized.length <= maxChars) return normalized;
    return '${normalized.substring(0, maxChars)}...';
  }

  static String buildPrompt({
    required String providerLabel,
    required AiUniversityVideoLessonTopic topic,
  }) {
    final source = _normalizeSource(topic.content);
    final clipped = source.length > _maxPromptContentChars
        ? '${source.substring(0, _maxPromptContentChars)}...'
        : source;

    return '''
あなたは「自分株式会社 AI大学」の講師アバターです。
以下の教材だけを根拠に、$providerLabel の「${topic.title}」を日本語で短い動画レッスンとして説明してください。

必須ルール:
- 4〜6文の話し言葉でまとめる
- 1文目で結論をひと言で示す
- 重要な特徴を2〜3個入れる
- どんな場面で使うと良いかを1つ入れる
- 教材にない断定や誇張は避ける
- 箇条書きやMarkdownは使わない

教材カテゴリ: ${categoryLabel(topic.category)}
教材タイトル: ${topic.title}
教材本文:
$clipped
'''
        .trim();
  }

  static int _categoryRank(String category) {
    switch (category) {
      case 'overview':
        return 0;
      case 'models':
        return 1;
      case 'api':
        return 2;
      case 'use_cases':
        return 3;
      case 'pricing':
        return 4;
      case 'news':
        return 5;
      default:
        return 99;
    }
  }

  static String _normalizeSource(String source) {
    return source
        .replaceAll(RegExp(r'```[\s\S]*?```'), ' ')
        .replaceAll(RegExp(r'[`*_>#|]'), ' ')
        .replaceAll(RegExp(r'\[(.*?)\]\((.*?)\)'), r'$1')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
