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
      '\u7af6\u5408\u304c\u307e\u3060\u8584\u3044\u6cd5\u5f8bAI\u5b9f\u52d9\u3092Harvey\u304b\u3089\u5b66\u3076\u65b0\u30b8\u30e3\u30f3\u30eb',
  description:
      '\u6c4e\u7528LLM\u306e\u5ef6\u9577\u3067\u306f\u306a\u304f\u3001\u5951\u7d04\u30ec\u30d3\u30e5\u30fc\u3001\u30ea\u30fc\u30ac\u30eb\u30ea\u30b5\u30fc\u30c1\u3001Due Diligence\u3001\u30b3\u30f3\u30d7\u30e9\u30a4\u30a2\u30f3\u30b9\u3068\u3044\u3046\u6cd5\u5f8b\u5b9f\u52d9\u306e\u30ef\u30fc\u30af\u30d5\u30ed\u30fc\u304b\u3089AI\u3092\u7406\u89e3\u3059\u308b\u5165\u53e3\u3067\u3059\u3002\u7af6\u5408\u304c\u307e\u3060\u8584\u3044\u9818\u57df\u3092\u3001Harvey\u3092\u4ee3\u8868\u30d7\u30ed\u30d0\u30a4\u30c0\u30fc\u306b\u3057\u3066\u72ec\u7acb\u30b8\u30e3\u30f3\u30eb\u5316\u3057\u307e\u3059\u3002',
  providerIds: ['harvey'],
  focusAreas: [
    '\u5951\u7d04\u30ec\u30d3\u30e5\u30fc',
    '\u30ea\u30fc\u30ac\u30eb\u30ea\u30b5\u30fc\u30c1',
    'Due Diligence',
    '\u30b3\u30f3\u30d7\u30e9\u30a4\u30a2\u30f3\u30b9',
  ],
  accentColor: Color(0xFF2C5282),
  launchProviderId: 'harvey',
);

const AiUniversityGenreEntry kFintechTradingAiGenre = AiUniversityGenreEntry(
  id: 'fintech_trading_ai',
  title: 'FinTech/Trading AI',
  headline: 'Decompose institutional finance workflows with low-cost AI',
  description: 'Compare professional terminals with Claude Pro, Cursor, and the '
      'Jibun Company signal-to-action pipeline. The learning path covers raw '
      'news capture, confidence scoring, fake-news filters, and human final '
      'review.',
  providerIds: [
    'bloomberg_terminal',
    'refinitiv_eikon',
    'factset',
    'sentieo',
    'koyfin',
    'atom_finance',
    'claude_pro_finance',
    'cursor_jibun_finance',
  ],
  focusAreas: [
    'market intelligence',
    'signal detection',
    'source confidence',
    'cost discipline',
  ],
  accentColor: Color(0xFF0F766E),
  launchProviderId: 'claude_pro_finance',
);

const List<AiUniversityGenreEntry> kAiUniversityGenres = [
  kLegalAiGenre,
  kFintechTradingAiGenre,
];

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
