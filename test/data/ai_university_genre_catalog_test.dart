import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/data/ai_university_genre_catalog.dart';

void main() {
  test(
      '\u6cd5\u5f8bAI\u30b8\u30e3\u30f3\u30eb\u304cHarvey\u3092\u4ee3\u8868\u30d7\u30ed\u30d0\u30a4\u30c0\u30fc\u306b\u6301\u3064',
      () {
    expect(kAiUniversityGenres, isNotEmpty);
    expect(kLegalAiGenre.providerIds, contains('harvey'));
    expect(kLegalAiGenre.launchProviderId, 'harvey');
    expect(kLegalAiGenre.headline, contains('\u7af6\u5408'));
    expect(kLegalAiGenre.description, contains('Harvey'));
    expect(
      kLegalAiGenre.focusAreas,
      contains('\u30b3\u30f3\u30d7\u30e9\u30a4\u30a2\u30f3\u30b9'),
    );
  });

  test(
      'provider\u304b\u3089\u6cd5\u5f8bAI\u30b8\u30e3\u30f3\u30eb\u3092\u9006\u5f15\u304d\u3067\u304d\u308b',
      () {
    final genre = aiUniversityGenreForProvider('harvey');

    expect(genre, isNotNull);
    expect(genre!.id, 'legal_ai');
    expect(genre.title, '\u6cd5\u5f8bAI');
  });

  test('FinTech/Trading AI genre contains #1964 provider set', () {
    expect(kFintechTradingAiGenre.providerIds, hasLength(8));
    expect(kFintechTradingAiGenre.providerIds, contains('bloomberg_terminal'));
    expect(kFintechTradingAiGenre.providerIds, contains('claude_pro_finance'));
    expect(
      kFintechTradingAiGenre.providerIds,
      contains('cursor_jibun_finance'),
    );
    expect(kFintechTradingAiGenre.launchProviderId, 'claude_pro_finance');
  });

  test('provider reverse lookup finds FinTech/Trading AI genre', () {
    final genre = aiUniversityGenreForProvider('koyfin');

    expect(genre, isNotNull);
    expect(genre!.id, 'fintech_trading_ai');
    expect(genre.title, 'FinTech/Trading AI');
  });
}
