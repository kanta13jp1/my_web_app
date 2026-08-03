/// 語学学習 単語帳 + フラッシュカードモデル。
///
/// `social-commerce-hub`:
/// - `lang.list_decks` → `{success, decks: [hub_data 行]}`
///   実フィールド `metadata.name` / `metadata.language` / `metadata.description`。
/// - `lang.list_cards` / `lang.review_session` → `{success, cards: [hub_data 行]}`
///   実フィールド `metadata.front` / `metadata.back` / `metadata.example` /
///   `metadata.deck`。
///
/// 旧実装のバグ:
/// - デッキ: `deck['deck_id']` (実 `id`) / デッキ名空 (`metadata.name`)。
/// - カード: 表裏空 (`front`/`back`)。
/// - `lang.review_session` は `cards` キーだが旧実装は `dueCards` を読み常に空。
/// - `lang.streak` は `{streak_days: N}`、`lang.stats` は `{total_cards, decks}`
///   だが旧実装は `{streak:{...}}` / `{stats:{...}}` を期待し常に空。
library;

import 'hub_data_parsing.dart';

class LanguageDeck {
  const LanguageDeck({
    required this.id,
    required this.name,
    required this.language,
    required this.description,
  });

  /// hub_data 行のトップレベル id (旧実装が読んでいた `deck_id` は不存在)。
  final String id;
  final String name;
  final String language;
  final String description;

  factory LanguageDeck.fromMap(Map<String, dynamic> raw) {
    return LanguageDeck(
      id: hubString(raw['id']),
      name: hubString(hubField(raw, 'name')),
      language: hubString(hubField(raw, 'language')),
      description: hubString(hubField(raw, 'description')),
    );
  }

  static List<LanguageDeck> listFromResponse(dynamic data) =>
      hubRowsFromResponse(data, 'decks').map(LanguageDeck.fromMap).toList();
}

class Flashcard {
  const Flashcard({
    required this.id,
    required this.front,
    required this.back,
    required this.example,
  });

  final String id;
  final String front;
  final String back;
  final String example;

  factory Flashcard.fromMap(Map<String, dynamic> raw) {
    return Flashcard(
      id: hubString(raw['id']),
      front: hubString(hubField(raw, 'front')),
      back: hubString(hubField(raw, 'back')),
      example: hubString(hubField(raw, 'example')),
    );
  }

  /// `lang.list_cards` / `lang.review_session` はどちらも `cards` キー。
  static List<Flashcard> listFromResponse(dynamic data) =>
      hubRowsFromResponse(data, 'cards').map(Flashcard.fromMap).toList();
}

/// `lang.streak` (`{streak_days}`) / `lang.stats` (`{total_cards, decks}`) の
/// scalar トップレベル値を安全に読む。
class LanguageStats {
  const LanguageStats({required this.streakDays, required this.totalCards});

  final num streakDays;
  final num totalCards;

  factory LanguageStats.fromResponses(dynamic streakData, dynamic statsData) {
    num streak = 0;
    num total = 0;
    if (streakData is Map) streak = hubNum(streakData['streak_days']);
    if (statsData is Map) total = hubNum(statsData['total_cards']);
    return LanguageStats(streakDays: streak, totalCards: total);
  }
}
