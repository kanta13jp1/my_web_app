import 'ai_hub_chat_service.dart';
import '../models/site_guide_catalog_item.dart';

typedef SiteGuideChatInvoker = AiHubChatInvoker;

class SiteGuideToolSuggestion {
  final String id;
  final String title;
  final String subtitle;
  final String sectionId;
  final String sectionTitle;
  final double score;

  const SiteGuideToolSuggestion({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.sectionId,
    required this.sectionTitle,
    required this.score,
  });
}

class SiteGuideChatAnswer {
  final String text;
  final String source;
  final DateTime answeredAt;
  final bool isFallback;
  final List<SiteGuideToolSuggestion> suggestions;

  const SiteGuideChatAnswer({
    required this.text,
    required this.source,
    required this.answeredAt,
    this.isFallback = false,
    this.suggestions = const <SiteGuideToolSuggestion>[],
  });
}

class SiteGuideChatService {
  final AiHubChatService _chatService;
  final List<SiteGuideCatalogItem> _catalog;
  final DateTime Function() _now;

  SiteGuideChatService({
    List<SiteGuideCatalogItem> catalog = const <SiteGuideCatalogItem>[],
    AiHubChatService? chatService,
    SiteGuideChatInvoker? invoker,
    DateTime Function()? now,
  })  : _chatService = chatService ?? AiHubChatService(invoker: invoker),
        _catalog = catalog,
        _now = now ?? DateTime.now;

  Future<SiteGuideChatAnswer> answerQuestion(String question) async {
    final normalizedQuestion = question.trim();
    final suggestions = _rankSuggestions(normalizedQuestion);
    if (normalizedQuestion.isEmpty) {
      return _buildFallbackAnswer(
        question: 'まず何から使えばいい？',
        suggestions: suggestions,
        reason: '質問が空でした。',
      );
    }

    try {
      final response = await _chatService.sendProviderChat(
        message: _buildPrompt(
          question: normalizedQuestion,
          suggestions: suggestions,
        ),
      );
      return SiteGuideChatAnswer(
        text: _normalize(response.text),
        source: response.source,
        answeredAt: _now(),
        suggestions: suggestions,
      );
    } catch (_) {
      return _buildFallbackAnswer(
        question: normalizedQuestion,
        suggestions: suggestions,
        reason: 'AI連携に失敗しました。',
      );
    }
  }

  SiteGuideChatAnswer _buildFallbackAnswer({
    required String question,
    required List<SiteGuideToolSuggestion> suggestions,
    required String reason,
  }) {
    final top = suggestions.take(3).toList();
    final gettingStarted = _looksLikeGettingStartedQuestion(question);

    final summary = gettingStarted
        ? '最初は Home の「AI FEATURE STRATEGY MONITOR」で今日の1手を見て、その次に「モーニングブリーフィング」を開くのがおすすめです。'
        : top.isNotEmpty
            ? 'いちばん近い候補は「${top.first.title}」です。'
            : '近い機能をすぐ絞れなかったので、Home の「AI FEATURE STRATEGY MONITOR」か「ユーザーマニュアル」から入るのがおすすめです。';

    final steps = top.isEmpty
        ? '詳しい全体像は「ユーザーマニュアル」、日々の着手順は「AI FEATURE STRATEGY MONITOR」で確認できます。'
        : top
            .map(
              (tool) =>
                  '「${tool.title}」(${tool.sectionTitle}) - ${tool.subtitle}',
            )
            .join(' / ');

    return SiteGuideChatAnswer(
      text: '$summary $steps $reason',
      source: 'local-site-guide',
      answeredAt: _now(),
      isFallback: true,
      suggestions: top,
    );
  }

  String _buildPrompt({
    required String question,
    required List<SiteGuideToolSuggestion> suggestions,
  }) {
    final suggestionLines = suggestions.isEmpty
        ? '- 近い候補を特定できませんでした。Home の全体導線から案内してください。'
        : suggestions.take(8).map((tool) {
            return '- [${tool.sectionTitle}] ${tool.title}: ${tool.subtitle} '
                '/ keywords score=${tool.score.toStringAsFixed(1)}';
          }).join('\n');

    return '''
あなたは「自分株式会社」のサイト案内AIです。
役割は、ユーザーがこのサイトの使い方、どこを開けばいいか、どの機能から始めればいいかを迷わないように導くことです。

必ず守ること:
- 日本語で答える
- 最初に「おすすめの入口」を1つ明言する
- 続けて 2〜4 手順で説明する
- 機能名やセクション名は、このサイト内の名前をそのまま使う
- 無い機能は無いと明言し、近い機能を案内する
- 不確かなことは断定しない
- 4〜6文で簡潔に答える

このサイトの主要入口:
- Home の「QUICK ACCESS」: 毎日よく使う固定導線
- Home の「AI FEATURE STRATEGY MONITOR」: 全機能の KGI / CSF / KPI と今日の低ハードル1手
- Home の「OFFICE KPI SNAPSHOT」: CFO / CHRO など主要オフィスの現状確認
- 「ユーザーマニュアル」: まとまった説明を読む入口

質問に近い機能候補:
$suggestionLines

質問:
$question
''';
  }

  List<SiteGuideToolSuggestion> _rankSuggestions(String question) {
    final normalizedQuestion = _normalizeForSearch(question);
    final tokens = _questionTokens(normalizedQuestion);

    final scored = _catalog.map((entry) {
      final title = _normalizeForSearch(entry.title);
      final subtitle = _normalizeForSearch(entry.subtitle);
      final section = _normalizeForSearch(entry.sectionTitle);
      final keywords = entry.keywords.map(_normalizeForSearch).toList();

      var score = 0.0;
      if (normalizedQuestion.isNotEmpty) {
        if (title.contains(normalizedQuestion)) score += 12;
        if (subtitle.contains(normalizedQuestion)) score += 8;
        if (section.contains(normalizedQuestion)) score += 5;
        if (keywords.any(
          (keyword) =>
              keyword.contains(normalizedQuestion) ||
              normalizedQuestion.contains(keyword),
        )) {
          score += 10;
        }
      }

      for (final token in tokens) {
        if (token.length < 2) continue;
        if (title.contains(token)) score += 6;
        if (subtitle.contains(token)) score += 4;
        if (section.contains(token)) score += 2;
        if (keywords.any(
          (keyword) => keyword.contains(token) || token.contains(keyword),
        )) {
          score += 5;
        }
      }

      if (_looksLikeGettingStartedQuestion(question)) {
        if (entry.id == 'morning-briefing') score += 8;
        if (entry.id == 'personal-dashboard') score += 8;
        if (entry.id == 'site-guide-ai') score += 4;
      }

      return SiteGuideToolSuggestion(
        id: entry.id,
        title: entry.title,
        subtitle: entry.subtitle,
        sectionId: entry.sectionId,
        sectionTitle: entry.sectionTitle,
        score: score,
      );
    }).toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    final filtered = scored.where((entry) => entry.score > 0).toList();
    if (filtered.isNotEmpty) {
      return filtered.take(5).toList();
    }

    const defaultIds = <String>[
      'morning-briefing',
      'personal-dashboard',
      'asset-management',
      'site-guide-ai',
    ];
    final defaults = <SiteGuideToolSuggestion>[];
    for (final id in defaultIds) {
      final match = scored.where((entry) => entry.id == id);
      if (match.isNotEmpty) {
        defaults.add(match.first);
      }
    }
    return defaults;
  }

  Iterable<String> _questionTokens(String question) sync* {
    final rawTokens = RegExp(r'[A-Za-z0-9ぁ-んァ-ヶ一-龠々ー]{2,}')
        .allMatches(question)
        .map((match) => match.group(0)!)
        .toSet();
    const stopWords = <String>{
      'どこ',
      'です',
      'ます',
      'したい',
      'したら',
      '使い方',
      '教えて',
      'ですか',
      'について',
      'この',
      'サイト',
      '機能',
      '画面',
    };
    for (final token in rawTokens) {
      if (!stopWords.contains(token)) {
        yield token;
      }
    }
  }

  bool _looksLikeGettingStartedQuestion(String question) {
    final normalized = _normalizeForSearch(question);
    return normalized.contains('まず') ||
        normalized.contains('最初') ||
        normalized.contains('何から') ||
        normalized.contains('初心者') ||
        normalized.contains('はじめかた') ||
        normalized.contains('始め方');
  }

  String _normalizeForSearch(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll('　', '');
  }

  String _normalize(String text) {
    final collapsed = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (collapsed.length <= 360) {
      return collapsed;
    }
    return '${collapsed.substring(0, 360)}...';
  }
}
