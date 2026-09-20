import 'dart:async';
import 'package:flutter/foundation.dart';
import 'jev_client.dart';

/// 支出・取引の即時分類結果。
class ExpenseCategoryPrediction {
  final String categoryId;
  final String categoryLabel;
  final double confidence;
  final bool isFallback;
  final String source; // 'jev' or 'local_rule'
  final int latencyMs;
  final Map<String, double> scores;

  const ExpenseCategoryPrediction({
    required this.categoryId,
    required this.categoryLabel,
    required this.confidence,
    this.isFallback = false,
    required this.source,
    this.latencyMs = 0,
    this.scores = const <String, double>{},
  });

  /// 確信度が 0.80 (80%) 以上であれば自動確定・高確信度サジェストが可能
  bool get isHighConfidence => confidence >= 0.80;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'category_id': categoryId,
      'category_label': categoryLabel,
      'confidence': confidence,
      'is_fallback': isFallback,
      'source': source,
      'latency_ms': latencyMs,
      'scores': scores,
    };
  }

  @override
  String toString() =>
      'ExpenseCategoryPrediction(category: $categoryLabel, confidence: ${(confidence * 100).toStringAsFixed(1)}%, source: $source)';
}

/// TypeSafe AI（Jev）を活用したリアルタイム即時カテゴリ分類サービス。
///
/// 取引メモや品目テキストから、最大256個の支出カテゴリを数十〜数百msで
/// 確率スコアリングする。API未設定時や通信障害時は完全な Fail-Open 設計により
/// ローカルのルールベース辞書へ瞬時にフォールバックする。
class JevInstantClassifierService {
  /// 標準の支出カテゴリ定義一覧
  static const List<JevChoice> defaultCategories = <JevChoice>[
    JevChoice(
      id: 'food',
      label: '食費・食材',
      description: 'スーパーマーケット、八百屋、肉屋、自炊用食材の購入',
    ),
    JevChoice(
      id: 'cafe_snack',
      label: 'カフェ・間食',
      description: 'スターバックス、喫茶店、カフェ、おやつ、軽食、スイーツ',
    ),
    JevChoice(
      id: 'convenience',
      label: 'コンビニ',
      description: 'セブンイレブン、ファミリーマート、ローソン等での買い物',
    ),
    JevChoice(
      id: 'dining_out',
      label: '外食・交際費',
      description: 'レストラン、居酒屋、同僚や友人との食事、飲み会',
    ),
    JevChoice(
      id: 'daily_necessities',
      label: '日用品・消耗品',
      description: 'ドラッグストア、洗剤、ティッシュ、雑貨、生活消耗品',
    ),
    JevChoice(
      id: 'transport',
      label: '交通費',
      description: '電車、バス、タクシー、Suica/PASMOチャージ、航空券',
    ),
    JevChoice(
      id: 'utilities',
      label: '水道・光熱費',
      description: '電気代、ガス代、水道料金',
    ),
    JevChoice(
      id: 'telecom',
      label: '通信費',
      description: 'スマートフォン月額、インターネット回線、Wi-Fi',
    ),
    JevChoice(
      id: 'subscription_entertainment',
      label: 'サブスク・娯楽',
      description: 'Netflix、Spotify、本、マンガ、ゲーム、映画、趣味',
    ),
    JevChoice(
      id: 'medical',
      label: '医療・健康',
      description: '病院、クリニック、処方箋、薬局、歯科、コンタクト',
    ),
    JevChoice(
      id: 'housing',
      label: '住居・家賃',
      description: '家賃、管理費、更新料、住宅ローン',
    ),
    JevChoice(
      id: 'other',
      label: 'その他支出',
      description: '上記のいずれにも明確に当てはまらない支出',
    ),
  ];

  /// キーワード辞書によるローカルルールマッピング（Fail-Open用）
  static const Map<String, String> _keywordToCategory = <String, String>{
    'スタバ': 'cafe_snack',
    'スターバックス': 'cafe_snack',
    'ドトール': 'cafe_snack',
    'タリーズ': 'cafe_snack',
    'カフェ': 'cafe_snack',
    '珈琲': 'cafe_snack',
    'コーヒー': 'cafe_snack',
    'セブン': 'convenience',
    'ファミマ': 'convenience',
    'ファミリーマート': 'convenience',
    'ローソン': 'convenience',
    'ミニストップ': 'convenience',
    'スーパー': 'food',
    'イオン': 'food',
    '西友': 'food',
    'ライフ': 'food',
    '八百屋': 'food',
    '食材': 'food',
    '業務スーパー': 'food',
    'マクドナルド': 'dining_out',
    'ガスト': 'dining_out',
    'サイゼリヤ': 'dining_out',
    '居酒屋': 'dining_out',
    'ラーメン': 'dining_out',
    'マツキヨ': 'daily_necessities',
    'ウエルシア': 'daily_necessities',
    'スギ薬局': 'daily_necessities',
    'ドラッグ': 'daily_necessities',
    '洗剤': 'daily_necessities',
    'ティッシュ': 'daily_necessities',
    'suica': 'transport',
    'pasmo': 'transport',
    'icoca': 'transport',
    'チャージ': 'transport',
    'jr': 'transport',
    'メトロ': 'transport',
    'タクシー': 'transport',
    '切符': 'transport',
    '東京電力': 'utilities',
    '関西電力': 'utilities',
    '電気': 'utilities',
    'ガス': 'utilities',
    '水道': 'utilities',
    'ドコモ': 'telecom',
    'au': 'telecom',
    'ソフトバンク': 'telecom',
    'ワイモバイル': 'telecom',
    'uq': 'telecom',
    'wifi': 'telecom',
    'ネット': 'telecom',
    'netflix': 'subscription_entertainment',
    'spotify': 'subscription_entertainment',
    'youtube': 'subscription_entertainment',
    'amazon prime': 'subscription_entertainment',
    'プライム': 'subscription_entertainment',
    '書籍': 'subscription_entertainment',
    'kindle': 'subscription_entertainment',
    '映画': 'subscription_entertainment',
    'クリニック': 'medical',
    '病院': 'medical',
    '医院': 'medical',
    '歯科': 'medical',
    '歯医者': 'medical',
    '薬局': 'medical',
    '処方': 'medical',
    '家賃': 'housing',
    '管理費': 'housing',
  };

  final JevClient _client;
  final bool isEnabled;

  JevInstantClassifierService({
    JevClient? client,
    this.isEnabled = const bool.fromEnvironment(
      'JEV_ROUTING_ENABLED',
      defaultValue: true,
    ),
  }) : _client = client ?? JevClient();

  /// サービスが利用可能（有効化かつキー設定済み）かどうか
  bool get isAvailable => isEnabled && _client.isConfigured;

  /// 入力された品目テキストからカテゴリを即座に予測する。
  ///
  /// Jevが有効かつ設定済みの場合は超低遅延スコアリングを行い、
  /// 未設定時・障害時・タイムアウト時はローカルルールベースへ即座に自動フォールバックする。
  Future<ExpenseCategoryPrediction> predictCategory(
    String itemText, {
    List<JevChoice>? categories,
  }) async {
    final effectiveCategories = categories ?? defaultCategories;
    final normalized = itemText.trim();

    if (normalized.isEmpty) {
      return const ExpenseCategoryPrediction(
        categoryId: 'other',
        categoryLabel: 'その他支出',
        confidence: 0.0,
        isFallback: true,
        source: 'empty_input',
      );
    }

    if (isAvailable) {
      try {
        final result = await _client.classify(
          input: normalized,
          choices: effectiveCategories,
          context: '日本の一般的な個人家計簿・支出管理における品目分類',
        );

        if (result != null && result.bestChoice != null) {
          return ExpenseCategoryPrediction(
            categoryId: result.bestChoiceId,
            categoryLabel: result.bestChoice!.label,
            confidence: result.confidence,
            isFallback: false,
            source: 'jev',
            latencyMs: result.latencyMs,
            scores: result.scores,
          );
        }
      } catch (e) {
        debugPrint(
          'JevInstantClassifierService: Jev call failed ($e), falling back',
        );
      }
    }

    // Fail-Open: ローカルルールベースによるフォールバック
    return predictLocalFallback(
      normalized,
      categories: effectiveCategories,
    );
  }

  /// ローカルキーワード辞書によるフォールバック判定（オフライン・Fail-Open）
  ExpenseCategoryPrediction predictLocalFallback(
    String itemText, {
    List<JevChoice>? categories,
  }) {
    final effectiveCategories = categories ?? defaultCategories;
    final lower = itemText.toLowerCase().trim();

    for (final entry in _keywordToCategory.entries) {
      if (lower.contains(entry.key.toLowerCase())) {
        final matchedId = entry.value;
        final matchedChoice = effectiveCategories.firstWhere(
          (c) => c.id == matchedId,
          orElse: () => const JevChoice(id: 'other', label: 'その他支出'),
        );

        return ExpenseCategoryPrediction(
          categoryId: matchedChoice.id,
          categoryLabel: matchedChoice.label,
          confidence: 0.85, // ルール一致による基準確信度
          isFallback: true,
          source: 'local_rule',
          latencyMs: 0,
        );
      }
    }

    // いずれにも一致しない場合はその他
    final otherChoice = effectiveCategories.firstWhere(
      (c) => c.id == 'other',
      orElse: () => effectiveCategories.first,
    );

    return ExpenseCategoryPrediction(
      categoryId: otherChoice.id,
      categoryLabel: otherChoice.label,
      confidence: 0.30,
      isFallback: true,
      source: 'local_default',
      latencyMs: 0,
    );
  }
}
