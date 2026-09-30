import 'dart:async';
import 'package:flutter/foundation.dart';
import 'jev_client.dart';

/// セマンティック支出検索のマッチ結果。
class SemanticSearchResult {
  final Map<String, dynamic> item;
  final double score;
  final bool isMatch;
  final String source; // 'jev' or 'local_fallback'
  final String matchedQuery;

  const SemanticSearchResult({
    required this.item,
    required this.score,
    required this.isMatch,
    required this.source,
    required this.matchedQuery,
  });

  /// 確信度スコアが 0.70 (70%) 以上
  bool get isHighConfidence => score >= 0.70;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'item': item,
      'score': score,
      'is_match': isMatch,
      'source': source,
      'matched_query': matchedQuery,
    };
  }

  @override
  String toString() =>
      'SemanticSearchResult(score: ${(score * 100).toStringAsFixed(1)}%, isMatch: $isMatch, source: $source)';
}

/// uehaj氏の「jev-semgrep」命題判定アーキテクチャに基づく
/// 支出データのセマンティック（意味で探す）検索サービス。
///
/// 単語の一致だけでなく、「交際費っぽい支出」「固定費削減候補」などの
/// 自然言語命題に対する真理確率（0.0〜1.0）をJev/LocalJevで判定する。
/// Fail-Open設計により、通信不達や未設定時は部分一致検索へ100%フォールバックする。
class JevSemanticExpenseSearchService {
  final JevClient _client;

  // メモ × クエリの判定結果キャッシュ
  final Map<String, double> _scoreCache = <String, double>{};

  JevSemanticExpenseSearchService({
    JevClient? client,
  }) : _client = client ??
            JevClient(
              apiKey: const String.fromEnvironment('TYPESAFE_API_KEY'),
            );

  /// 判定用のバイナリ選択肢（合致する / 合致しない）
  static const JevChoice choiceMatch = JevChoice(
    id: 'match',
    label: '合致する (True)',
    description: 'この支出アイテムの内容は指定された検索意図・命題に合致します。',
  );

  static const JevChoice choiceNotMatch = JevChoice(
    id: 'not_match',
    label: '合致しない (False)',
    description: 'この支出アイテムの内容は指定された検索意図・命題に合致しません。',
  );

  /// 支出アイテム群を指定した意味クエリで検索する。
  ///
  /// [meaningQuery]: 検索意図（例: "交際費・飲み会", "固定費", "無駄遣い"）
  /// [excludeQuery]: 除外したい意味（AND NOT検索、例: "完了したもの"）
  /// [threshold]: 合致と判定する確率閾値（デフォルト 0.50）
  Future<List<SemanticSearchResult>> search({
    required List<Map<String, dynamic>> items,
    required String meaningQuery,
    String? excludeQuery,
    double threshold = 0.50,
  }) async {
    final String query = meaningQuery.trim();
    if (query.isEmpty) {
      return items.map((Map<String, dynamic> it) {
        return SemanticSearchResult(
          item: it,
          score: 1.0,
          isMatch: true,
          source: 'empty_query',
          matchedQuery: '',
        );
      }).toList();
    }

    // Jev が利用可能（APIキー設定済み、または LocalJev モード）か判定
    if (!_client.isConfigured) {
      return _localFallbackSearch(
        items: items,
        query: query,
        excludeQuery: excludeQuery,
      );
    }

    try {
      final List<SemanticSearchResult> results = <SemanticSearchResult>[];

      for (final Map<String, dynamic> item in items) {
        final double score = await _evaluateItem(item, query);

        bool isMatch = score >= threshold;

        // 除外クエリ（AND NOT）が存在する場合
        if (isMatch && excludeQuery != null && excludeQuery.trim().isNotEmpty) {
          final double excludeScore =
              await _evaluateItem(item, excludeQuery.trim());
          // 除外命題の成立スコアが高い（>= 0.60）場合は除外
          if (excludeScore >= 0.60) {
            isMatch = false;
          }
        }

        results.add(
          SemanticSearchResult(
            item: item,
            score: score,
            isMatch: isMatch,
            source: 'jev',
            matchedQuery: query,
          ),
        );
      }

      // マッチしたものを優先し、スコア降順でソート
      results.sort((SemanticSearchResult a, SemanticSearchResult b) {
        if (a.isMatch != b.isMatch) {
          return a.isMatch ? -1 : 1;
        }
        return b.score.compareTo(a.score);
      });

      return results;
    } catch (e) {
      debugPrint(
        '[JevSemanticSearch] Error during search: $e. Falling back to local search.',
      );
      return _localFallbackSearch(
        items: items,
        query: query,
        excludeQuery: excludeQuery,
      );
    }
  }

  /// 1件の支出アイテムとクエリの命題成立確率を評価（キャッシュ付き）
  Future<double> _evaluateItem(Map<String, dynamic> item, String query) async {
    final String text = _extractItemSummary(item);
    final String cacheKey = '$text:::$query';

    if (_scoreCache.containsKey(cacheKey)) {
      return _scoreCache[cacheKey]!;
    }

    try {
      final String inputPrompt =
          '対象支出データ:\n$text\n\n判定命題: この支出は「$query」に該当するか？';

      final JevClassificationResult? res = await _client.classify(
        input: inputPrompt,
        choices: const <JevChoice>[choiceMatch, choiceNotMatch],
        context: '個人財務管理の支出履歴に対するセマンティック検索フィルタリング',
      );

      if (res == null) {
        final double fallbackScore = _evaluateLocalWordMatch(text, query);
        _scoreCache[cacheKey] = fallbackScore;
        return fallbackScore;
      }

      final double score = res.scores['match'] ??
          (res.bestChoiceId == 'match' ? res.confidence : 1.0 - res.confidence);
      _scoreCache[cacheKey] = score;
      return score;
    } catch (e) {
      debugPrint(
        '[JevSemanticSearch] Item eval error: $e',
      );
      final double fallbackScore = _evaluateLocalWordMatch(text, query);
      _scoreCache[cacheKey] = fallbackScore;
      return fallbackScore;
    }
  }

  /// 支出アイテムから要約テキストを抽出
  String _extractItemSummary(Map<String, dynamic> item) {
    final String title = item['title']?.toString() ??
        item['name']?.toString() ??
        item['memo']?.toString() ??
        '';
    final String category = item['category']?.toString() ?? '';
    final String amount = item['amount'] != null ? '${item['amount']}円' : '';
    final String date = item['date']?.toString() ?? '';

    final List<String> parts = <String>[
      if (title.isNotEmpty) '名称/メモ: $title',
      if (category.isNotEmpty) 'カテゴリ: $category',
      if (amount.isNotEmpty) '金額: $amount',
      if (date.isNotEmpty) '日付: $date',
    ];

    return parts.join(' / ');
  }

  /// 通信障害・未設定時のローカル部分一致フォールバック検索
  List<SemanticSearchResult> _localFallbackSearch({
    required List<Map<String, dynamic>> items,
    required String query,
    String? excludeQuery,
  }) {
    final String lowerQuery = query.toLowerCase();
    final String? lowerExclude = excludeQuery?.trim().toLowerCase();

    final List<SemanticSearchResult> results = <SemanticSearchResult>[];

    for (final Map<String, dynamic> item in items) {
      final String text = _extractItemSummary(item).toLowerCase();
      final double score = _evaluateLocalWordMatch(text, lowerQuery);
      bool isMatch = score >= 0.50;

      if (isMatch && lowerExclude != null && lowerExclude.isNotEmpty) {
        if (text.contains(lowerExclude)) {
          isMatch = false;
        }
      }

      results.add(
        SemanticSearchResult(
          item: item,
          score: score,
          isMatch: isMatch,
          source: 'local_fallback',
          matchedQuery: query,
        ),
      );
    }

    results.sort((SemanticSearchResult a, SemanticSearchResult b) {
      if (a.isMatch != b.isMatch) {
        return a.isMatch ? -1 : 1;
      }
      return b.score.compareTo(a.score);
    });

    return results;
  }

  /// ローカル文字一致スコアリング
  double _evaluateLocalWordMatch(String text, String query) {
    if (text.contains(query)) {
      return 0.90;
    }
    // クエリの単語分割一致
    final List<String> words = query
        .split(RegExp(r'[\s・/、]+'))
        .where((String w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return 0.0;

    int matchedCount = 0;
    for (final String word in words) {
      if (text.contains(word)) {
        matchedCount++;
      }
    }

    if (matchedCount == words.length) {
      return 0.80;
    } else if (matchedCount > 0) {
      return 0.40 + (0.30 * (matchedCount / words.length));
    }

    return 0.10;
  }

  /// キャッシュのクリア（テスト等用）
  void clearCache() {
    _scoreCache.clear();
  }
}
