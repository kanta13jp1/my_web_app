import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/data/ai_university_genre_catalog.dart';

void main() {
  test(
      '\u6cd5\u5f8bAI\u30b8\u30e3\u30f3\u30eb\u304cHarvey\u3092\u4ee3\u8868\u30d7\u30ed\u30d0\u30a4\u30c0\u30fc\u306b\u6301\u3064',
      () {
    expect(kAiUniversityGenres, isNotEmpty);
    expect(kLegalAiGenre.providerIds, contains('harvey'));
    expect(kLegalAiGenre.launchProviderId, 'harvey');
  });

  test(
      'provider\u304b\u3089\u6cd5\u5f8bAI\u30b8\u30e3\u30f3\u30eb\u3092\u9006\u5f15\u304d\u3067\u304d\u308b',
      () {
    final genre = aiUniversityGenreForProvider('harvey');

    expect(genre, isNotNull);
    expect(genre!.id, 'legal_ai');
    expect(genre.title, '\u6cd5\u5f8bAI');
  });
}
