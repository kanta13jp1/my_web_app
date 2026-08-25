class LiveCaptionLanguage {
  const LiveCaptionLanguage({
    required this.tag,
    required this.label,
    required this.translationName,
  });

  final String tag;
  final String label;
  final String translationName;
}

const List<LiveCaptionLanguage> kLiveCaptionLanguages = <LiveCaptionLanguage>[
  LiveCaptionLanguage(tag: 'ja-JP', label: '日本語', translationName: 'Japanese'),
  LiveCaptionLanguage(tag: 'en-US', label: '英語', translationName: 'English'),
  LiveCaptionLanguage(
    tag: 'zh-CN',
    label: '中国語（簡体字）',
    translationName: 'Simplified Chinese',
  ),
  LiveCaptionLanguage(tag: 'ko-KR', label: '韓国語', translationName: 'Korean'),
  LiveCaptionLanguage(tag: 'es-ES', label: 'スペイン語', translationName: 'Spanish'),
  LiveCaptionLanguage(tag: 'fr-FR', label: 'フランス語', translationName: 'French'),
];

LiveCaptionLanguage liveCaptionLanguageByTag(String tag) {
  return kLiveCaptionLanguages.firstWhere(
    (language) => language.tag == tag,
    orElse: () => kLiveCaptionLanguages.first,
  );
}

class LiveCaptionSegment {
  LiveCaptionSegment({
    required this.id,
    required this.sourceLanguageTag,
    required this.sourceText,
    required this.receivedAt,
    Map<String, String> translations = const <String, String>{},
  }) : translations = Map<String, String>.unmodifiable(translations);

  final int id;
  final String sourceLanguageTag;
  final String sourceText;
  final DateTime receivedAt;
  final Map<String, String> translations;

  String textFor(String languageTag) {
    if (languageTag == sourceLanguageTag) return sourceText;
    return translations[languageTag] ?? sourceText;
  }

  bool hasTranslation(String languageTag) =>
      languageTag == sourceLanguageTag || translations.containsKey(languageTag);

  LiveCaptionSegment withTranslation(String languageTag, String text) {
    return LiveCaptionSegment(
      id: id,
      sourceLanguageTag: sourceLanguageTag,
      sourceText: sourceText,
      receivedAt: receivedAt,
      translations: <String, String>{...translations, languageTag: text},
    );
  }
}

enum LiveCaptionStatus {
  idle,
  listening,
  translating,
  stopped,
  unsupported,
  error,
}
