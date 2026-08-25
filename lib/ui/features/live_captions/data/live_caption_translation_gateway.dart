import '../../../../services/ai_service.dart';
import '../domain/live_caption_models.dart';

abstract class LiveCaptionTranslationGateway {
  Future<String> translate({
    required String text,
    required LiveCaptionLanguage sourceLanguage,
    required LiveCaptionLanguage targetLanguage,
  });
}

class AiLiveCaptionTranslationGateway implements LiveCaptionTranslationGateway {
  AiLiveCaptionTranslationGateway({AIService? aiService})
      : _aiService = aiService ?? AIService();

  final AIService _aiService;

  @override
  Future<String> translate({
    required String text,
    required LiveCaptionLanguage sourceLanguage,
    required LiveCaptionLanguage targetLanguage,
  }) async {
    if (sourceLanguage.tag == targetLanguage.tag) return text;

    final translated = await _aiService.translateText(
      text,
      targetLanguage: targetLanguage.translationName,
      styleName: 'live-caption',
      styleInstruction:
          'Translate spoken ${sourceLanguage.translationName} into concise '
          '${targetLanguage.translationName} subtitles. Return only the '
          'translation, without labels, commentary, or quotation marks.',
    );
    final normalized = translated.trim();
    if (normalized.isEmpty) {
      throw const LiveCaptionTranslationException('翻訳結果が空でした。');
    }
    return normalized;
  }
}

class LiveCaptionTranslationException implements Exception {
  const LiveCaptionTranslationException(this.message);

  final String message;

  @override
  String toString() => message;
}
