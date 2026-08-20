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

  String? get youtubeVideoId =>
      AiUniversityVideoLessonService.youtubeVideoIdFromUrl(sourceUrl);
}

class AiUniversityVideoV3Scene {
  const AiUniversityVideoV3Scene({
    required this.label,
    required this.narration,
    required this.visualDirection,
    required this.onScreenText,
  });

  final String label;
  final String narration;
  final String visualDirection;
  final String onScreenText;
}

class AiUniversityVideoV3Plan {
  const AiUniversityVideoV3Plan({
    required this.title,
    required this.learningGoal,
    required this.heygenBrief,
    required this.scenes,
    required this.localizationNotes,
    required this.cta,
  });

  final String title;
  final String learningGoal;
  final String heygenBrief;
  final List<AiUniversityVideoV3Scene> scenes;
  final List<String> localizationNotes;
  final String cta;

  String get clipboardText => [
        title,
        '',
        'Learning goal: $learningGoal',
        '',
        'HeyGen brief:',
        heygenBrief,
        '',
        'Scenes:',
        ...scenes.map(
          (scene) => [
            '- ${scene.label}',
            '  Narration: ${scene.narration}',
            '  Visual: ${scene.visualDirection}',
            '  Text: ${scene.onScreenText}',
          ].join('\n'),
        ),
        '',
        'Localization:',
        ...localizationNotes.map((note) => '- $note'),
        '',
        'CTA: $cta',
      ].join('\n');
}

class AiUniversityVideoLessonService {
  static const int _maxPromptContentChars = 1800;
  static final RegExp _youtubeVideoIdPattern = RegExp(r'^[A-Za-z0-9_-]{11}$');

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

  static List<Map<String, dynamic>> mergeContentRowsByProviderCategory(
    Iterable<Map<String, dynamic>> primaryRows,
    Iterable<Map<String, dynamic>> supplementalRows,
  ) {
    final rowsByKey = <String, Map<String, dynamic>>{};
    var unkeyedRowIndex = 0;

    for (final row in [...primaryRows, ...supplementalRows]) {
      final provider =
          (row['provider'] as String? ?? row['provider_id'] as String? ?? '')
              .trim();
      final category = (row['category'] as String? ?? '').trim();
      final key = provider.isNotEmpty && category.isNotEmpty
          ? '$provider::$category'
          : 'unkeyed::${unkeyedRowIndex++}';
      rowsByKey[key] = row;
    }

    return rowsByKey.values.toList(growable: false);
  }

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

  static String? youtubeVideoIdFromUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return null;
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null) return null;

    final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
    String? candidate;

    if (host == 'youtu.be') {
      candidate = uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
    } else if (host == 'youtube.com' ||
        host == 'm.youtube.com' ||
        host == 'music.youtube.com' ||
        host == 'youtube-nocookie.com') {
      if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'watch') {
        candidate = uri.queryParameters['v'];
      } else if (uri.pathSegments.length >= 2 &&
          const {'embed', 'shorts', 'live'}.contains(uri.pathSegments.first)) {
        candidate = uri.pathSegments[1];
      } else {
        candidate = uri.queryParameters['v'];
      }
    }

    final videoId = candidate?.trim();
    return videoId != null && _youtubeVideoIdPattern.hasMatch(videoId)
        ? videoId
        : null;
  }

  static String youtubeEmbedUrl(String videoId) =>
      'https://www.youtube.com/embed/$videoId?rel=0';

  static AiUniversityVideoV3Plan buildHeyGenV3Plan({
    required String providerLabel,
    required AiUniversityVideoLessonTopic topic,
  }) {
    final source = _normalizeSource(topic.content);
    final category = categoryLabel(topic.category);
    final oneLine = _firstSentence(source, fallback: topic.title);
    final useCase = _pickUseCase(topic.category);

    return AiUniversityVideoV3Plan(
      title: 'HeyGen AI大学 v3: $providerLabel / ${topic.title}',
      learningGoal: '$providerLabel の $category を90秒以内で理解し、$useCase に使う判断材料を得る',
      heygenBrief: 'HeyGen Avatar Vで、落ち着いた講師アバターが日本語で説明する。'
          '1シーン15秒前後、字幕は短く、口調は断定しすぎず教材根拠ベースにする。'
          '生成後は英語・韓国語・中国語・スペイン語へリップシンク翻訳できる構成にする。',
      scenes: [
        AiUniversityVideoV3Scene(
          label: 'Hook',
          narration: '$providerLabel は何を解決するAIなのか。まず一言で押さえます。',
          visualDirection: '講師アバター正面。背景にプロバイダー名とカテゴリを表示。',
          onScreenText: '$providerLabel: $category',
        ),
        AiUniversityVideoV3Scene(
          label: 'Core concept',
          narration: oneLine,
          visualDirection: 'キーワード3つを横並びで表示し、講師が順番に指し示す。',
          onScreenText: _keywords(source).join(' / '),
        ),
        AiUniversityVideoV3Scene(
          label: 'Why it matters',
          narration: '$useCase で使うと、調査・制作・判断の手戻りを減らせます。',
          visualDirection: 'Before/Afterの2カラム。左は手作業、右はAI活用。',
          onScreenText: '手戻り削減 / 判断高速化 / 再利用',
        ),
        const AiUniversityVideoV3Scene(
          label: 'How to try',
          narration: 'まずは小さな教材や業務メモで試し、結果をKGI、CSF、KPIで確認します。',
          visualDirection: 'チェックリストUI。入力、生成、評価、改善の4ステップ。',
          onScreenText: '入力 -> 生成 -> 評価 -> 改善',
        ),
        AiUniversityVideoV3Scene(
          label: 'Recap',
          narration: '$providerLabel は、$category の理解を動画で素早く共有する入口になります。',
          visualDirection: '講師アバター横にまとめカード。最後にAI大学への導線。',
          onScreenText: 'AI大学で次の教材へ',
        ),
      ],
      localizationNotes: [
        '英語版は専門用語を残し、短い文でテンポを上げる',
        '韓国語・中国語版は画面テキストを詰め込みすぎない',
        'SNS短尺版はHook、Core concept、CTAの3シーンだけに圧縮する',
        '各言語で字幕が長くなる場合は1行18文字前後に分割する',
      ],
      cta: 'AI大学で $providerLabel の教材を開き、次のユースケースを試す',
    );
  }

  static String categoryLabel(String category) {
    if (category.startsWith('video_')) return '動画レッスン';
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

  static String buildHeyGenV3Prompt({
    required String providerLabel,
    required AiUniversityVideoLessonTopic topic,
  }) {
    final basePrompt = buildPrompt(providerLabel: providerLabel, topic: topic);
    final plan = buildHeyGenV3Plan(providerLabel: providerLabel, topic: topic);
    return '''
$basePrompt

追加条件:
- HeyGen Avatar V でそのまま動画化できる構成にする
- 冒頭に学習ゴールを1文で入れる
- 5シーン構成で、各シーンは15秒以内の短い台詞にする
- 日本語版を主原稿にし、英語・韓国語・中国語・スペイン語への翻訳時に崩れにくい短文にする
- 最後に「次に試す小さな実践」を1つだけ示す

HeyGen v3 設計メモ:
${plan.clipboardText}
'''
        .trim();
  }

  static int _categoryRank(String category) {
    if (category.startsWith('video_')) return 1;
    switch (category) {
      case 'overview':
        return 0;
      case 'models':
        return 2;
      case 'api':
        return 3;
      case 'use_cases':
        return 4;
      case 'pricing':
        return 5;
      case 'news':
        return 6;
      default:
        return 99;
    }
  }

  static String _firstSentence(String source, {required String fallback}) {
    if (source.trim().isEmpty) return fallback;
    final parts = source.split(RegExp(r'[。.!?]\s*'));
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.length >= 12) {
        return trimmed.length > 90 ? '${trimmed.substring(0, 90)}...' : trimmed;
      }
    }
    final clipped = source.trim();
    return clipped.length > 90 ? '${clipped.substring(0, 90)}...' : clipped;
  }

  static List<String> _keywords(String source) {
    final matches = RegExp(r'[A-Za-z][A-Za-z0-9.+-]{2,}|[一-龥ぁ-んァ-ンー]{3,}')
        .allMatches(source)
        .map((match) => match.group(0) ?? '')
        .where((word) => word.trim().isNotEmpty)
        .toList();
    final unique = <String>[];
    for (final word in matches) {
      if (!unique.contains(word)) unique.add(word);
      if (unique.length == 3) break;
    }
    return unique.isEmpty ? ['概要', '使いどころ', '次の実践'] : unique;
  }

  static String _pickUseCase(String category) {
    switch (category) {
      case 'api':
        return 'プロダクト実装やEdge Function連携';
      case 'models':
        return 'モデル選定や性能比較';
      case 'use_cases':
        return '実務への適用判断';
      case 'pricing':
        return '費用対効果の見積もり';
      case 'news':
        return '最新動向の共有';
      case 'overview':
      default:
        return '初回学習とチーム共有';
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
