import 'package:flutter/material.dart';

@immutable
class AiUniversityGenreEntry {
  const AiUniversityGenreEntry({
    required this.id,
    required this.title,
    required this.headline,
    required this.description,
    required this.providerIds,
    required this.focusAreas,
    required this.accentColor,
    required this.launchProviderId,
  });

  final String id;
  final String title;
  final String headline;
  final String description;
  final List<String> providerIds;
  final List<String> focusAreas;
  final Color accentColor;
  final String launchProviderId;
}

const AiUniversityGenreEntry kLegalAiGenre = AiUniversityGenreEntry(
  id: 'legal_ai',
  title: '\u6cd5\u5f8bAI',
  headline:
      '\u5951\u7d04\u30ec\u30d3\u30e5\u30fc\u30fb\u30ea\u30fc\u30ac\u30eb\u30ea\u30b5\u30fc\u30c1\u30fbDD\u3092\u5b66\u3076\u65b0\u30b8\u30e3\u30f3\u30eb',
  description:
      '\u6c4e\u7528LLM\u306e\u5ef6\u9577\u3067\u306f\u306a\u304f\u3001\u6cd5\u5f8b\u5b9f\u52d9\u306e\u30ef\u30fc\u30af\u30d5\u30ed\u30fc\u304b\u3089AI\u3092\u7406\u89e3\u3059\u308b\u305f\u3081\u306e\u5165\u53e3\u3067\u3059\u3002',
  providerIds: ['harvey'],
  focusAreas: [
    '\u5951\u7d04\u30ec\u30d3\u30e5\u30fc',
    '\u30ea\u30fc\u30ac\u30eb\u30ea\u30b5\u30fc\u30c1',
    'Due Diligence',
  ],
  accentColor: Color(0xFF2C5282),
  launchProviderId: 'harvey',
);

const List<AiUniversityGenreEntry> kAiUniversityGenres = [kLegalAiGenre];

AiUniversityGenreEntry? aiUniversityGenreById(String id) {
  for (final genre in kAiUniversityGenres) {
    if (genre.id == id) return genre;
  }
  return null;
}

AiUniversityGenreEntry? aiUniversityGenreForProvider(String providerId) {
  for (final genre in kAiUniversityGenres) {
    if (genre.providerIds.contains(providerId)) return genre;
  }
  return null;
}
